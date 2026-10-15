package main

import (
	"fmt"
	"reflect"
	"strings"
	"testing"
)

func TestLocalFlowSimulationUsesActualOrderedRulesAndEngineCandidates(t *testing.T) {
	input := simulationFixture()
	input.Config.SchemaVersion = 3
	yes := true
	input.Config.Policies[0].Action = "proxy"
	input.Config.Policies[0].SkipUnavailable = &yes
	input.Rules = []string{"DOMAIN-KEYWORD,private,managed", "MATCH,REJECT"}
	input.Flows = []LocalPolicySimulationFlow{{Host: "private.example", Network: "tcp"}, {Host: "public.example", Network: "udp"}}
	active := activeLocalPolicy.Load()
	result, err := simulateLocalPolicies(input)
	if err != nil {
		t.Fatal(err)
	}
	if len(result.FlowResults) != 2 || result.FlowResults[0].Status != "matched" || result.FlowResults[0].PolicyID != "p" || result.FlowResults[0].SelectedNodeID != "a1" || result.FlowResults[1].Target != "REJECT" {
		t.Fatalf("%+v", result.FlowResults)
	}
	if activeLocalPolicy.Load() != active {
		t.Fatal("simulation replaced production engine")
	}
	for _, id := range []string{"a1", "b2"} {
		no := false
		input.Health[id] = &no
	}
	result, err = simulateLocalPolicies(input)
	if err != nil {
		t.Fatal(err)
	}
	flow := result.FlowResults[0]
	if flow.Target != "REJECT" || flow.Trace[0].Outcome != "skipped" || flow.Trace[0].Reason != "no_eligible_candidates" {
		t.Fatalf("unavailable managed rule did not pass: %+v", flow)
	}
}

func TestLocalFlowSimulationLogicalProcessAndNetworkUseNativeMatcher(t *testing.T) {
	input := simulationFixture()
	input.Rules = []string{"AND,((DOMAIN-SUFFIX,example.com),(PROCESS-PATH-REGEX,^/Applications/Fixture\\.app/Contents/.*$),(NETWORK,udp)),managed", "MATCH,DIRECT"}
	input.Flows = []LocalPolicySimulationFlow{{Host: "api.example.com", ProcessPath: "/Applications/Fixture.app/Contents/MacOS/Fixture", Network: "udp"}, {Host: "api.example.com", ProcessPath: "/Applications/Other.app/Contents/MacOS/Other", Network: "udp"}}
	result, err := simulateLocalPolicies(input)
	if err != nil {
		t.Fatal(err)
	}
	if result.FlowResults[0].Target != "managed" || result.FlowResults[0].SelectedNodeID != "a1" || result.FlowResults[1].Target != "DIRECT" {
		t.Fatalf("%+v", result.FlowResults)
	}
}

func TestLocalFlowSimulationMissingFactsNeverBecomeNegativeGeoMatches(t *testing.T) {
	for _, rule := range []string{"NOT,((GEOIP,CN)),managed", "geoip , CN , managed", "AND,((DOMAIN,example.com),(PROCESS-NAME,Fixture)),managed"} {
		t.Run(rule, func(t *testing.T) {
			input := simulationFixture()
			input.Rules = []string{rule, "MATCH,REJECT"}
			input.Flows = []LocalPolicySimulationFlow{{Host: "example.com"}}
			result, err := simulateLocalPolicies(input)
			if err != nil {
				t.Fatal(err)
			}
			flow := result.FlowResults[0]
			if flow.Status != "unknown" || flow.Trace[0].Outcome != "unknown" || len(flow.Needs) == 0 || flow.Target != "REJECT" {
				t.Fatalf("missing facts became definitive: %+v", flow)
			}
		})
	}
	input := simulationFixture()
	input.Rules = []string{"GEOIP,CN,managed", "MATCH,DIRECT"}
	input.Flows = []LocalPolicySimulationFlow{{DestinationIP: "203.0.113.1", Network: "tcp"}}
	result, err := simulateLocalPolicies(input)
	if err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(result.FlowResults[0].Needs, []string{"geoData"}) {
		t.Fatal(result.FlowResults)
	}
}

