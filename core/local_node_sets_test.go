package main

import (
	C "github.com/metacubex/mihomo/constant"
	"testing"
	"time"
)

func TestDynamicSetKeepsUnknownAndScope(t *testing.T) {
	e, _, _, now := localFixture(t)
	jp, hk := "JP", "HK"
	half := 0.5
	cap := 1.0
	a, b, c := e.config.Nodes[0], e.config.Nodes[1], e.config.Nodes[2]
	a.Region = &jp
	a.Multiplier = &half
	b.Region = &jp
	c.Region = &hk
	e.config.Nodes = []LocalPolicyNode{a, b, c}
	for _, n := range e.config.Nodes {
		e.nodes[n.ID] = n
	}
	set := LocalNodeSet{ID: "jp", SourceIDs: []string{"a", "b", "c"}, Regions: []string{"JP"}, MaxMultiplier: &cap, UnknownMultiplier: "assumeOne", Strategy: "multiplier", Probe: e.config.Policies[0].Probe, ImprovementPercent: 20}
	e.config.NodeSets = []LocalNodeSet{set}
	e.config.Policies[0].CandidateNodeIDs = nil
	e.config.Policies[0].Choices = []LocalPolicyChoice{{Type: "nodeSet", ID: "jp"}, {Type: "node", ID: "c3"}}
	if err := validateLocalPolicyConfig(&e.config); err != nil {
		t.Fatal(err)
	}
	e.prepareNodeSets(&e.config)
	r := e.policies["p"]
	r.definition = e.config.Policies[0]
	r.health = map[string]*localNodeHealth{"c3": {healthy: true, lastProbe: *now}}
	sr := e.sets["jp"]
	for _, h := range sr.health {
		h.healthy = true
		h.lastProbe = *now
	}
	expectLocalNode(t, e, "a1")
	sr.health["a1"].healthy = false
	expectLocalNode(t, e, "b2")
	sr.health["b2"].healthy = false
	expectLocalNode(t, e, "c3")
	if e.nodes["b2"].Multiplier != nil {
		t.Fatal("unknown fact was overwritten")
	}
}
func TestScheduleAdapterPassesOutsideWindow(t *testing.T) {
	e, _, _, now := localFixture(t)
	healthyLocalNodes(e)
	r := e.policies["p"]
	r.definition.Schedule = &LocalPolicySchedule{TimeZone: "Asia/Shanghai", Windows: []LocalPolicyScheduleWindow{{Weekdays: []int{2}, StartMinute: 720, EndMinute: 721}}}
	a := &localManagedAdapter{engine: e, policyID: "p"}
	if a.Type() != C.Selector {
		t.Fatal("start must be included")
	}
	*now = now.Add(time.Minute)
	if a.Type() != C.Pass {
		t.Fatal("end must skip matching rule")
	}
	if e.snapshot().Policies[0].State != "skipped" {
		t.Fatal("snapshot must distinguish skip from fallback")
	}
}
func TestKnownExhaustionCannotBeClearedByMissingRefresh(t *testing.T) {
	e, _, _, now := localFixture(t)
	healthyLocalNodes(e)
	zero := int64(0)
	s := e.sources["a"]
	s.RemainingBytes = &zero
	e.sources["a"] = s
	expectLocalNode(t, e, "b2")
	observed := now.UnixMilli()
	if err := e.refreshSource(LocalPolicySourceRefresh{Revision: 3, Sequence: 1, Source: LocalPolicySourceMetadata{ID: "a", ObservedAt: &observed}}); err != "" {
		t.Fatal(err)
	}
	expectLocalNode(t, e, "b2")
	remaining := int64(100)
	if err := e.refreshSource(LocalPolicySourceRefresh{Revision: 3, Sequence: 2, Source: LocalPolicySourceMetadata{ID: "a", ObservedAt: &observed, RemainingBytes: &remaining}}); err != "" {
		t.Fatal(err)
	}
	*now = now.Add(301 * time.Second)
	expectLocalNode(t, e, "a1")
}
func TestProbeSampleExpiryAndZeroLatencyOptimization(t *testing.T) {
	e, _, _, now := localFixture(t)
	healthyLocalNodes(e)
	e.policies["p"].definition.Probe.ValiditySeconds = 60
	*now = now.Add(time.Minute)
	expectLocalNode(t, e, "")
}
