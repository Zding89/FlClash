package main

import (
	"context"
	"errors"
	"fmt"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/metacubex/mihomo/adapter"
	"github.com/metacubex/mihomo/adapter/outbound"
	C "github.com/metacubex/mihomo/constant"
)

func TestPolicyClosureIndependentRuleAdmissionAndStableState(t *testing.T) {
	e, _, _, now := localFixture(t)
	regressionPrepareSet(t, e)
	p := e.policies["p"]
	p.definition.Guard.MinRemainingBytes = 1000
	observed, low, high := now.UnixMilli(), int64(500), int64(2000)
	e.sources["a"] = LocalPolicySource{ID: "a", RemainingBytes: &low, ObservedAt: &observed}
	e.sources["b"] = LocalPolicySource{ID: "b", RemainingBytes: &high, ObservedAt: &observed}
	q := &localPolicyRuntime{definition: p.definition, health: map[string]*localNodeHealth{}}
	q.definition.ID = "q"
	q.definition.Guard.MinRemainingBytes = 100
	e.policies["q"] = q
	expectLocalNode(t, e, "b2")
	_, id, err := e.selectProxy("q")
	if err != nil || id != "a1" {
		t.Fatalf("permissive rule got %s: %v", id, err)
	}
	if !e.sets["shared"].health["a1"].healthy {
		t.Fatal("strict admission polluted shared health")
	}
	e.sets["shared"].health["b2"].healthy = false
	low = 1500
	expectLocalNode(t, e, "a1")
	if q.choiceSelections[0] == p.choiceSelections[0] {
		t.Fatal("rule selections share state")
	}
}

func regressionRecovery(t *testing.T) (*localPolicyEngine, *localPolicyRuntime, *time.Time) {
	t.Helper()
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
	return e, set, now
}

func TestPolicyClosureRecoveryBoundaryAndSecondFailure(t *testing.T) {
	e, set, now := regressionRecovery(t)
	*now = now.Add(299 * time.Second)
	expectLocalNode(t, e, "b2")
	*now = now.Add(time.Second)
	expectLocalNode(t, e, "a1")
	e.applyProbeLocked(set, "a1", errors.New("again"), *now)
	expectLocalNode(t, e, "b2")
	*now = now.Add(61 * time.Second)
	e.applyProbeLocked(set, "a1", nil, *now)
	expectLocalNode(t, e, "b2")
	*now = now.Add(300 * time.Second)
	expectLocalNode(t, e, "a1")
}

func TestPolicyClosureInvalidCurrentBypassesRecoveryHold(t *testing.T) {
	e, _, _ := regressionRecovery(t)
	e.policies["p"].health["b2"].healthy = false
	expectLocalNode(t, e, "a1")
}

func TestPolicyClosureOverrideEndsInNormalOrder(t *testing.T) {
	for _, automatic := range []bool{false, true} {
		for _, cancelled := range []bool{false, true} {
			for _, primaryUnavailable := range []bool{false, true} {
				t.Run(fmt.Sprintf("auto=%v/cancel=%v/unavailable=%v", automatic, cancelled, primaryUnavailable), func(t *testing.T) {
					e, _, _, now := localFixture(t)
					healthyLocalNodes(e)
					r := e.policies["p"]
					r.definition.AutoRecover = automatic
					r.definition.Choices = []LocalPolicyChoice{{Type: "node", ID: "a1"}, {Type: "node", ID: "b2"}}
					e.config.Overrides = []LocalPolicyOverride{{PolicyID: "p", NodeID: "b2", ExpiresAt: now.Add(time.Minute).UnixMilli()}}
					expectLocalNode(t, e, "b2")
					if primaryUnavailable {
						r.health["a1"].healthy = false
					}
					if cancelled {
						e.config.Overrides = nil
					} else {
						*now = now.Add(time.Minute)
					}
					want := "a1"
					if primaryUnavailable {
						want = "b2"
					}
					expectLocalNode(t, e, want)
					if r.reason == "manual_override" {
						t.Fatal("expired override remains active")
					}
				})
			}
		}
	}
}

