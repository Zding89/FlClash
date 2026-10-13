package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"io"
	"sort"
	"strings"
	"time"
)

type LocalPolicyDetailsRequest struct {
	Revision           int64  `json:"revision"`
	PolicyID           string `json:"policyId"`
	NodeSetID          string `json:"nodeSetId"`
	Offset             int    `json:"offset"`
	Limit              int    `json:"limit"`
	IncludeUnavailable bool   `json:"includeUnavailable"`
}
type LocalPolicyCounts struct {
	MemberCount      int    `json:"memberCount"`
	AvailableCount   int    `json:"availableCount"`
	PendingCount     int    `json:"pendingCount"`
	UnavailableCount int    `json:"unavailableCount"`
	RestrictedCount  int    `json:"restrictedCount"`
	LastProbeAt      *int64 `json:"lastProbeAt"`
}
type LocalPolicyDetails struct {
	LocalPolicyCounts
	Revision       int64                   `json:"revision"`
	TargetID       string                  `json:"targetId"`
	PolicyID       string                  `json:"policyId,omitempty"`
	NodeSetID      string                  `json:"nodeSetId,omitempty"`
	SampleAt       int64                   `json:"sampleAt"`
	Total          int                     `json:"total"`
	Offset         int                     `json:"offset"`
	Limit          int                     `json:"limit"`
	HasMore        bool                    `json:"hasMore"`
	ChecksWaiting  int                     `json:"checksWaiting"`
	ChecksInFlight int                     `json:"checksInFlight"`
	Probe          *LocalPolicyProbe       `json:"probe,omitempty"`
	Nodes          []LocalPolicyNodeStatus `json:"nodes"`
}

