package main

import (
	"context"
	"encoding/json"
	"errors"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/metacubex/mihomo/config"
	C "github.com/metacubex/mihomo/constant"
)

const localReloadProxies = `proxies:
  - {name: A1, type: ss, server: first.example, port: 443, password: initial}
  - {name: B2, type: ss, server: second.example, port: 443, password: initial}
  - {name: C3, type: ss, server: third.example, port: 443, password: initial}
rules: [MATCH,managed]
`

func reloadManualFixture(t *testing.T) (*localPolicyEngine, *config.Config, *time.Time) {
	t.Helper()
	e, cfg, _, now := localFixture(t)
	automatic := false
	probe := e.config.Policies[0].Probe
	probe.Automatic = &automatic
	probe.SuccessThreshold = 1
	probe.ValiditySeconds = 120
	e.config.NodeSets = []LocalNodeSet{{ID: "manual", SourceIDs: []string{"a", "b"}, Strategy: "stable", Probe: probe, ImprovementPercent: 20}}
	e.config.Policies[0].Choices = []LocalPolicyChoice{{Type: "nodeSet", ID: "manual"}}
	e.config.Policies[0].CandidateNodeIDs = nil
	e.policies["p"].definition = e.config.Policies[0]
	if err := e.prepareNodeSets(&e.config); err != nil {
		t.Fatal(err)
	}
	e.identifyNodes([]byte(localReloadProxies))
	e.probe = func(context.Context, C.Proxy, LocalPolicyProbe) error { return nil }
	job, err := e.checkNodes(LocalPolicyCheckInput{Revision: e.config.Revision, NodeSetID: "manual"})
	if err != nil {
		t.Fatal(err)
	}
	e.tick()
	e.wg.Wait()
	completed, err := e.checkNodes(LocalPolicyCheckInput{Revision: e.config.Revision, OperationID: job.ID})
	if err != nil || completed.Status != "completed" {
		t.Fatalf("manual check %+v: %v", completed, err)
	}
	expectLocalNode(t, e, "a1")
	return e, cfg, now
}

func reloadLocalFixture(t *testing.T, old *localPolicyEngine, cfg *config.Config, mutate func(*LocalPolicyConfig), raw string) *localPolicyEngine {
	t.Helper()
	encoded, err := json.Marshal(old.config)
	if err != nil {
		t.Fatal(err)
	}
	var c LocalPolicyConfig
	if err = json.Unmarshal(encoded, &c); err != nil {
		t.Fatal(err)
	}
	c.Revision++
	if mutate != nil {
		mutate(&c)
	}
	next, err := prepareLocalPolicy(&c, cfg, old.ledger)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(next.stop)
	next.now = old.now
	next.identifyNodes([]byte(raw))
	old.stop()
	next.inheritRuntime(old)
	return next
}

func TestLocalReloadRetainsManualHealthAndAppliesOverrides(t *testing.T) {
	old, cfg, now := reloadManualFixture(t)
	next := reloadLocalFixture(t, old, cfg, func(c *LocalPolicyConfig) { c.Policies[0].Label = "renamed" }, strings.ReplaceAll(localReloadProxies, "MATCH,managed", "DOMAIN,example.com,DIRECT"))
	var probes atomic.Int32
	next.probe = func(context.Context, C.Proxy, LocalPolicyProbe) error { probes.Add(1); return nil }
	expectLocalNode(t, next, "a1")
	next.tick()
	if probes.Load() != 0 || next.sets["manual"].health["a1"].lastProbe != *now {
		t.Fatal("reload required another manual check")
	}
	overridden := reloadLocalFixture(t, next, cfg, func(c *LocalPolicyConfig) {
		c.Overrides = []LocalPolicyOverride{{PolicyID: "p", NodeSetID: "manual", NodeID: "b2", ExpiresAt: now.Add(time.Minute).UnixMilli()}}
	}, localReloadProxies)
	expectLocalNode(t, overridden, "b2")
	if overridden.policies["p"].reason != "manual_override" {
		t.Fatal("new override was not reevaluated")
	}
}

