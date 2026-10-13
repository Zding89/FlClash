package main

import (
	"errors"
	"math"
	"sort"
	"strings"
	"time"
)

type LocalPolicyChoice struct {
	Type string `json:"type" yaml:"type"`
	ID   string `json:"id" yaml:"id"`
}
type LocalNodeSet struct {
	ID                 string           `json:"id" yaml:"id"`
	Label              string           `json:"label" yaml:"label"`
	SourceIDs          []string         `json:"sourceIds" yaml:"sourceIds"`
	Regions            []string         `json:"regions" yaml:"regions"`
	MaxMultiplier      *float64         `json:"maxMultiplier" yaml:"maxMultiplier"`
	UnknownMultiplier  string           `json:"unknownMultiplier" yaml:"unknownMultiplier"`
	AllowUnknownRegion bool             `json:"allowUnknownRegion" yaml:"allowUnknownRegion"`
	Strategy           string           `json:"strategy" yaml:"strategy"`
	Probe              LocalPolicyProbe `json:"probe" yaml:"probe"`
	RecoverySeconds    int              `json:"recoverySeconds" yaml:"recoverySeconds"`
	CooldownSeconds    int              `json:"cooldownSeconds" yaml:"cooldownSeconds"`
	ImprovementPercent int              `json:"improvementPercent" yaml:"improvementPercent"`
}