func decodeLocalPolicyDetails(raw json.RawMessage) (LocalPolicyDetailsRequest, error) {
	var input LocalPolicyDetailsRequest
	if len(raw) > 4096 {
		return input, errors.New("local_policy_details_invalid")
	}
	decoder := json.NewDecoder(bytes.NewReader(raw))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&input); err != nil {
		return input, errors.New("local_policy_details_invalid")
	}
	if decoder.Decode(&struct{}{}) != io.EOF || input.Revision < 0 || input.Offset < 0 || input.Offset > 5000 || input.Limit < 1 || input.Limit > 200 || (input.PolicyID == "") == (input.NodeSetID == "") || len(input.PolicyID) > 128 || len(input.NodeSetID) > 128 {
		return input, errors.New("local_policy_details_invalid")
	}
	return input, nil
}
func localBoundedHistory(values []LocalPolicyHistory) []LocalPolicyHistory {
	if len(values) > 8 {
		values = values[len(values)-8:]
	}
	return append([]LocalPolicyHistory{}, values...)
}
func (e *localPolicyEngine) beginSelectionRoundLocked() func() {
	e.selectionRoundActive = true
	if e.evaluatedSets == nil {
		e.evaluatedSets = map[string]bool{}
	} else {
		clear(e.evaluatedSets)
	}
	return func() { e.selectionRoundActive = false }
}
func (e *localPolicyEngine) nodeHealthForPolicyLocked(r *localPolicyRuntime, id string, now time.Time) (*localNodeHealth, string) {
	if len(r.definition.Choices) == 0 || r.setID != "" {
		return r.health[id], e.nodeReasonLocked(r, id, now)
	}
	guardReason := e.sourceReasonLocked(id, r.definition, now)
	var first *localNodeHealth
	reason := "outside_node_set"
	for _, choice := range r.definition.Choices {
		runtime := r
		if choice.Type == "node" {
			if choice.ID != id {
				continue
			}
		} else {
			runtime = e.sets[choice.ID]
			if runtime == nil {
				continue
			}
		}
		h := runtime.health[id]
		if h == nil {
			continue
		}
		if guardReason != "" {
			return h, guardReason
		}
		current := e.nodeReasonLocked(runtime, id, now)
		if current == "" {
			return h, ""
		}
		if first == nil {
			first, reason = h, current
		}
	}
	return first, reason
}
func (e *localPolicyEngine) nodeStatusLocked(r *localPolicyRuntime, id string, now time.Time) LocalPolicyNodeStatus {
	h, reason := e.nodeHealthForPolicyLocked(r, id, now)
	result := LocalPolicyNodeStatus{NodeID: id, Reason: reason, Eligible: reason == ""}
	if h == nil {
		return result
	}
	result.Healthy = h.healthy
	result.ProbePending = h.pending
	result.DetectionDelayed = !h.pending && ((h.nextProbe.IsZero() && e.workers >= 8) || (!h.nextProbe.IsZero() && now.After(h.nextProbe.Add(time.Second)))) && (reason == "" || reason == "probing" || reason == "unhealthy")
	if !h.lastProbe.IsZero() {
		value := h.lastProbe.UnixMilli()
		result.LastProbeAt = &value
	}
	if h.latencyMillis != nil {
		value := *h.latencyMillis
		result.LatencyMillis = &value
	}
	return result
}
func localCountStatus(counts *LocalPolicyCounts, node LocalPolicyNodeStatus) {
	counts.MemberCount++
	if node.Eligible {
		counts.AvailableCount++
	} else {
		counts.UnavailableCount++
	}
	if node.ProbePending || node.Reason == "probing" || node.Reason == "probe_expired" {
		counts.PendingCount++
	}
	if strings.HasPrefix(node.Reason, "source_") || strings.HasPrefix(node.Reason, "metadata_") || strings.HasPrefix(node.Reason, "budget_") || node.Reason == "ledger_untrusted" {
		counts.RestrictedCount++
	}
	if node.LastProbeAt != nil && (counts.LastProbeAt == nil || *node.LastProbeAt > *counts.LastProbeAt) {
		value := *node.LastProbeAt
		counts.LastProbeAt = &value
	}
}
func (e *localPolicyEngine) queueWaitingLocked(now time.Time) int {
	values := map[localProbeKey]bool{}
	for _, r := range e.checkRuntimes() {
		for _, id := range localFixedCandidates(r.definition) {
			h := r.health[id]
			if h == nil || h.pending || now.Before(h.nextProbe) || e.sourceReasonLocked(id, r.definition, now) != "" || (r.definition.Probe.Automatic != nil && !*r.definition.Probe.Automatic && !e.manualCheckNeeded(r, id)) {
				continue
			}
			values[localNetworkProbeKey(r, id)] = true
		}
	}
	return len(values)
}
func (e *localPolicyEngine) details(input LocalPolicyDetailsRequest) (LocalPolicyDetails, error) {
	e.mu.Lock()
	defer e.mu.Unlock()
	if e.stopped || input.Revision != e.config.Revision {
		return LocalPolicyDetails{}, errors.New("local_policy_revision_conflict")
	}
	if input.Offset < 0 || input.Offset > 5000 || input.Limit < 1 || input.Limit > 200 || (input.PolicyID == "") == (input.NodeSetID == "") {
		return LocalPolicyDetails{}, errors.New("local_policy_details_invalid")
	}
	r := e.policies[input.PolicyID]
	if input.NodeSetID != "" {
		r = e.sets[input.NodeSetID]
	}
	if r == nil {
		return LocalPolicyDetails{}, errors.New("local_policy_details_missing")
	}
	now := e.now()
	ids := map[string]bool{}
	for _, id := range localFixedCandidates(r.definition) {
		ids[id] = true
	}
	for _, choice := range r.definition.Choices {
		if choice.Type == "nodeSet" {
			if set := e.sets[choice.ID]; set != nil {
				for _, id := range set.definition.CandidateNodeIDs {
					ids[id] = true
				}
			}
		}
	}
	ordered := make([]string, 0, len(ids))
	for id := range ids {
		ordered = append(ordered, id)
	}
	sort.Strings(ordered)
	result := LocalPolicyDetails{Revision: e.config.Revision, TargetID: e.config.TargetID, PolicyID: input.PolicyID, NodeSetID: input.NodeSetID, SampleAt: now.UnixMilli(), Offset: input.Offset, Limit: input.Limit, Nodes: []LocalPolicyNodeStatus{}, ChecksInFlight: e.workers, ChecksWaiting: e.queueWaitingLocked(now)}
	if input.NodeSetID != "" {
		probe := r.definition.Probe
		result.Probe = &probe
	}
	for _, id := range ordered {
		node := e.nodeStatusLocked(r, id, now)
		localCountStatus(&result.LocalPolicyCounts, node)
		if !input.IncludeUnavailable && !node.Eligible {
			continue
		}
		index := result.Total
		result.Total++
		if index >= input.Offset && len(result.Nodes) < input.Limit {
			result.Nodes = append(result.Nodes, node)
		}
	}
	result.HasMore = input.Offset+len(result.Nodes) < result.Total
	return result, nil
}
func handleGetLocalPolicyDetails(input LocalPolicyDetailsRequest) (LocalPolicyDetails, error) {
	if e := activeLocalPolicy.Load(); e != nil {
		return e.details(input)
	}
	return LocalPolicyDetails{}, errors.New("local_policy_inactive")
}

type localHealthKey struct {
	Network   localProbeKey
	Interval  int
	Retry     int
	Validity  int
	Failures  int
	Successes int
	Recovery  int
	Automatic bool
}

func localNetworkProbeKey(r *localPolicyRuntime, id string) localProbeKey {
	probe := r.definition.Probe
	status := probe.ExpectedStatus
	if status == "" {
		status = "200-399"
	}
	return localProbeKey{nodeID: id, method: localProbeMethod(probe), url: probe.URL, status: status, timeout: probe.TimeoutSeconds, unknown: r.definition.Guard.UnknownBehavior}
}
func (e *localPolicyEngine) sharedHealthLocked(r *localPolicyRuntime, id string) *localNodeHealth {
	if e.healthPool == nil {
		e.healthPool = map[localHealthKey]*localNodeHealth{}
	}
	p := r.definition.Probe
	key := localHealthKey{Network: localNetworkProbeKey(r, id), Interval: p.IntervalSeconds, Retry: p.RetrySeconds, Validity: p.ValiditySeconds, Failures: p.FailureThreshold, Successes: p.SuccessThreshold, Recovery: r.definition.RecoverySeconds, Automatic: p.Automatic == nil || *p.Automatic}
	h := e.healthPool[key]
	if h == nil {
		h = &localNodeHealth{}
		e.healthPool[key] = h
	}
	return h
}