func TestLocalReloadRejectsIncompatibleOrExpiredManualHealth(t *testing.T) {
	cases := []struct {
		name   string
		mutate func(*LocalPolicyConfig)
		raw    string
		elapse time.Duration
	}{
		{name: "method", mutate: func(c *LocalPolicyConfig) { c.NodeSets[0].Probe.Method = "GET" }},
		{name: "url", mutate: func(c *LocalPolicyConfig) { c.NodeSets[0].Probe.URL = "http://other.example" }},
		{name: "status", mutate: func(c *LocalPolicyConfig) { c.NodeSets[0].Probe.ExpectedStatus = "204" }},
		{name: "timeout", mutate: func(c *LocalPolicyConfig) { c.NodeSets[0].Probe.TimeoutSeconds++ }},
		{name: "interval", mutate: func(c *LocalPolicyConfig) { c.NodeSets[0].Probe.IntervalSeconds++ }},
		{name: "retry", mutate: func(c *LocalPolicyConfig) { c.NodeSets[0].Probe.RetrySeconds++ }},
		{name: "validity", mutate: func(c *LocalPolicyConfig) { c.NodeSets[0].Probe.ValiditySeconds++ }},
		{name: "failures", mutate: func(c *LocalPolicyConfig) { c.NodeSets[0].Probe.FailureThreshold++ }},
		{name: "successes", mutate: func(c *LocalPolicyConfig) { c.NodeSets[0].Probe.SuccessThreshold++ }},
		{name: "recovery", mutate: func(c *LocalPolicyConfig) { c.NodeSets[0].RecoverySeconds++ }},
		{name: "automatic", mutate: func(c *LocalPolicyConfig) { automatic := true; c.NodeSets[0].Probe.Automatic = &automatic }},
		{name: "expired", elapse: 120 * time.Second},
		{name: "clock-reversed", elapse: -time.Second},
		{name: "source", mutate: func(c *LocalPolicyConfig) { c.Nodes[0].SourceID = "b" }},
		{name: "node-metadata", mutate: func(c *LocalPolicyConfig) { region := "US"; c.Nodes[0].Region = &region }},
		{name: "credentials", raw: strings.ReplaceAll(localReloadProxies, "password: initial", "password: replacement")},
		{name: "server", raw: strings.ReplaceAll(localReloadProxies, "first.example", "replacement.example")},
		{name: "identity-missing", raw: "proxies: []"},
		{name: "target", mutate: func(c *LocalPolicyConfig) { c.TargetID = "different" }},
		{name: "source-excluded", mutate: func(c *LocalPolicyConfig) { zero := int64(0); c.Sources[0].RemainingBytes = &zero }},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			old, cfg, now := reloadManualFixture(t)
			*now = now.Add(tc.elapse)
			if tc.name == "expired" {
				old.lastTick = *now
			}
			raw := tc.raw
			if raw == "" {
				raw = localReloadProxies
			}
			next := reloadLocalFixture(t, old, cfg, tc.mutate, raw)
			health := next.sets["manual"].health["a1"]
			if health.healthy || !health.lastProbe.IsZero() || next.policies["p"].selected == "a1" {
				t.Fatalf("incompatible result survived: %+v", health)
			}
		})
	}
}

func TestLocalReloadPreservesStableChoiceAndRecoveryTiming(t *testing.T) {
	old, cfg, now := reloadManualFixture(t)
	set := old.sets["manual"]
	set.health["a1"].healthy = false
	expectLocalNode(t, old, "b2")
	set.health["a1"].healthy = true
	set.health["a1"].healthySince = *now
	expectLocalNode(t, old, "b2")
	prior := old.policies["p"]
	switched := prior.switched
	next := reloadLocalFixture(t, old, cfg, nil, localReloadProxies)
	expectLocalNode(t, next, "b2")
	if next.policies["p"].switched != switched || next.policies["p"].choiceSelections[0].selected != "b2" {
		t.Fatal("reload reset stable per-policy selection or cooldown")
	}
	if next.sets["manual"].health["a1"] == set.health["a1"] || next.policies["p"].choiceSelections[0] == prior.choiceSelections[0] {
		t.Fatal("engines share mutable runtime state")
	}
}

