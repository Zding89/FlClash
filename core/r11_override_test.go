package main

import (
	"encoding/json"
	"strings"
	"testing"
	"time"
)

func remediationBoundSets(t *testing.T) (*localPolicyEngine, *time.Time) {
	t.Helper()
	e, _, _, now := localFixture(t)
	healthyLocalNodes(e)
	jp := "JP"
	for i, node := range e.config.Nodes {
		node.Region = &jp
		e.config.Nodes[i] = node
		e.nodes[node.ID] = node
	}
	probe := e.config.Policies[0].Probe
	probe.Method = "GET"
	e.config.NodeSets = []LocalNodeSet{
		{ID: "A", SourceIDs: []string{"a", "b"}, Regions: []string{"JP"}, UnknownMultiplier: "exclude", Strategy: "stable", Probe: probe, ImprovementPercent: 20},
		{ID: "B", SourceIDs: []string{"b"}, UnknownMultiplier: "exclude", Strategy: "stable", Probe: probe, ImprovementPercent: 20},
	}
	e.config.Policies[0].CandidateNodeIDs = nil
	e.config.Policies[0].Choices = []LocalPolicyChoice{{Type: "nodeSet", ID: "A"}, {Type: "nodeSet", ID: "B"}}
	e.config.Policies[0].AutoRecover = false
	if err := e.prepareNodeSets(&e.config); err != nil {
		t.Fatal(err)
	}
	e.policies["p"].definition = e.config.Policies[0]
	for _, set := range e.sets {
		for _, h := range set.health {
			h.healthy = true
			h.healthySince = now.Add(-time.Hour)
			h.lastProbe = *now
		}
	}
	return e, now
}

func TestRemediationR11OriginSetCannotBorrowOtherMembership(t *testing.T) {
	e, now := remediationBoundSets(t)
	e.config.Overrides = []LocalPolicyOverride{{PolicyID: "p", NodeID: "b2", NodeSetID: "A", ExpiresAt: now.Add(time.Minute).UnixMilli()}}
	expectLocalNode(t, e, "b2")
	hk := "HK"
	node := e.nodes["b2"]
	node.Region = &hk
	e.nodes["b2"] = node
	for i, n := range e.config.Nodes {
		if n.ID == node.ID {
			e.config.Nodes[i] = node
		}
	}
	if !e.setDefinitions["B"].includes(node) {
		t.Fatal("fixture must retain node in B")
	}
	expectLocalNode(t, e, "a1")
	if e.policies["p"].reason == "manual_override" {
		t.Fatal("override borrowed B")
	}
}

func TestRemediationR11InvalidBindingsAreInactive(t *testing.T) {
	for _, origin := range []string{"", "not-referenced"} {
		t.Run("origin="+origin, func(t *testing.T) {
			e, now := remediationBoundSets(t)
			e.config.Overrides = []LocalPolicyOverride{{PolicyID: "p", NodeID: "b2", NodeSetID: origin, ExpiresAt: now.Add(time.Minute).UnixMilli()}}
			expectLocalNode(t, e, "a1")
			e.retainBoundOverrides(&e.config)
			if len(e.config.Overrides) != 0 {
				t.Fatal("stale binding survived configuration retention")
			}
		})
	}
}

func TestRemediationR11BindingExpiresCancelsOrLosesReference(t *testing.T) {
	for _, end := range []string{"expire", "cancel", "remove-choice", "remove-set", "unhealthy", "source-restricted", "rule-guard", "budget", "origin-check"} {
		t.Run(end, func(t *testing.T) {
			e, now := remediationBoundSets(t)
			e.config.Overrides = []LocalPolicyOverride{{PolicyID: "p", NodeID: "b2", NodeSetID: "A", ExpiresAt: now.Add(time.Minute).UnixMilli()}}
			expectLocalNode(t, e, "b2")
			want := "a1"
			switch end {
			case "expire":
				*now = now.Add(time.Minute)
			case "cancel":
				e.config.Overrides = nil
			case "remove-choice":
				e.policies["p"].definition.Choices = []LocalPolicyChoice{{Type: "nodeSet", ID: "B"}}
				want = "b2"
			case "remove-set":
				delete(e.sets, "A")
				want = "b2"
			case "unhealthy":
				e.sets["A"].health["b2"].healthy = false
			case "rule-guard":
				e.policies["p"].definition.Guard.MinRemainingBytes = 1000
				observed, low, enough := now.UnixMilli(), int64(500), int64(2000)
				e.sources["b"] = LocalPolicySource{ID: "b", RemainingBytes: &low, ObservedAt: &observed}
				e.sources["a"] = LocalPolicySource{ID: "a", RemainingBytes: &enough, ObservedAt: &observed}
			case "budget":
				e.ledger.configure([]LocalPolicyBudget{{SourceID: "b", LimitBytes: 1, ResetDay: 1, TimeZone: "Asia/Shanghai"}}, *now)
				e.ledger.count("b", 2, *now)
			case "origin-check":
				e.sets["A"].health["b2"].healthy = false
				e.sets["B"].health["b2"] = &localNodeHealth{healthy: true, lastProbe: *now, healthySince: now.Add(-time.Hour)}
			case "source-restricted":
				zero := int64(0)
				source := e.sources["b"]
				source.RemainingBytes = &zero
				e.sources["b"] = source
			}
			expectLocalNode(t, e, want)
			if e.policies["p"].reason == "manual_override" {
				t.Fatal("invalid override remains active")
			}
		})
	}
}