func TestPolicyClosureManualWaitersShareMeasurements(t *testing.T) {
	e, _, _, now := localFixture(t)
	regressionPrepareSet(t, e)
	set := e.sets["shared"]
	automatic := false
	set.definition.Probe.Automatic = &automatic
	for _, h := range set.health {
		h.nextProbe = now.Add(time.Hour)
	}
	var calls atomic.Int32
	e.probe = func(context.Context, C.Proxy, LocalPolicyProbe) error { calls.Add(1); return nil }
	one, err := e.checkNodes(LocalPolicyCheckInput{Revision: e.config.Revision, NodeSetID: "shared"})
	if err != nil {
		t.Fatal(err)
	}
	two, err := e.checkNodes(LocalPolicyCheckInput{Revision: e.config.Revision, NodeSetID: "shared"})
	if err != nil {
		t.Fatal(err)
	}
	if one.ID == two.ID {
		t.Fatal("callers share cancellation identity")
	}
	if _, err = e.checkNodes(LocalPolicyCheckInput{Revision: e.config.Revision, OperationID: one.ID, Cancel: true}); err != nil {
		t.Fatal(err)
	}
	e.tick()
	e.wg.Wait()
	other, err := e.checkNodes(LocalPolicyCheckInput{Revision: e.config.Revision, OperationID: two.ID})
	if err != nil {
		t.Fatal(err)
	}
	if other.Status != "completed" || other.Completed != 2 || calls.Load() != 2 {
		t.Fatalf("waiter=%+v calls=%d", other, calls.Load())
	}
	cancelled, _ := e.checkNodes(LocalPolicyCheckInput{Revision: e.config.Revision, OperationID: one.ID})
	if cancelled.Status != "cancelled" {
		t.Fatal("cancelled caller changed status")
	}
}

func TestPolicyClosureLastManualCancellationPreservesBackground(t *testing.T) {
	for _, automatic := range []bool{false, true} {
		t.Run(fmt.Sprint(automatic), func(t *testing.T) {
			e, _, _, _ := localFixture(t)
			regressionPrepareSet(t, e)
			e.sets["shared"].definition.Probe.Automatic = &automatic
			var calls atomic.Int32
			e.probe = func(context.Context, C.Proxy, LocalPolicyProbe) error { calls.Add(1); return nil }
			job, err := e.checkNodes(LocalPolicyCheckInput{Revision: e.config.Revision, NodeSetID: "shared"})
			if err != nil {
				t.Fatal(err)
			}
			_, err = e.checkNodes(LocalPolicyCheckInput{Revision: e.config.Revision, OperationID: job.ID, Cancel: true})
			if err != nil {
				t.Fatal(err)
			}
			e.tick()
			e.wg.Wait()
			want := int32(0)
			if automatic {
				want = 2
			}
			if calls.Load() != want {
				t.Fatalf("got %d calls want %d", calls.Load(), want)
			}
		})
	}
}