func TestLocalReloadRejectsOldInFlightProbeCallback(t *testing.T) {
	old, cfg, _ := reloadManualFixture(t)
	set := old.sets["manual"]
	started, release := make(chan struct{}), make(chan struct{})
	old.probe = func(context.Context, C.Proxy, LocalPolicyProbe) error {
		close(started)
		<-release
		return errors.New("late failure")
	}
	key := localNetworkProbeKey(set, "a1")
	set.health["a1"].pending = true
	old.inFlight[key] = []localProbeCandidate{{runtime: set, nodeID: "a1"}}
	old.workers++
	old.wg.Add(1)
	go old.runSharedProbe(key, old.proxies["a1"], old.epoch)
	<-started
	stopDone := make(chan struct{})
	go func() { old.stop(); close(stopDone) }()
	select {
	case <-old.ctx.Done():
	case <-time.After(time.Second):
		t.Fatal("old engine was not cancelled")
	}
	close(release)
	<-stopDone
	next := reloadLocalFixture(t, old, cfg, nil, localReloadProxies)
	expectLocalNode(t, next, "a1")
	health := next.sets["manual"].health["a1"]
	if health.pending || health.failures != 0 {
		t.Fatal("stopped probe result polluted successor")
	}
	set.health["a1"].healthy = false
	expectLocalNode(t, next, "a1")
}

func TestLocalReloadPreservesOrderedRecoveryWindow(t *testing.T) {
	old, cfg, _, now := localFixture(t)
	old.config.Policies[0].Choices = []LocalPolicyChoice{{Type: "node", ID: "a1"}, {Type: "node", ID: "b2"}}
	old.config.Policies[0].CandidateNodeIDs = nil
	old.config.Policies[0].Probe.ValiditySeconds = 600
	old.policies["p"].definition = old.config.Policies[0]
	old.identifyNodes([]byte(localReloadProxies))
	healthyLocalNodes(old)
	expectLocalNode(t, old, "a1")
	old.policies["p"].health["a1"].healthy = false
	expectLocalNode(t, old, "b2")
	old.policies["p"].health["a1"].healthy = true
	expectLocalNode(t, old, "b2")
	recoverySince := old.policies["p"].recoverySince
	*now = now.Add(30 * time.Second)
	next := reloadLocalFixture(t, old, cfg, nil, localReloadProxies)
	expectLocalNode(t, next, "b2")
	if next.policies["p"].recoverySince != recoverySince {
		t.Fatal("reload restarted ordered recovery window")
	}
	*now = recoverySince.Add(299 * time.Second)
	expectLocalNode(t, next, "b2")
	*now = recoverySince.Add(300 * time.Second)
	expectLocalNode(t, next, "a1")
}

func TestLocalReloadPreservesFailureRecoveryState(t *testing.T) {
	old, cfg, _, now := localFixture(t)
	old.config.Policies[0].Probe.ValiditySeconds = 600
	old.policies["p"].definition = old.config.Policies[0]
	old.identifyNodes([]byte(localReloadProxies))
	healthyLocalNodes(old)
	r := old.policies["p"]
	h := r.health["a1"]
	h.healthy = false
	h.recovering = true
	h.failures = 3
	h.successes = 1
	h.healthySince = *now
	expectLocalNode(t, old, "b2")
	next := reloadLocalFixture(t, old, cfg, nil, localReloadProxies)
	inherited := next.policies["p"].health["a1"]
	if inherited.healthy || !inherited.recovering || inherited.failures != 3 || inherited.successes != 1 || inherited.healthySince != *now {
		t.Fatalf("failure recovery was reset: %+v", inherited)
	}
	*now = now.Add(299 * time.Second)
	next.applyProbeLocked(next.policies["p"], "a1", nil, *now)
	expectLocalNode(t, next, "b2")
	*now = now.Add(time.Second)
	next.applyProbeLocked(next.policies["p"], "a1", nil, *now)
	expectLocalNode(t, next, "a1")
}

func TestLocalReloadDoesNotInheritPreviouslyExcludedSources(t *testing.T) {
	old, cfg, _ := reloadManualFixture(t)
	zero := int64(0)
	source := old.sources["a"]
	source.RemainingBytes = &zero
	old.sources["a"] = source
	next := reloadLocalFixture(t, old, cfg, nil, localReloadProxies)
	if next.sets["manual"].health["a1"].healthy {
		t.Fatal("stale config resurrected an excluded source's health")
	}
	expectLocalNode(t, next, "b2")
}
