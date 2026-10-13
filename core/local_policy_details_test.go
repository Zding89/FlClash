package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"testing"
	"time"

	C "github.com/metacubex/mihomo/constant"
)

func largeDetailsFixture(t *testing.T) *localPolicyEngine {
	t.Helper()
	e, _, _, _ := localFixture(t)
	base := e.config.Policies[0]
	e.config.Nodes = nil
	e.nodes = map[string]LocalPolicyNode{}
	proxy := e.proxies["a1"]
	for i := 0; i < 5000; i++ {
		id := fmt.Sprintf("n%04d", i)
		node := LocalPolicyNode{ID: id, SourceID: "a", ProxyName: "A1"}
		e.config.Nodes = append(e.config.Nodes, node)
		e.nodes[id] = node
		e.proxies[id] = proxy
	}
	e.config.Policies = nil
	e.policies = map[string]*localPolicyRuntime{}
	for i := 0; i < 100; i++ {
		p := base
		p.ID = fmt.Sprintf("p%03d", i)
		p.GroupName = p.ID
		p.CandidateNodeIDs = nil
		p.Choices = []LocalPolicyChoice{{Type: "nodeSet", ID: "all"}}
		e.config.Policies = append(e.config.Policies, p)
		e.policies[p.ID] = &localPolicyRuntime{definition: p, health: map[string]*localNodeHealth{}}
	}
	e.config.NodeSets = []LocalNodeSet{{ID: "all", SourceIDs: []string{"a"}, UnknownMultiplier: "exclude", Strategy: "stable", Probe: base.Probe, RecoverySeconds: 300, ImprovementPercent: 20}}
	if err := e.prepareNodeSets(&e.config); err != nil {
		t.Fatal(err)
	}
	for _, h := range e.sets["all"].health {
		h.healthy = true
		h.lastProbe = e.now()
		h.nextProbe = e.now().Add(time.Hour)
	}
	for _, r := range e.checkRuntimes() {
		for i := 0; i < 30; i++ {
			r.history = append(r.history, LocalPolicyHistory{At: int64(i), NodeID: "n0000", Reason: "fixture"})
		}
	}
	return e
}

func TestLocalPolicyRootBoundedAndDetailsPages(t *testing.T) {
	e := largeDetailsFixture(t)
	snapshot := e.snapshot()
	raw, err := json.Marshal(snapshot)
	if err != nil || len(raw) >= 1<<20 {
		t.Fatalf("root size=%d err=%v", len(raw), err)
	}
	for _, p := range snapshot.Policies {
		if len(p.Nodes) > 1 || len(p.History) != 8 {
			t.Fatalf("unbounded dynamic rule %s nodes=%d history=%d", p.PolicyID, len(p.Nodes), len(p.History))
		}
	}
	if len(snapshot.NodeSets) != 1 || len(snapshot.NodeSets[0].Nodes) != 0 || snapshot.NodeSets[0].MemberCount != 5000 || snapshot.NodeSets[0].AvailableCount != 5000 {
		t.Fatal(snapshot.NodeSets)
	}
	input := LocalPolicyDetailsRequest{Revision: e.config.Revision, NodeSetID: "all", Limit: 200, IncludeUnavailable: true}
	for offset := 0; offset < 5000; offset += 200 {
		input.Offset = offset
		page, err := e.details(input)
		if err != nil || len(page.Nodes) != 200 || page.Total != 5000 || page.Offset != offset || page.HasMore != (offset+200 < 5000) || page.SampleAt != e.now().UnixMilli() {
			t.Fatalf("page=%+v err=%v", page, err)
		}
		if page.Nodes[0].NodeID != fmt.Sprintf("n%04d", offset) {
			t.Fatal("page ordering changed")
		}
	}
	e.sets["all"].health["n0000"].healthy = false
	input.Offset, input.IncludeUnavailable = 0, false
	page, err := e.details(input)
	if err != nil || page.Total != 4999 || page.UnavailableCount != 1 || page.Nodes[0].NodeID != "n0001" {
		t.Fatalf("filtered page=%+v err=%v", page, err)
	}
	input.NodeSetID, input.PolicyID = "", "p000"
	page, err = e.details(input)
	if err != nil || len(page.Nodes) != 200 || page.Total != 4999 {
		t.Fatalf("rule page=%+v err=%v", page, err)
	}
	input.Revision++
	if _, err := e.details(input); err == nil {
		t.Fatal("stale revision accepted")
	}
	e.stop()
	input.Revision--
	if _, err := e.details(input); err == nil {
		t.Fatal("disabled engine accepted old detail read")
	}
	t.Logf("5000 members / 100 shared rules root bytes=%d", len(raw))
}

func TestLocalPolicyDetailsStrictInput(t *testing.T) {
	valid := map[string]any{"revision": 3, "nodeSetId": "all", "offset": 0, "limit": 200, "includeUnavailable": true}
	for key, value := range map[string]any{"limit": 201, "offset": 5001, "revision": -1, "policyId": "p", "unknown": true} {
		input := map[string]any{}
		for k, v := range valid {
			input[k] = v
		}
		input[key] = value
		raw, _ := json.Marshal(input)
		if _, err := decodeLocalPolicyDetails(raw); err == nil {
			t.Fatal("invalid input accepted", input)
		}
	}
	raw, _ := json.Marshal(valid)
	if _, err := decodeLocalPolicyDetails(raw); err != nil {
		t.Fatal(err)
	}
	if _, err := decodeLocalPolicyDetails(append(raw, raw...)); err == nil {
		t.Fatal("trailing JSON accepted")
	}
}

