package main

import (
	"context"
	C "github.com/metacubex/mihomo/constant"
	"testing"
	"time"
)

func manualSetFixture(t *testing.T) (*localPolicyEngine, *time.Time) {
	e, _, _, now := localFixture(t)
	automatic := false
	probe := e.config.Policies[0].Probe
	probe.Automatic = &automatic
	e.config.NodeSets = []LocalNodeSet{{ID: "manual", SourceIDs: []string{"a", "b"}, Strategy: "stable", Probe: probe, ImprovementPercent: 20}}
	e.config.Policies[0].Choices = []LocalPolicyChoice{{Type: "nodeSet", ID: "manual"}}
	e.config.Policies[0].CandidateNodeIDs = nil
	e.policies["p"].definition = e.config.Policies[0]
	e.prepareNodeSets(&e.config)
	return e, now
}

func TestManualNodeCheckWithAutomaticDisabled(t *testing.T) {
	e, now := manualSetFixture(t)
	job, err := e.checkNodes(LocalPolicyCheckInput{Revision: 3, NodeSetID: "manual"})
	if err != nil || job.Status != "pending" || job.Total != 2 {
		t.Fatalf("%+v %v", job, err)
	}
	duplicate, err := e.checkNodes(LocalPolicyCheckInput{Revision: 3, NodeSetID: "manual"})
	if err != nil || duplicate.ID == job.ID {
		t.Fatal("callers must have independent cancellation identities")
	}
	*now = now.Add(2 * time.Millisecond)
	r := e.sets["manual"]
	e.probe = func(context.Context, C.Proxy, LocalPolicyProbe) error { return nil }
	for _, id := range []string{"a1", "b2"} {
		e.wg.Add(1)
		e.workers++
		e.runProbe(r, id, e.proxies[id])
	}
	completed, err := e.checkNodes(LocalPolicyCheckInput{Revision: 3, OperationID: job.ID})
	if err != nil || completed.Status != "completed" || completed.Completed != 2 {
		t.Fatalf("%+v %v", completed, err)
	}
	other, err := e.checkNodes(LocalPolicyCheckInput{Revision: 3, OperationID: duplicate.ID})
	if err != nil || other.Status != "completed" || other.Completed != 2 {
		t.Fatalf("other waiter %+v %v", other, err)
	}
}

func TestManualNodeCheckCannotProbeRestrictedSourcesAndCancelIsScoped(t *testing.T) {
	e, _ := manualSetFixture(t)
	zero := int64(0)
	for _, id := range []string{"a", "b"} {
		s := e.sources[id]
		s.RemainingBytes = &zero
		e.sources[id] = s
	}
	job, err := e.checkNodes(LocalPolicyCheckInput{Revision: 3, NodeSetID: "manual"})
	if err != nil {
		t.Fatal(err)
	}
	completed, err := e.checkNodes(LocalPolicyCheckInput{Revision: 3, OperationID: job.ID})
	if err != nil || completed.Status != "completed" || completed.Completed != completed.Total {
		t.Fatalf("%+v %v", completed, err)
	}
	if _, err = e.checkNodes(LocalPolicyCheckInput{Revision: 2, OperationID: job.ID}); err == nil {
		t.Fatal("stale revision accepted")
	}
	if _, err = e.checkNodes(LocalPolicyCheckInput{Revision: 3, OperationID: "unrelated", Cancel: true}); err == nil {
		t.Fatal("unknown cancellation accepted")
	}
	for _, id := range []string{"a", "b"} {
		e.sources[id] = LocalPolicySource{ID: id}
	}
	next, err := e.checkNodes(LocalPolicyCheckInput{Revision: 3, NodeSetID: "manual"})
	if err != nil {
		t.Fatal(err)
	}
	cancelled, err := e.checkNodes(LocalPolicyCheckInput{Revision: 3, OperationID: next.ID, Cancel: true})
	if err != nil || cancelled.Status != "cancelled" {
		t.Fatalf("%+v %v", cancelled, err)
	}
}
