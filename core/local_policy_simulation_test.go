package main

import (
	"testing"
	"time"
)

func simulationFixture() LocalPolicySimulationInput {
	yes := true
	now := time.Date(2026, 10, 13, 12, 0, 0, 0, time.FixedZone("Asia/Shanghai", 28800)).UnixMilli()
	return LocalPolicySimulationInput{Now: now, AvailableNodeIDs: []string{"a1", "b2", "c3"}, Health: map[string]*bool{"a1": &yes, "b2": &yes, "c3": &yes}, Config: LocalPolicyConfig{SchemaVersion: 1, Revision: 1, Enabled: true, Sources: []LocalPolicySource{{ID: "a"}, {ID: "b"}, {ID: "c"}}, Nodes: []LocalPolicyNode{{ID: "a1", SourceID: "a", ProxyName: "A1"}, {ID: "b2", SourceID: "b", ProxyName: "B2"}, {ID: "c3", SourceID: "c", ProxyName: "C3"}}, Policies: []LocalPolicyDefinition{{ID: "p", Enabled: true, GroupName: "managed", CandidateNodeIDs: []string{"a1", "b2"}, Probe: LocalPolicyProbe{URL: "https://probe.example", ExpectedStatus: "200-399", IntervalSeconds: 30, TimeoutSeconds: 5, FailureThreshold: 3, SuccessThreshold: 2}, Guard: LocalPolicyGuard{UnknownBehavior: "exclude"}, AutoRecover: true, RecoverySeconds: 300, CooldownSeconds: 60, Fallback: "reject"}}}}
}
func TestLocalPolicySimulationSharesFailureAndRecoveryStateMachine(t *testing.T) {
	input := simulationFixture()
	for _, seconds := range []int64{30, 60, 90} {
		input.Steps = append(input.Steps, LocalPolicySimulationStep{At: input.Now + seconds*1000, Probes: []LocalPolicySimulationProbe{{NodeID: "a1", Success: false}}})
	}
	for _, seconds := range []int64{120, 150, 180, 420} {
		input.Steps = append(input.Steps, LocalPolicySimulationStep{At: input.Now + seconds*1000, Probes: []LocalPolicySimulationProbe{{NodeID: "a1", Success: true}}})
	}
	active := activeLocalPolicy.Load()
	result, err := simulateLocalPolicies(input)
	if err != nil {
		t.Fatal(err)
	}
	want := []string{"a1", "a1", "a1", "b2", "b2", "b2", "b2", "a1"}
	for i, frame := range result.Steps {
		if got := frame.Decisions[0].SelectedNodeID; got != want[i] {
			t.Fatalf("step %d selected %s, want %s", i, got, want[i])
		}
	}
	if activeLocalPolicy.Load() != active {
		t.Fatal("simulation changed active runtime")
	}
}
func TestLocalPolicySimulationMissingBudgetIsUnknownAndExplicitUsageExcludes(t *testing.T) {
	input := simulationFixture()
	input.Config.Budgets = []LocalPolicyBudget{{SourceID: "a", LimitBytes: 100, ResetDay: 1, TimeZone: "Asia/Shanghai"}}
	result, err := simulateLocalPolicies(input)
	if err != nil {
		t.Fatal(err)
	}
	if result.Snapshot.Policies[0].SelectedNodeID != "b2" || result.Snapshot.Policies[0].Nodes[0].Reason != "budget_untrusted" {
		t.Fatal(result.Snapshot)
	}
	input.LocalUsage = map[string]int64{"a": 99}
	input.Steps = []LocalPolicySimulationStep{{At: input.Now + 1, Usage: map[string]int64{"a": 100}}}
	result, err = simulateLocalPolicies(input)
	if err != nil {
		t.Fatal(err)
	}
	if result.Steps[0].Decisions[0].SelectedNodeID != "a1" || result.Steps[1].Decisions[0].SelectedNodeID != "b2" {
		t.Fatal(result.Steps)
	}
}
func TestLocalPolicySimulationHardExclusionOverridesManualChoice(t *testing.T) {
	input := simulationFixture()
	expiry := input.Now + 1
	input.Config.Sources[0].ExpiresAt = &expiry
	input.Config.Overrides = []LocalPolicyOverride{{PolicyID: "p", NodeID: "a1", ExpiresAt: input.Now + 3600000}}
	input.Steps = []LocalPolicySimulationStep{{At: expiry}}
	result, err := simulateLocalPolicies(input)
	if err != nil {
		t.Fatal(err)
	}
	if result.Steps[0].Decisions[0].SelectedNodeID != "a1" || result.Steps[1].Decisions[0].SelectedNodeID != "b2" {
		t.Fatal(result.Steps)
	}
	input.AvailableNodeIDs = []string{"c3"}
	result, err = simulateLocalPolicies(input)
	if err != nil {
		t.Fatal(err)
	}
	if result.Snapshot.Policies[0].SelectedNodeID != "" || result.Snapshot.Policies[0].State != "reject" {
		t.Fatal("unlisted C3 or DIRECT escaped fallback", result.Snapshot)
	}
}
func TestLocalPolicySimulationRejectsUnboundedAndReorderedInputs(t *testing.T) {
	input := simulationFixture()
	input.Steps = []LocalPolicySimulationStep{{At: input.Now - 1}}
	if _, err := simulateLocalPolicies(input); err == nil {
		t.Fatal("accepted backwards simulation step")
	}
	input.Steps = make([]LocalPolicySimulationStep, 33)
	if _, err := simulateLocalPolicies(input); err == nil {
		t.Fatal("accepted unbounded timeline")
	}
}