func TestPolicyClosurePriorityAndOrdinaryFairnessBounded(t *testing.T) {
	e, _, _, now := localFixture(t)
	regressionPrepareSet(t, e)
	set := e.sets["shared"]
	set.definition.CandidateNodeIDs = nil
	set.health = map[string]*localNodeHealth{}
	for i := 0; i < 32; i++ {
		id := fmt.Sprintf("n%02d", i)
		set.definition.CandidateNodeIDs = append(set.definition.CandidateNodeIDs, id)
		set.health[id] = &localNodeHealth{healthy: true, healthySince: now.Add(-time.Hour), lastProbe: now.Add(-time.Minute)}
		e.nodes[id] = LocalPolicyNode{ID: id, SourceID: "a", ProxyName: id}
		e.proxies[id] = adapter.NewProxy(outbound.NewBase(outbound.BaseOption{Name: id, Type: C.Shadowsocks}))
	}
	e.policies = map[string]*localPolicyRuntime{}
	e.config.Policies = nil
	for i := 0; i < 16; i++ {
		id := fmt.Sprintf("n%02d", i)
		pid := fmt.Sprintf("p%d", i)
		def := LocalPolicyDefinition{ID: pid, Enabled: true, Choices: []LocalPolicyChoice{{Type: "nodeSet", ID: "shared"}}, Guard: LocalPolicyGuard{UnknownBehavior: "allow"}, AutoRecover: true, Fallback: "reject"}
		r := &localPolicyRuntime{definition: def, health: map[string]*localNodeHealth{}, selected: id, choiceSelections: map[int]*localPolicyRuntime{0: {setID: "shared", selected: id}}}
		e.policies[pid] = r
		e.config.Policies = append(e.config.Policies, def)
	}
	set.selected = "n00"
	e.probeCursor = 9
	var active, maxActive atomic.Int32
	var mu sync.Mutex
	seen := map[string]bool{}
	e.probe = func(_ context.Context, p C.Proxy, _ LocalPolicyProbe) error {
		n := active.Add(1)
		for {
			old := maxActive.Load()
			if n <= old || maxActive.CompareAndSwap(old, n) {
				break
			}
		}
		mu.Lock()
		seen[p.Name()] = true
		mu.Unlock()
		time.Sleep(time.Millisecond)
		active.Add(-1)
		return nil
	}
	for round := 0; round < 20; round++ {
		e.mu.Lock()
		for i := 0; i < 16; i++ {
			set.health[fmt.Sprintf("n%02d", i)].nextProbe = time.Time{}
		}
		e.mu.Unlock()
		e.tick()
		e.wg.Wait()
		if round == 0 {
			mu.Lock()
			first := seen["n00"]
			mu.Unlock()
			if !first {
				t.Fatal("active node lost priority")
			}
		}
	}
	mu.Lock()
	defer mu.Unlock()
	if len(seen) != 32 {
		t.Fatalf("members starved: checked=%d want 32", len(seen))
	}
	if maxActive.Load() > 8 {
		t.Fatalf("concurrency=%d", maxActive.Load())
	}
}

func TestPolicyClosureManualWaitersJoinInFlightSameClockSample(t *testing.T) {
	e, _, _, _ := localFixture(t)
	regressionPrepareSet(t, e)
	set := e.sets["shared"]
	automatic := false
	set.definition.Probe.Automatic = &automatic
	started := make(chan struct{}, 2)
	release := make(chan struct{})
	var calls atomic.Int32
	e.probe = func(ctx context.Context, _ C.Proxy, _ LocalPolicyProbe) error {
		calls.Add(1)
		started <- struct{}{}
		select {
		case <-release:
			return nil
		case <-ctx.Done():
			return ctx.Err()
		}
	}
	first, err := e.checkNodes(LocalPolicyCheckInput{Revision: 3, NodeSetID: "shared"})
	if err != nil {
		t.Fatal(err)
	}
	e.tick()
	for i := 0; i < 2; i++ {
		select {
		case <-started:
		case <-time.After(time.Second):
			t.Fatal("probe not started")
		}
	}
	second, err := e.checkNodes(LocalPolicyCheckInput{Revision: 3, NodeSetID: "shared"})
	if err != nil {
		t.Fatal(err)
	}
	if _, err = e.checkNodes(LocalPolicyCheckInput{Revision: 3, OperationID: first.ID, Cancel: true}); err != nil {
		t.Fatal(err)
	}
	e.tick()
	close(release)
	e.wg.Wait()
	result, err := e.checkNodes(LocalPolicyCheckInput{Revision: 3, OperationID: second.ID})
	if err != nil || result.Status != "completed" || result.Completed != 2 || calls.Load() != 2 {
		t.Fatalf("result=%+v calls=%d err=%v", result, calls.Load(), err)
	}
}

