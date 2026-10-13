package main

import "testing"

func TestSnapshotCapacityCountsActualUniqueNetworkTasks(t *testing.T) {
	e := largeDetailsFixture(t)
	e.sets["all"].definition.Probe.IntervalSeconds = 60
	e.sets["all"].definition.Probe.RetrySeconds = 180
	duplicate := *e.sets["all"]
	duplicate.setID = "duplicate"
	duplicate.definition.ID = "duplicate"
	e.sets["duplicate"] = &duplicate
	set := e.config.NodeSets[0]
	set.ID = "duplicate"
	e.config.NodeSets = append(e.config.NodeSets, set)
	e.config.Policies[0].Choices = append(e.config.Policies[0].Choices, LocalPolicyChoice{Type: "nodeSet", ID: "duplicate"})
	e.policies[e.config.Policies[0].ID].definition = e.config.Policies[0]
	snapshot := e.snapshot()
	if snapshot.CheckTaskCount != 5000 || snapshot.MaxCheckTimeoutSeconds != 5 || snapshot.RecommendedCheckCycleSeconds != 3960 {
		t.Fatalf("tasks=%d timeout=%d recommendation=%d", snapshot.CheckTaskCount, snapshot.MaxCheckTimeoutSeconds, snapshot.RecommendedCheckCycleSeconds)
	}
	if snapshot.RecommendedCheckCycleSeconds < 3930 || snapshot.RecommendedCheckCycleSeconds%60 != 0 {
		t.Fatal("cycle recommendation did not cover capacity estimate")
	}
}

func TestSnapshotCapacitySeparatesNetworkParameters(t *testing.T) {
	e, _, _, _ := localFixture(t)
	first := e.policies["p"]
	second := &localPolicyRuntime{definition: first.definition, health: first.health}
	second.definition.ID = "second"
	second.definition.Probe.TimeoutSeconds = 6
	second.definition.Probe.RetrySeconds = 180
	e.config.Policies = append(e.config.Policies, second.definition)
	e.policies["second"] = second
	snapshot := e.snapshot()
	if snapshot.CheckTaskCount != 4 || snapshot.MaxCheckTimeoutSeconds != 6 || snapshot.RecommendedCheckCycleSeconds != 240 {
		t.Fatalf("tasks=%d timeout=%d recommendation=%d", snapshot.CheckTaskCount, snapshot.MaxCheckTimeoutSeconds, snapshot.RecommendedCheckCycleSeconds)
	}
}
