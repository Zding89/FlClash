package main

import (
	"hash/fnv"
	"strings"
	"time"

	C "github.com/metacubex/mihomo/constant"
	"golang.org/x/net/publicsuffix"
)

type LocalNodePreference struct {
	Type      string `json:"type" yaml:"type"`
	Direction string `json:"direction" yaml:"direction"`
}

func localPolicyAction(p LocalPolicyDefinition) string {
	if p.Action == "" {
		return "proxy"
	}
	return p.Action
}

func localPolicySkipsUnavailable(c LocalPolicyConfig, p LocalPolicyDefinition) bool {
	return c.SchemaVersion >= 3 || p.SkipUnavailable != nil && *p.SkipUnavailable
}

func validLocalSchedule(schedule *LocalPolicySchedule) bool {
	if schedule == nil {
		return true
	}
	if schedule.TimeZone != "Asia/Shanghai" && schedule.TimeZone != "UTC" || len(schedule.Windows) > 20 {
		return false
	}
	for _, w := range schedule.Windows {
		if len(w.Weekdays) == 0 || len(w.Weekdays) > 7 || w.StartMinute < 0 || w.StartMinute >= 1440 || w.EndMinute < 0 || w.EndMinute > 1440 || w.EndMinute == w.StartMinute {
			return false
		}
		seen := map[int]bool{}
		for _, day := range w.Weekdays {
			if day < 1 || day > 7 || seen[day] {
				return false
			}
			seen[day] = true
		}
	}
	return true
}

func validLocalSetPreferences(set LocalNodeSet, sources map[string]bool) bool {
	if len(set.Preferences) > 5 || !validLocalSchedule(set.Schedule) || set.SelectionMode != "" && set.SelectionMode != "priority" && set.SelectionMode != "loadBalance" || set.BalanceStrategy != "" && set.BalanceStrategy != "roundRobin" && set.BalanceStrategy != "consistentHashing" && set.BalanceStrategy != "stickySessions" {
		return false
	}
	seen := map[string]bool{}
	for _, p := range set.Preferences {
		if seen[p.Type] || p.Direction != "ascending" && p.Direction != "descending" {
			return false
		}
		switch p.Type {
		case "expiry", "remaining", "latency", "multiplier", "source":
		default:
			return false
		}
		seen[p.Type] = true
	}
	for _, entries := range [][]string{set.NameIncludes, set.NameExcludes} {
		if len(entries) > 50 {
			return false
		}
		for _, value := range entries {
			if strings.TrimSpace(value) == "" || len(value) > 200 {
				return false
			}
		}
	}
	if len(set.ExcludedSourceIDs) > 20 || len(set.ExcludedRegions) > 250 {
		return false
	}
	seen = map[string]bool{}
	for _, id := range set.ExcludedSourceIDs {
		if !sources[id] || seen[id] {
			return false
		}
		seen[id] = true
	}
	seen = map[string]bool{}
	for _, region := range set.ExcludedRegions {
		if len(region) != 2 || region[0] < 'A' || region[0] > 'Z' || region[1] < 'A' || region[1] > 'Z' || seen[region] {
			return false
		}
		seen[region] = true
	}
	return true
}

type localPreferenceValue struct {
	integer    int64
	multiplier float64
	known      bool
}

func (e *localPolicyEngine) preferenceValue(set LocalNodeSet, r *localPolicyRuntime, id, kind string, now time.Time) localPreferenceValue {
	node := e.nodes[id]
	source := e.sources[node.SourceID]
	switch kind {
	case "expiry":
		if source.ExpiresAt != nil && *source.ExpiresAt > now.UnixMilli() {
			return localPreferenceValue{integer: *source.ExpiresAt, known: true}
		}
	case "remaining":
		if source.RemainingBytes != nil {
			return localPreferenceValue{integer: *source.RemainingBytes, known: true}
		}
	case "latency":
		if h := r.health[id]; h != nil && h.latencyMillis != nil {
			return localPreferenceValue{integer: *h.latencyMillis, known: true}
		}
	case "multiplier":
		if value := set.effectiveMultiplier(node); value != nil {
			return localPreferenceValue{multiplier: *value, known: true}
		}
	case "source":
		for index, sourceID := range set.SourceIDs {
			if sourceID == node.SourceID {
				return localPreferenceValue{integer: int64(index), known: true}
			}
		}
	}
	return localPreferenceValue{}
}

func (e *localPolicyEngine) preferenceLess(set LocalNodeSet, r *localPolicyRuntime, a, b string, now time.Time) bool {
	for _, p := range set.Preferences {
		av := e.preferenceValue(set, r, a, p.Type, now)
		bv := e.preferenceValue(set, r, b, p.Type, now)
		if av.known != bv.known {
			return av.known
		}
		if av.known && (av.integer != bv.integer || av.multiplier != bv.multiplier) {
			if p.Type == "multiplier" {
				if p.Direction == "descending" {
					return av.multiplier > bv.multiplier
				}
				return av.multiplier < bv.multiplier
			}
			if p.Direction == "descending" {
				return av.integer > bv.integer
			}
			return av.integer < bv.integer
		}
	}
	return a < b
}

func localBalancedNode(r *localPolicyRuntime, metadata *C.Metadata, allocate bool) string {
	pool := r.activeNodeIDs
	if r.balanceStrategy == "" || r.balanceStrategy == "roundRobin" {
		id := pool[r.balanceCursor%uint64(len(pool))]
		if allocate {
			r.balanceCursor++
		}
		return id
	}
	key := ""
	if metadata != nil {
		key = strings.ToLower(metadata.Host)
		if domain, err := publicsuffix.EffectiveTLDPlusOne(key); err == nil {
			key = domain
		}
		if key == "" {
			key = metadata.DstIP.String()
		}
		if r.balanceStrategy == "stickySessions" {
			key = metadata.SrcIP.String() + "/" + key
		}
	}
	selected := pool[0]
	var greatest uint64
	for _, id := range pool {
		h := fnv.New64a()
		_, _ = h.Write([]byte(key + "\x00" + id))
		score := h.Sum64()
		if score > greatest {
			greatest, selected = score, id
		}
	}
	return selected
}

func localSelectionStatus(status *LocalPolicyStatus, r *localPolicyRuntime) {
	status.SelectionMode = r.selectionMode
	if r.selectionMode == "loadBalance" {
		status.ActiveNodeCount = len(r.activeNodeIDs)
		status.ActiveNodeIDs = append([]string(nil), r.activeNodeIDs[:min(10, len(r.activeNodeIDs))]...)
		status.SelectedNodeID = ""
	} else if r.selected != "" {
		status.ActiveNodeCount = 1
		status.ActiveNodeIDs = []string{r.selected}
	}
}
