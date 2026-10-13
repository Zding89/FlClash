package main

import (
	"context"
	"errors"
	"fmt"
	"github.com/metacubex/mihomo/adapter"
	"github.com/metacubex/mihomo/adapter/outbound"
	C "github.com/metacubex/mihomo/constant"
	"testing"
	"time"
)

func regressionPrepareSet(t *testing.T, e *localPolicyEngine) {
	t.Helper()
	e.config.NodeSets = []LocalNodeSet{{ID: "shared", SourceIDs: []string{"a", "b"}, UnknownMultiplier: "exclude", Strategy: "stable", Probe: e.config.Policies[0].Probe, ImprovementPercent: 20}}
	e.config.Policies[0].CandidateNodeIDs = nil
	e.config.Policies[0].Choices = []LocalPolicyChoice{{Type: "nodeSet", ID: "shared"}}
	if err := e.prepareNodeSets(&e.config); err != nil {
		t.Fatal(err)
	}
	e.policies["p"].definition = e.config.Policies[0]
	for _, h := range e.sets["shared"].health {
		h.healthy = true
		h.lastProbe = e.now()
		h.healthySince = e.now().Add(-time.Hour)
	}
}

func TestPolicyRegressionNodeSetFiltersBeforePerRuleSelection(t *testing.T) {
	e, _, _, now := localFixture(t)
	regressionPrepareSet(t, e)
	r := e.policies["p"]
	r.definition.Guard.MinRemainingBytes = 1000
	r.definition.Guard.UnknownBehavior = "exclude"
	observed, low, enough := now.UnixMilli(), int64(500), int64(2000)
	e.sources["a"] = LocalPolicySource{ID: "a", RemainingBytes: &low, ObservedAt: &observed}
	e.sources["b"] = LocalPolicySource{ID: "b", RemainingBytes: &enough, ObservedAt: &observed}
	expectLocalNode(t, e, "b2")
}

func TestPolicyRegressionChoicesHonorPrimaryRecoveryObservation(t *testing.T) {
	e, _, _, now := localFixture(t)
	healthyLocalNodes(e)
	regressionPrepareSet(t, e)
	r := e.policies["p"]
	r.definition.Choices = []LocalPolicyChoice{{Type: "nodeSet", ID: "shared"}, {Type: "node", ID: "b2"}}
	set := e.sets["shared"]
	set.definition.CandidateNodeIDs = []string{"a1"}
	delete(set.health, "b2")
	set.definition.Probe.FailureThreshold = 1
	set.definition.Probe.SuccessThreshold = 1
	set.definition.RecoverySeconds = 0
	expectLocalNode(t, e, "a1")
	e.applyProbeLocked(set, "a1", errors.New("offline"), *now)
	expectLocalNode(t, e, "b2")
	*now = now.Add(61 * time.Second)
	e.applyProbeLocked(set, "a1", nil, *now)
	expectLocalNode(t, e, "b2")
}

func TestPolicyRegressionExpiredOverrideResumesNormalOrder(t *testing.T) {
	e, _, _, now := localFixture(t)
	healthyLocalNodes(e)
	r := e.policies["p"]
	r.definition.Choices = []LocalPolicyChoice{{Type: "node", ID: "a1"}, {Type: "node", ID: "b2"}}
	r.definition.AutoRecover = false
	e.config.Overrides = []LocalPolicyOverride{{PolicyID: "p", NodeID: "b2", ExpiresAt: now.Add(time.Minute).UnixMilli()}}
	expectLocalNode(t, e, "b2")
	*now = now.Add(time.Minute)
	expectLocalNode(t, e, "a1")
}

func TestPolicyRegressionManualCancellationKeepsOtherWaiter(t *testing.T) {
	e, _, _, _ := localFixture(t)
	regressionPrepareSet(t, e)
	one, err := e.checkNodes(LocalPolicyCheckInput{Revision: e.config.Revision, NodeSetID: "shared"})
	if err != nil {
		t.Fatal(err)
	}
	two, err := e.checkNodes(LocalPolicyCheckInput{Revision: e.config.Revision, NodeSetID: "shared"})
	if err != nil {
		t.Fatal(err)
	}
	_, err = e.checkNodes(LocalPolicyCheckInput{Revision: e.config.Revision, OperationID: one.ID, Cancel: true})
	if err != nil {
		t.Fatal(err)
	}
	other, err := e.checkNodes(LocalPolicyCheckInput{Revision: e.config.Revision, OperationID: two.ID})
	if err != nil {
		t.Fatal(err)
	}
	if other.Status != "pending" {
		t.Fatalf("second caller lost its pending check: status=%s", other.Status)
	}
}

func TestPolicyRegressionSelectedNodeHasProbePriority(t *testing.T) {
	e, _, _, now := localFixture(t)
	regressionPrepareSet(t, e)
	r := e.sets["shared"]
	r.definition.CandidateNodeIDs = nil
	r.health = map[string]*localNodeHealth{}
	for index := 0; index < 20; index++ {
		id := fmt.Sprintf("n%02d", index)
		r.definition.CandidateNodeIDs = append(r.definition.CandidateNodeIDs, id)
		r.health[id] = &localNodeHealth{healthy: true, healthySince: now.Add(-time.Hour), lastProbe: now.Add(-time.Minute)}
		e.nodes[id] = LocalPolicyNode{ID: id, SourceID: "a", ProxyName: id}
		e.proxies[id] = adapter.NewProxy(outbound.NewBase(outbound.BaseOption{Name: id, Type: C.Shadowsocks}))
	}
	r.selected = "n00"
	r.reason = "strict_order"
	e.probeCursor = 9
	started := make(chan string, 20)
	e.probe = func(ctx context.Context, proxy C.Proxy, _ LocalPolicyProbe) error {
		started <- proxy.Name()
		<-ctx.Done()
		return ctx.Err()
	}
	e.tick()
	seen := map[string]bool{}
	for i := 0; i < 8; i++ {
		select {
		case id := <-started:
			seen[id] = true
		case <-time.After(time.Second):
			t.Fatal("probe was not started")
		}
	}
	if !seen["n00"] {
		t.Fatalf("selected node was skipped by round-robin cursor: %v", seen)
	}
}