func TestLocalFlowSimulationBudgetAdmissionAndTraceBounds(t *testing.T) {
	input := simulationFixture()
	input.Config.SchemaVersion = 3
	yes := true
	input.Config.Policies[0].Action = "proxy"
	input.Config.Policies[0].SkipUnavailable = &yes
	input.Config.Budgets = []LocalPolicyBudget{{SourceID: "a", LimitBytes: 100, ResetDay: 1, TimeZone: "UTC"}}
	input.LocalUsage = map[string]int64{"a": 100}
	for i := 0; i < 25; i++ {
		input.Rules = append(input.Rules, fmt.Sprintf("DOMAIN,unused-%d.example,DIRECT", i))
	}
	input.Rules = append(input.Rules, "MATCH,managed")
	input.Flows = []LocalPolicySimulationFlow{{Host: "selected.example", Network: "tcp"}}
	result, err := simulateLocalPolicies(input)
	if err != nil {
		t.Fatal(err)
	}
	flow := result.FlowResults[0]
	if flow.Status != "matched" || flow.SelectedNodeID != "b2" || len(flow.Trace) != 16 || !flow.TraceTruncated || flow.Target != "managed" {
		t.Fatalf("%+v", flow)
	}
}

func TestLocalFlowSimulationTCPUDPAllocateWithTheSameBalancedEngine(t *testing.T) {
	input := simulationFixture()
	input.Config = v3Fixture(t).config
	input.Config.NodeSets[0].SelectionMode = "loadBalance"
	input.Config.NodeSets[0].BalanceStrategy = "roundRobin"
	input.Rules = []string{"MATCH,managed"}
	input.Flows = []LocalPolicySimulationFlow{{Network: "tcp"}, {Network: "udp"}, {Network: "tcp"}}
	result, err := simulateLocalPolicies(input)
	if err != nil {
		t.Fatal(err)
	}
	for index, want := range []string{"a1", "b2", "c3"} {
		if flow := result.FlowResults[index]; flow.SelectedNodeID != want || flow.Status != "matched" {
			t.Fatalf("flow %d: %+v", index, flow)
		}
	}
}

func TestLocalFlowSimulationRejectsUnboundedOrUnsafeInputs(t *testing.T) {
	for _, mutate := range []func(*LocalPolicySimulationInput){
		func(i *LocalPolicySimulationInput) { i.Flows = make([]LocalPolicySimulationFlow, 9) },
		func(i *LocalPolicySimulationInput) { i.Rules = make([]string, 2049) },
		func(i *LocalPolicySimulationInput) { i.Rules = []string{strings.Repeat("x", 16385)} },
		func(i *LocalPolicySimulationInput) { i.Flows[0].DestinationIP = "invalid" },
		func(i *LocalPolicySimulationInput) { i.Flows[0].Network = "quic" },
	} {
		input := simulationFixture()
		input.Rules = []string{"MATCH,DIRECT"}
		input.Flows = []LocalPolicySimulationFlow{{Host: "example.com"}}
		mutate(&input)
		if _, err := simulateLocalPolicies(input); err == nil {
			t.Fatal("accepted invalid flow input")
		}
	}
	input := simulationFixture()
	input.Rules = []string{"PROCESS-PATH-REGEX,(a+)+$,managed", "MATCH,DIRECT"}
	input.Flows = []LocalPolicySimulationFlow{{ProcessPath: strings.Repeat("a", 3000) + "!"}}
	result, err := simulateLocalPolicies(input)
	if err != nil {
		t.Fatal(err)
	}
	if !localContains(result.FlowResults[0].Needs, "bounded_regex_evaluation") || result.FlowResults[0].Status != "unknown" {
		t.Fatal(result.FlowResults)
	}
}