func TestSharedHealthSamplesCountOnceAndParametersStayIsolated(t *testing.T) {
	e, _, _, _ := localFixture(t)
	first := e.policies["p"]
	first.definition.CandidateNodeIDs = []string{"a1"}
	first.health = map[string]*localNodeHealth{"a1": e.sharedHealthLocked(first, "a1")}
	second := &localPolicyRuntime{definition: first.definition, health: map[string]*localNodeHealth{}}
	second.definition.ID = "p2"
	second.health["a1"] = e.sharedHealthLocked(second, "a1")
	if first.health["a1"] != second.health["a1"] {
		t.Fatal("same parameters did not share health")
	}
	isolated := []*localPolicyRuntime{}
	for i := 0; i < 4; i++ {
		r := &localPolicyRuntime{definition: first.definition, health: map[string]*localNodeHealth{}}
		switch i {
		case 0:
			r.definition.Probe.SuccessThreshold++
		case 1:
			r.definition.Probe.ValiditySeconds++
		case 2:
			r.definition.RecoverySeconds++
		case 3:
			r.definition.Probe.FailureThreshold++
		}
		r.health["a1"] = e.sharedHealthLocked(r, "a1")
		if r.health["a1"] == first.health["a1"] {
			t.Fatal("distinct parameters shared health", i)
		}
		isolated = append(isolated, r)
	}
	for _, fail := range []bool{false, true} {
		e.probe = func(context.Context, C.Proxy, LocalPolicyProbe) error {
			if fail {
				return errors.New("fixture failure")
			}
			return nil
		}
		key := localNetworkProbeKey(first, "a1")
		e.inFlight[key] = []localProbeCandidate{{runtime: first, nodeID: "a1"}, {runtime: second, nodeID: "a1"}}
		for _, r := range isolated {
			e.inFlight[key] = append(e.inFlight[key], localProbeCandidate{runtime: r, nodeID: "a1"})
		}
		e.workers++
		e.wg.Add(1)
		e.runSharedProbe(key, e.proxies["a1"], e.epoch)
		h := first.health["a1"]
		if (!fail && h.successes != 1) || (fail && h.failures != 1) {
			t.Fatalf("network sample counted more than once successes=%d failures=%d", h.successes, h.failures)
		}
		for _, r := range isolated {
			if (!fail && r.health["a1"].successes != 1) || (fail && r.health["a1"].failures != 1) {
				t.Fatal("distinct state did not get network sample")
			}
		}
	}
}

func TestLocalPolicySimulationSharedThresholdNotMultiplied(t *testing.T) {
	input := simulationFixture()
	no := false
	input.Health = map[string]*bool{"a1": &no, "b2": &no, "c3": &no}
	p := input.Config.Policies[0]
	p.CandidateNodeIDs = nil
	p.Choices = []LocalPolicyChoice{{Type: "nodeSet", ID: "one"}, {Type: "nodeSet", ID: "two"}}
	input.Config.Policies = []LocalPolicyDefinition{p}
	for _, id := range []string{"one", "two"} {
		input.Config.NodeSets = append(input.Config.NodeSets, LocalNodeSet{ID: id, SourceIDs: []string{"a"}, UnknownMultiplier: "exclude", Strategy: "stable", Probe: p.Probe, ImprovementPercent: 20})
	}
	input.Steps = []LocalPolicySimulationStep{{At: input.Now + 1000, Probes: []LocalPolicySimulationProbe{{NodeID: "a1", Success: true}}}, {At: input.Now + 2000, Probes: []LocalPolicySimulationProbe{{NodeID: "a1", Success: true}}}}
	result, err := simulateLocalPolicies(input)
	if err != nil {
		t.Fatal(err)
	}
	if result.Steps[1].Decisions[0].SelectedNodeID != "" || result.Steps[2].Decisions[0].SelectedNodeID != "a1" {
		t.Fatal("one simulation sample incorrectly satisfied success threshold", result.Steps)
	}
}

func TestMixedChoicesPreferredRecoveryRequiresContinuousObservation(t *testing.T) {
	for _, preferredSet := range []bool{false, true} {
		e, _, _, now := localFixture(t)
		r := e.policies["p"]
		r.definition.CandidateNodeIDs = nil
		r.definition.Choices = []LocalPolicyChoice{{Type: "node", ID: "a1"}, {Type: "node", ID: "b2"}}
		r.definition.RecoverySeconds = 300
		r.definition.CooldownSeconds = 60
		if preferredSet {
			e.config.NodeSets = []LocalNodeSet{{ID: "first", SourceIDs: []string{"a"}, UnknownMultiplier: "exclude", Strategy: "stable", Probe: r.definition.Probe, ImprovementPercent: 20}}
			r.definition.Choices[0] = LocalPolicyChoice{Type: "nodeSet", ID: "first"}
			e.config.Policies[0] = r.definition
			if err := e.prepareNodeSets(&e.config); err != nil {
				t.Fatal(err)
			}
		}
		healthyLocalNodes(e)
		first := r.health["a1"]
		if preferredSet {
			first = e.sets["first"].health["a1"]
		}
		first.healthy = false
		expectLocalNode(t, e, "b2")
		*now = now.Add(61 * time.Second)
		first.healthy = true
		first.lastProbe = *now
		expectLocalNode(t, e, "b2")
		*now = now.Add(299 * time.Second)
		first.lastProbe = *now
		expectLocalNode(t, e, "b2")
		first.healthy = false
		expectLocalNode(t, e, "b2")
		*now = now.Add(time.Second)
		first.healthy = true
		first.lastProbe = *now
		expectLocalNode(t, e, "b2")
		*now = now.Add(299 * time.Second)
		first.lastProbe = *now
		expectLocalNode(t, e, "b2")
		*now = now.Add(time.Second)
		first.lastProbe = *now
		expectLocalNode(t, e, "a1")
	}
}