func TestPolicyClosureManualWaiterCapacityAndRetention(t *testing.T) {
	e, _, _, _ := localFixture(t)
	regressionPrepareSet(t, e)
	jobs := []localPolicyCheck{}
	for i := 0; i < 16; i++ {
		job, err := e.checkNodes(LocalPolicyCheckInput{Revision: 3, NodeSetID: "shared"})
		if err != nil {
			t.Fatal(err)
		}
		jobs = append(jobs, job)
	}
	if _, err := e.checkNodes(LocalPolicyCheckInput{Revision: 3, NodeSetID: "shared"}); err == nil {
		t.Fatal("manual waiter limit exceeded")
	}
	if _, err := e.checkNodes(LocalPolicyCheckInput{Revision: 3, OperationID: jobs[0].ID, Cancel: true}); err != nil {
		t.Fatal(err)
	}
	if _, err := e.checkNodes(LocalPolicyCheckInput{Revision: 3, NodeSetID: "shared"}); err != nil {
		t.Fatal(err)
	}
	zero := int64(0)
	for _, id := range []string{"a", "b"} {
		e.sources[id] = LocalPolicySource{ID: id, RemainingBytes: &zero}
	}
	for i := 0; i < 80; i++ {
		job, err := e.checkNodes(LocalPolicyCheckInput{Revision: 3, NodeSetID: "shared"})
		if err != nil {
			t.Fatal(err)
		}
		result, err := e.checkNodes(LocalPolicyCheckInput{Revision: 3, OperationID: job.ID})
		if err != nil || result.Status != "completed" {
			t.Fatalf("%+v %v", result, err)
		}
		if len(e.checks) > 64 {
			t.Fatal("retained result limit exceeded")
		}
	}
}

func TestPolicyClosureSimulationUsesPerRuleSetAdmission(t *testing.T) {
	input := simulationFixture()
	policy := input.Config.Policies[0]
	policy.CandidateNodeIDs = nil
	policy.Choices = []LocalPolicyChoice{{Type: "nodeSet", ID: "shared"}}
	policy.Guard.MinRemainingBytes = 1000
	input.Config.Policies = []LocalPolicyDefinition{policy}
	input.Config.NodeSets = []LocalNodeSet{{ID: "shared", SourceIDs: []string{"a", "b"}, UnknownMultiplier: "exclude", Strategy: "stable", Probe: policy.Probe, ImprovementPercent: 20}}
	low, high := int64(500), int64(2000)
	input.Config.Sources[0].RemainingBytes = &low
	input.Config.Sources[0].ObservedAt = &input.Now
	input.Config.Sources[1].RemainingBytes = &high
	input.Config.Sources[1].ObservedAt = &input.Now
	result, err := simulateLocalPolicies(input)
	if err != nil {
		t.Fatal(err)
	}
	if result.Snapshot.Policies[0].SelectedNodeID != "b2" {
		t.Fatalf("%+v", result.Snapshot.Policies[0])
	}
}

func TestPolicyClosurePrioritySurvivesSharedHealthCandidateDeduplication(t *testing.T) {
	e, _, _, now := localFixture(t)
	regressionPrepareSet(t, e)
	first := e.sets["shared"]
	first.definition.CandidateNodeIDs = nil
	first.health = map[string]*localNodeHealth{}
	for i := 0; i < 20; i++ {
		id := fmt.Sprintf("n%02d", i)
		first.definition.CandidateNodeIDs = append(first.definition.CandidateNodeIDs, id)
		first.health[id] = &localNodeHealth{healthy: true, lastProbe: *now}
		e.nodes[id] = LocalPolicyNode{ID: id, SourceID: "a", ProxyName: id}
		e.proxies[id] = adapter.NewProxy(outbound.NewBase(outbound.BaseOption{Name: id, Type: C.Shadowsocks}))
	}
	second := *first
	second.setID = "second"
	second.selected = "n00"
	first.selected = "n01"
	e.sets["second"] = &second
	definition := e.config.NodeSets[0]
	definition.ID = "second"
	e.config.NodeSets = append(e.config.NodeSets, definition)
	e.setDefinitions["second"] = definition
	e.policies = map[string]*localPolicyRuntime{}
	e.config.Policies = nil
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
			t.Fatal("probe not started")
		}
	}
	if !seen["n00"] || !seen["n01"] {
		t.Fatalf("shared current nodes lost priority: %v", seen)
	}
	if e.workers > 8 {
		t.Fatal("probe concurrency exceeded")
	}
}