func localProbeMethod(p LocalPolicyProbe) string {
	if p.Method == "" {
		return "HEAD"
	}
	return p.Method
}
func localContains(values []string, id string) bool {
	for _, value := range values {
		if value == id {
			return true
		}
	}
	return false
}
func (s LocalNodeSet) effectiveMultiplier(n LocalPolicyNode) *float64 {
	if n.Multiplier != nil {
		return n.Multiplier
	}
	if s.UnknownMultiplier == "assumeOne" {
		value := 1.0
		return &value
	}
	return nil
}
func (s LocalNodeSet) includes(n LocalPolicyNode) bool {
	if !localContains(s.SourceIDs, n.SourceID) {
		return false
	}
	if len(s.Regions) > 0 && (n.Region == nil && !s.AllowUnknownRegion || n.Region != nil && !localContains(s.Regions, *n.Region)) {
		return false
	}
	if s.MaxMultiplier != nil {
		value := s.effectiveMultiplier(n)
		if value == nil && s.UnknownMultiplier != "allow" || value != nil && *value > *s.MaxMultiplier {
			return false
		}
	}
	return true
}
func localFixedCandidates(p LocalPolicyDefinition) []string {
	if len(p.Choices) == 0 {
		return p.CandidateNodeIDs
	}
	values := []string{}
	for _, c := range p.Choices {
		if c.Type == "node" {
			values = append(values, c.ID)
		}
	}
	return values
}
func localOverrideChoice(p LocalPolicyDefinition, override LocalPolicyOverride) (int, bool) {
	if len(p.Choices) == 0 {
		return 0, override.NodeSetID == "" && localContains(p.CandidateNodeIDs, override.NodeID)
	}
	for i, choice := range p.Choices {
		if override.NodeSetID == "" && choice.Type == "node" && choice.ID == override.NodeID || override.NodeSetID != "" && choice.Type == "nodeSet" && choice.ID == override.NodeSetID {
			return i, true
		}
	}
	return -1, false
}
func localOverrideBinding(c *LocalPolicyConfig, p LocalPolicyDefinition, override LocalPolicyOverride) bool {
	if _, found := localOverrideChoice(p, override); !found {
		return false
	}
	if override.NodeSetID == "" {
		return true
	}
	for _, set := range c.NodeSets {
		if set.ID == override.NodeSetID {
			for _, node := range c.Nodes {
				if node.ID == override.NodeID && set.includes(node) {
					return true
				}
			}
			return false
		}
	}
	return false
}
func (e *localPolicyEngine) retainBoundOverrides(c *LocalPolicyConfig) {
	retained := []LocalPolicyOverride{}
	for _, override := range c.Overrides {
		for _, p := range c.Policies {
			if p.ID == override.PolicyID && localOverrideBinding(c, p, override) {
				retained = append(retained, override)
				break
			}
		}
	}
	e.config.Overrides = retained
}
func (e *localPolicyEngine) overrideChoiceLocked(r *localPolicyRuntime, override LocalPolicyOverride, now time.Time) (int, bool) {
	i, found := localOverrideChoice(r.definition, override)
	if !found {
		return -1, false
	}
	if len(r.definition.Choices) == 0 {
		return i, e.nodeReasonLocked(r, override.NodeID, now) == ""
	}
	return i, e.choiceNodeReasonLocked(r, i, override.NodeID, now) == ""
}
func validateLocalNodeSets(c *LocalPolicyConfig) error {
	fail := func() error { return errors.New("local policy: invalid node set, attributes or check capacity") }
	if len(c.NodeSets) > 100 {
		return fail()
	}
	sets := map[string]LocalNodeSet{}
	sources := map[string]bool{}
	for _, source := range c.Sources {
		sources[source.ID] = true
	}
	validBasis := func(v string) bool {
		return v == "" || v == "unknown" || v == "name" || v == "subscription" || v == "manual"
	}
	for _, node := range c.Nodes {
		if node.Region != nil && (len(*node.Region) != 2 || strings.ToUpper(*node.Region) != *node.Region) || node.Multiplier != nil && (math.IsNaN(*node.Multiplier) || math.IsInf(*node.Multiplier, 0) || *node.Multiplier <= 0 || *node.Multiplier > 1000) || !validBasis(node.RegionBasis) || !validBasis(node.MultiplierBasis) {
			return fail()
		}
	}
	for _, set := range c.NodeSets {
		if set.ID == "" || len(set.ID) > 128 || sets[set.ID].ID != "" || len(set.SourceIDs) == 0 || len(set.SourceIDs) > 20 || len(set.Regions) > 250 || set.MaxMultiplier != nil && (math.IsNaN(*set.MaxMultiplier) || math.IsInf(*set.MaxMultiplier, 0) || *set.MaxMultiplier <= 0 || *set.MaxMultiplier > 1000) || set.UnknownMultiplier != "exclude" && set.UnknownMultiplier != "allow" && set.UnknownMultiplier != "assumeOne" || set.Strategy != "stable" && set.Strategy != "latency" && set.Strategy != "multiplier" || set.ImprovementPercent < 1 || set.ImprovementPercent > 100 || set.RecoverySeconds < 0 || set.RecoverySeconds > 86400 || set.CooldownSeconds < 0 || set.CooldownSeconds > 3600 {
			return fail()
		}
		seen := map[string]bool{}
		for _, id := range set.SourceIDs {
			if !sources[id] || seen[id] {
				return fail()
			}
			seen[id] = true
		}
		seen = map[string]bool{}
		for _, region := range set.Regions {
			if len(region) != 2 || strings.ToUpper(region) != region || seen[region] {
				return fail()
			}
			seen[region] = true
		}
		p := LocalPolicyDefinition{ID: "validation", GroupName: "validation", CandidateNodeIDs: []string{"validation"}, Enabled: true, Probe: set.Probe, Guard: LocalPolicyGuard{UnknownBehavior: "allow"}, Fallback: "reject"}
		probeConfig := &LocalPolicyConfig{SchemaVersion: 1, Policies: []LocalPolicyDefinition{p}}
		if err := validateLocalPolicyConfig(probeConfig); err != nil {
			return err
		}
		sets[set.ID] = set
	}
	tasks := map[localProbeKey]bool{}
	for _, p := range c.Policies {
		if localProbeMethod(p.Probe) != "HEAD" && localProbeMethod(p.Probe) != "GET" || p.Probe.RetrySeconds < 0 || p.Probe.RetrySeconds > 86400 || p.Probe.ValiditySeconds < 0 || p.Probe.ValiditySeconds > 86400 || p.Probe.ValiditySeconds > 0 && p.Probe.ValiditySeconds < p.Probe.IntervalSeconds {
			return fail()
		}
		seen := map[string]bool{}
		for _, choice := range p.Choices {
			key := choice.Type + ":" + choice.ID
			if choice.ID == "" || seen[key] || choice.Type != "node" && choice.Type != "nodeSet" {
				return fail()
			}
			seen[key] = true
			if choice.Type == "nodeSet" && sets[choice.ID].ID == "" {
				return fail()
			}
		}
		if !p.Enabled {
			continue
		}
		add := func(id string, probe LocalPolicyProbe) {
			tasks[localProbeKey{nodeID: id, url: probe.URL, method: localProbeMethod(probe), status: probe.ExpectedStatus, timeout: probe.TimeoutSeconds, unknown: p.Guard.UnknownBehavior}] = true
		}
		for _, id := range localFixedCandidates(p) {
			add(id, p.Probe)
		}
		for _, choice := range p.Choices {
			if choice.Type == "nodeSet" {
				set := sets[choice.ID]
				for _, node := range c.Nodes {
					if set.includes(node) {
						add(node.ID, set.Probe)
					}
				}
			}
		}
	}
	if len(tasks) > 5000 {
		return fail()
	}
	return nil
}
func (e *localPolicyEngine) prepareNodeSets(c *LocalPolicyConfig) error {
	e.sets = map[string]*localPolicyRuntime{}
	e.setDefinitions = map[string]LocalNodeSet{}
	referenced := map[string]bool{}
	for _, p := range c.Policies {
		if p.Enabled {
			for _, choice := range p.Choices {
				if choice.Type == "nodeSet" {
					referenced[choice.ID] = true
				}
			}
		}
	}
	for _, set := range c.NodeSets {
		if !referenced[set.ID] {
			continue
		}
		ids := []string{}
		for _, node := range c.Nodes {
			if set.includes(node) {
				ids = append(ids, node.ID)
			}
		}
		sort.Strings(ids)
		r := &localPolicyRuntime{setID: set.ID, definition: LocalPolicyDefinition{ID: set.ID, Label: set.Label, CandidateNodeIDs: ids, Probe: set.Probe, Guard: LocalPolicyGuard{UnknownBehavior: "allow"}, RecoverySeconds: set.RecoverySeconds, CooldownSeconds: set.CooldownSeconds, AutoRecover: true, Fallback: "reject"}, health: map[string]*localNodeHealth{}}
		for _, id := range ids {
			r.health[id] = e.sharedHealthLocked(r, id)
		}
		e.sets[set.ID] = r
		e.setDefinitions[set.ID] = set
	}
	return nil
}
func (e *localPolicyEngine) checkRuntimes() []*localPolicyRuntime {
	values := []*localPolicyRuntime{}
	for _, set := range e.config.NodeSets {
		if r := e.sets[set.ID]; r != nil {
			values = append(values, r)
		}
	}
	for _, p := range e.config.Policies {
		if r := e.policies[p.ID]; r != nil {
			values = append(values, r)
		}
	}
	return values
}
func (e *localPolicyEngine) startProbesLocked(values []localProbeCandidate, now time.Time) {
	if len(values) == 0 {
		return
	}
	priorities := map[localProbeKey]bool{}
	for _, r := range e.checkRuntimes() {
		if r.selected != "" {
			priorities[localNetworkProbeKey(r, r.selected)] = true
		}
	}
	for _, r := range e.policies {
		for i, choice := range r.definition.Choices {
			target := r
			id := choice.ID
			if choice.Type == "nodeSet" {
				target = e.sets[choice.ID]
				if target == nil {
					continue
				}
				id = ""
				if selection := r.choiceSelections[i]; selection != nil {
					id = selection.selected
				}
				if id == "" && len(target.definition.CandidateNodeIDs) > 0 {
					id = target.definition.CandidateNodeIDs[0]
				}
			}
			if i == r.selectedChoice || i == 0 || i == r.selectedChoice+1 {
				if i == r.selectedChoice && r.selected != "" {
					id = r.selected
				}
				priorities[localNetworkProbeKey(target, id)] = true
			}
		}
	}
	urgent, ordinary := []int{}, []int{}
	for i, candidate := range values {
		if priorities[localNetworkProbeKey(candidate.runtime, candidate.nodeID)] {
			urgent = append(urgent, i)
		}
	}
	urgentPositions := map[int]int{}
	for position, index := range urgent {
		urgentPositions[index] = position
	}
	if len(urgent) > 0 {
		start := e.priorityCursor % len(urgent)
		urgent = append(append([]int{}, urgent[start:]...), urgent[:start]...)
	}
	for offset := range values {
		i := (e.probeCursor + offset) % len(values)
		if !priorities[localNetworkProbeKey(values[i].runtime, values[i].nodeID)] {
			ordinary = append(ordinary, i)
		}
	}
	for len(urgent)+len(ordinary) > 0 {
		priority := len(urgent) > 0 && (len(ordinary) == 0 || e.priorityStarts < 7)
		var index int
		if priority {
			index, urgent = urgent[0], urgent[1:]
		} else {
			index, ordinary = ordinary[0], ordinary[1:]
		}
		candidate := values[index]
		r, id := candidate.runtime, candidate.nodeID
		p, h := r.definition, r.health[id]
		if h == nil || h.pending || now.Before(h.nextProbe) && !e.manualCheckNeeded(r, id) || e.sourceReasonLocked(id, p, now) != "" {
			continue
		}
		expected := p.Probe.ExpectedStatus
		if expected == "" {
			expected = "200-399"
		}
		key := localProbeKey{nodeID: id, method: localProbeMethod(p.Probe), url: p.Probe.URL, status: expected, timeout: p.Probe.TimeoutSeconds, unknown: p.Guard.UnknownBehavior}
		if shared, ok := e.inFlight[key]; ok {
			e.inFlight[key] = append(shared, candidate)
			h.pending = true
			h.nextProbe = now.Add(time.Duration(p.Probe.IntervalSeconds) * time.Second)
			continue
		}
		if e.workers >= 8 {
			continue
		}
		e.inFlight[key] = []localProbeCandidate{candidate}
		h.pending = true
		h.nextProbe = now.Add(time.Duration(p.Probe.IntervalSeconds) * time.Second)
		e.workers++
		if priority {
			if e.priorityStarts < 7 {
				e.priorityStarts++
			}
			e.priorityCursor = (urgentPositions[index] + 1) % len(urgentPositions)
		} else {
			e.priorityStarts = 0
			e.probeCursor = (index + 1) % len(values)
		}
		e.wg.Add(1)
		go e.runSharedProbe(key, e.proxies[id], e.epoch)
	}
}
func (e *localPolicyEngine) evaluateSetLocked(r *localPolicyRuntime, now time.Time) {
	if e.selectionRoundActive && e.evaluatedSets[r.setID] {
		return
	}
	if e.selectionRoundActive {
		e.evaluatedSets[r.setID] = true
	}
	e.evaluateSetSelectionLocked(r, r, nil, now)
}
func (e *localPolicyEngine) evaluateSetSelectionLocked(r, measured, owner *localPolicyRuntime, now time.Time) {
	eligibleReason := func(id string) string {
		if !e.setDefinitions[measured.setID].includes(e.nodes[id]) {
			return "outside_node_set"
		}
		if owner != nil {
			if reason := e.sourceReasonLocked(id, owner.definition, now); reason != "" {
				return reason
			}
		}
		return e.nodeReasonLocked(measured, id, now)
	}
	set := e.setDefinitions[r.setID]
	less := func(a, b string) bool {
		if set.Strategy == "multiplier" {
			am, bm := set.effectiveMultiplier(e.nodes[a]), set.effectiveMultiplier(e.nodes[b])
			if am == nil && bm != nil {
				return false
			}
			if am != nil && bm == nil {
				return true
			}
			if am != nil && bm != nil && *am != *bm {
				return *am < *bm
			}
		}
		ah, bh := r.health[a].latencyMillis, r.health[b].latencyMillis
		if ah == nil && bh != nil {
			return false
		}
		if ah != nil && bh == nil {
			return true
		}
		if ah != nil && bh != nil && *ah != *bh {
			return *ah < *bh
		}
		return a < b
	}
	desired := ""
	if set.Strategy == "stable" && r.selected != "" && eligibleReason(r.selected) == "" {
		desired = r.selected
	} else {
		for _, id := range r.definition.CandidateNodeIDs {
			if eligibleReason(id) == "" && (desired == "" || less(id, desired)) {
				desired = id
			}
		}
	}
	old := r.selected
	valid := old != "" && eligibleReason(old) == ""
	if valid && desired != old {
		improve := true
		if set.Strategy == "stable" {
			improve = false
		} else if set.Strategy == "latency" {
			current, next := r.health[old].latencyMillis, r.health[desired].latencyMillis
			improve = current != nil && next != nil && *current > 0 && *next < *current && float64(*current-*next)*100 >= float64(*current)*float64(set.ImprovementPercent)
		}
		if !improve {
			desired = old
			r.optimizationNode = ""
		} else {
			if r.optimizationNode != desired {
				r.optimizationNode = desired
				r.optimizationSince = now
			}
			if now.Sub(r.switched) < time.Duration(set.CooldownSeconds)*time.Second || now.Sub(r.optimizationSince) < time.Duration(set.RecoverySeconds)*time.Second {
				desired = old
			}
		}
	}
	reason := "node_set"
	if desired == "" {
		reason = "no_eligible_members"
	}
	e.recordSelectionLocked(r, desired, reason, now)
}
func (e *localPolicyEngine) choiceNodeReasonLocked(r *localPolicyRuntime, index int, id string, now time.Time) string {
	if reason := e.sourceReasonLocked(id, r.definition, now); reason != "" {
		return reason
	}
	choice := r.definition.Choices[index]
	if choice.Type == "node" {
		if id != choice.ID {
			return "outside_choice"
		}
		return e.nodeReasonLocked(r, id, now)
	}
	set := e.sets[choice.ID]
	if set == nil || set.health[id] == nil || !e.setDefinitions[choice.ID].includes(e.nodes[id]) {
		return "outside_node_set"
	}
	return e.nodeReasonLocked(set, id, now)
}
func (e *localPolicyEngine) policyNodeReasonLocked(r *localPolicyRuntime, id string, now time.Time) string {
	if len(r.definition.Choices) == 0 {
		return e.nodeReasonLocked(r, id, now)
	}
	for i := range r.definition.Choices {
		if reason := e.choiceNodeReasonLocked(r, i, id, now); reason == "" {
			return ""
		}
	}
	return "outside_or_ineligible_choice"
}
func (e *localPolicyEngine) evaluateChoicesLocked(r *localPolicyRuntime, now time.Time) {
	if !localPolicyScheduleActive(r.definition.Schedule, now) {
		r.recoveryNode = ""
		r.recoverySince = time.Time{}
		e.recordSelectionLocked(r, "", "schedule_inactive", now)
		return
	}
	if r.choiceSelections == nil {
		r.choiceSelections = map[int]*localPolicyRuntime{}
	}
	candidates := make([]string, len(r.definition.Choices))
	for i, choice := range r.definition.Choices {
		id := choice.ID
		if choice.Type == "nodeSet" {
			set := e.sets[choice.ID]
			if set == nil {
				continue
			}
			selection := r.choiceSelections[i]
			if selection == nil || selection.setID != choice.ID {
				selection = &localPolicyRuntime{setID: choice.ID}
				r.choiceSelections[i] = selection
			}
			selection.definition = set.definition
			selection.health = set.health
			e.evaluateSetSelectionLocked(selection, set, r, now)
			id = selection.selected
		}
		if id != "" && e.choiceNodeReasonLocked(r, i, id, now) == "" {
			candidates[i] = id
		}
	}
	desired, index, reason := "", -1, "no_eligible_candidates"
	for _, override := range e.config.Overrides {
		if override.PolicyID == r.definition.ID && override.ExpiresAt > now.UnixMilli() {
			if i, valid := e.overrideChoiceLocked(r, override, now); valid {
				desired, index, reason = override.NodeID, i, "manual_override"
				break
			}
		}
	}
	if desired == "" {
		for i, id := range candidates {
			if id != "" {
				desired, index, reason = id, i, "ordered_choices"
				break
			}
		}
		oldValid := r.selected != "" && r.selectedChoice >= 0 && r.selectedChoice < len(r.definition.Choices) && e.choiceNodeReasonLocked(r, r.selectedChoice, r.selected, now) == ""
		if oldValid && index >= 0 && index < r.selectedChoice && desired != r.selected && r.reason != "manual_override" {
			if r.recoveryNode != desired || r.recoveryChoice != index {
				r.recoveryNode = desired
				r.recoveryChoice = index
				r.recoverySince = now
			}
			if !r.definition.AutoRecover || now.Sub(r.switched) < time.Duration(r.definition.CooldownSeconds)*time.Second || now.Sub(r.recoverySince) < time.Duration(r.definition.RecoverySeconds)*time.Second {
				desired = r.selected
				index = r.selectedChoice
				reason = "recovery_hold"
			} else {
				r.recoveryNode = ""
				r.recoverySince = time.Time{}
			}
		} else {
			r.recoveryNode = ""
			r.recoverySince = time.Time{}
		}
	} else {
		r.recoveryNode = ""
		r.recoverySince = time.Time{}
	}
	r.selectedChoice = index
	e.recordSelectionLocked(r, desired, reason, now)
}
func (e *localPolicyEngine) recordSelectionLocked(r *localPolicyRuntime, id, reason string, now time.Time) {
	if r.selected == id && r.reason == reason {
		return
	}
	if r.selected != id {
		r.switched = now
	}
	r.selected = id
	r.reason = reason
	r.updated = now
	r.history = append(r.history, LocalPolicyHistory{At: now.UnixMilli(), NodeID: id, Reason: reason})
	if len(r.history) > 64 {
		r.history = append([]LocalPolicyHistory{}, r.history[len(r.history)-64:]...)
	}
}
func (e *localPolicyEngine) addSetSnapshotsLocked(result *LocalPolicySnapshot, now time.Time) {
	result.ChecksInFlight = e.workers
	result.ChecksWaiting = e.queueWaitingLocked(now)
	result.NodeSets = []LocalPolicyStatus{}
	for _, set := range e.config.NodeSets {
		r := e.sets[set.ID]
		if r == nil {
			continue
		}
		e.evaluateSetLocked(r, now)
		status := LocalPolicyStatus{PolicyID: set.ID, SelectedNodeID: r.selected, State: "active", Reason: r.reason, UpdatedAt: r.updated.UnixMilli(), History: localBoundedHistory(r.history), Nodes: []LocalPolicyNodeStatus{}}
		for _, id := range r.definition.CandidateNodeIDs {
			localCountStatus(&status.LocalPolicyCounts, e.nodeStatusLocked(r, id, now))
		}
		result.NodeSets = append(result.NodeSets, status)
	}
}