func TestRemediationR11RebuildDropsStaleOriginBinding(t *testing.T) {
	e, now := remediationBoundSets(t)
	e.config.Overrides = []LocalPolicyOverride{{PolicyID: "p", NodeID: "b2", NodeSetID: "A", ExpiresAt: now.Add(time.Minute).UnixMilli()}}
	for i, node := range e.config.Nodes {
		if node.ID == "b2" {
			hk := "HK"
			node.Region = &hk
			e.config.Nodes[i] = node
		}
	}
	if err := validateLocalPolicyConfig(&e.config); err != nil {
		t.Fatalf("stale binding must not prevent rebuild: %v", err)
	}
	_, cfg, _, _ := localFixture(t)
	rebuilt, err := prepareLocalPolicy(&e.config, cfg, e.ledger)
	if err != nil {
		t.Fatal(err)
	}
	defer rebuilt.stop()
	rebuilt.now = e.now
	for _, set := range rebuilt.sets {
		for _, h := range set.health {
			h.healthy = true
			h.lastProbe = *now
			h.healthySince = now.Add(-time.Hour)
		}
	}
	if len(rebuilt.config.Overrides) != 0 {
		t.Fatal("rebuild retained invalid original set")
	}
	expectLocalNode(t, rebuilt, "a1")
}

func TestRemediationR11LegacyFixedOverrideCompatibility(t *testing.T) {
	for _, choices := range []bool{false, true} {
		name := "legacy-fixed"
		if choices {
			name = "new-fixed"
		}
		t.Run(name, func(t *testing.T) {
			e, _, _, now := localFixture(t)
			healthyLocalNodes(e)
			if choices {
				e.policies["p"].definition.CandidateNodeIDs = nil
				e.policies["p"].definition.Choices = []LocalPolicyChoice{{Type: "node", ID: "a1"}, {Type: "node", ID: "b2"}}
			}
			o := LocalPolicyOverride{PolicyID: "p", NodeID: "b2", ExpiresAt: now.Add(time.Minute).UnixMilli()}
			data, err := json.Marshal(o)
			if err != nil {
				t.Fatal(err)
			}
			if strings.Contains(string(data), "nodeSetId") {
				t.Fatal("fixed identity field was not omitted")
			}
			var decoded LocalPolicyOverride
			if err := json.Unmarshal(data, &decoded); err != nil {
				t.Fatal(err)
			}
			e.config.Overrides = []LocalPolicyOverride{decoded}
			expectLocalNode(t, e, "b2")
			e.config.Overrides[0].NodeSetID = "A"
			expectLocalNode(t, e, "a1")
		})
	}
}

func TestRemediationR11FixedEligibilityUsesItsOwnCheck(t *testing.T) {
	for _, fixedHealthy := range []bool{false, true} {
		name := "fixed-fails-set-succeeds"
		if fixedHealthy {
			name = "fixed-succeeds-set-fails"
		}
		t.Run(name, func(t *testing.T) {
			e, now := remediationBoundSets(t)
			r := e.policies["p"]
			r.definition.Choices = []LocalPolicyChoice{{Type: "node", ID: "b2"}, {Type: "nodeSet", ID: "A"}}
			r.health["b2"].healthy = fixedHealthy
			e.sets["A"].health["b2"].healthy = !fixedHealthy
			if r.health["b2"] == e.sets["A"].health["b2"] {
				t.Fatal("fixture requires distinct checks")
			}
			policy, err := e.details(LocalPolicyDetailsRequest{Revision: e.config.Revision, PolicyID: "p", Limit: 20, IncludeUnavailable: true})
			if err != nil {
				t.Fatal(err)
			}
			var found bool
			for _, node := range policy.Nodes {
				if node.NodeID == "b2" {
					found = true
					if !node.Eligible || node.FixedEligible == nil || *node.FixedEligible != fixedHealthy {
						t.Fatalf("unexpected policy node: %+v", node)
					}
				}
			}
			if !found {
				t.Fatal("fixed member missing")
			}
			set, err := e.details(LocalPolicyDetailsRequest{Revision: e.config.Revision, NodeSetID: "A", Limit: 20, IncludeUnavailable: true})
			if err != nil {
				t.Fatal(err)
			}
			for _, node := range set.Nodes {
				if node.FixedEligible != nil {
					t.Fatal("set details must omit fixedEligible")
				}
				if node.NodeID == "b2" && node.Eligible == fixedHealthy {
					t.Fatalf("set check contaminated: %+v at %v", node, now)
				}
			}
			for _, node := range policy.Nodes {
				if node.NodeID == "a1" && node.FixedEligible != nil {
					t.Fatal("dynamic-only node got fixed eligibility")
				}
			}
		})
	}
}
