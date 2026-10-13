package main

import (
	"context"
	"errors"
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"sync/atomic"
	"testing"
	"time"

	"github.com/metacubex/mihomo/adapter"
	"github.com/metacubex/mihomo/adapter/outbound"
	"github.com/metacubex/mihomo/common/buf"
	"github.com/metacubex/mihomo/config"
	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/tunnel"
	"github.com/metacubex/mihomo/tunnel/statistic"
	"gopkg.in/yaml.v3"
)

type localTestLeaf struct {
	*outbound.Base
	calls   atomic.Int32
	packets atomic.Int32
}

func (l *localTestLeaf) DialContext(ctx context.Context, m *C.Metadata) (C.Conn, error) {
	l.calls.Add(1)
	conn, err := (&net.Dialer{}).DialContext(ctx, "tcp", m.RemoteAddress())
	if err != nil {
		return nil, err
	}
	return outbound.NewConn(conn, l), nil
}
func (l *localTestLeaf) ListenPacketContext(ctx context.Context, m *C.Metadata) (C.PacketConn, error) {
	l.packets.Add(1)
	conn, err := net.ListenPacket("udp", "127.0.0.1:0")
	if err != nil {
		return nil, err
	}
	return outbound.NewPacketConn(conn, l), nil
}
func localFixture(t *testing.T) (*localPolicyEngine, *config.Config, map[string]*localTestLeaf, *time.Time) {
	t.Helper()
	now := time.Date(2026, 10, 13, 12, 0, 0, 0, time.FixedZone("Asia/Shanghai", 28800))
	c := &LocalPolicyConfig{SchemaVersion: 1, Revision: 3, Enabled: true, Sources: []LocalPolicySource{{ID: "a"}, {ID: "b"}, {ID: "c"}}, Nodes: []LocalPolicyNode{{ID: "a1", SourceID: "a", ProxyName: "A1"}, {ID: "b2", SourceID: "b", ProxyName: "B2"}, {ID: "c3", SourceID: "c", ProxyName: "C3"}}, Policies: []LocalPolicyDefinition{{ID: "p", Enabled: true, GroupName: "managed", CandidateNodeIDs: []string{"a1", "b2"}, Probe: LocalPolicyProbe{URL: "http://127.0.0.1", IntervalSeconds: 30, TimeoutSeconds: 5, FailureThreshold: 3, SuccessThreshold: 2}, Guard: LocalPolicyGuard{UnknownBehavior: "exclude"}, AutoRecover: true, Fallback: "reject", RecoverySeconds: 300, CooldownSeconds: 60}}}
	cfg := &config.Config{General: &config.General{Mode: tunnel.Rule}, Proxies: map[string]C.Proxy{}}
	leaves := map[string]*localTestLeaf{}
	for _, n := range c.Nodes {
		leaf := &localTestLeaf{Base: outbound.NewBase(outbound.BaseOption{Name: n.ProxyName, Type: C.Shadowsocks, UDP: true})}
		cfg.Proxies[n.ProxyName] = adapter.NewProxy(leaf)
		leaves[n.ID] = leaf
	}
	cfg.Proxies["managed"] = adapter.NewProxy(outbound.NewBase(outbound.BaseOption{Name: "managed", Type: C.Selector, UDP: true}))
	cfg.Proxies["DIRECT"] = adapter.NewProxy(outbound.NewBase(outbound.BaseOption{Name: "DIRECT", Type: C.Direct, UDP: true}))
	ledger := newLocalBudgetLedger("")
	e, err := prepareLocalPolicy(c, cfg, ledger)
	if err != nil {
		t.Fatal(err)
	}
	e.now = func() time.Time { return now }
	ledger.configure(c.Budgets, now)
	t.Cleanup(func() {
		e.stop()
		closeLocalPolicyConnections()
		localConnections.Lock()
		localConnections.values = map[uint64]localPolicyConnection{}
		localConnections.Unlock()
	})
	return e, cfg, leaves, &now
}
func healthyLocalNodes(e *localPolicyEngine) {
	for _, r := range e.policies {
		for _, h := range r.health {
			h.healthy = true
			h.healthySince = e.now().Add(-time.Hour)
			h.lastProbe = e.now()
			h.nextProbe = e.now().Add(time.Hour)
		}
	}
}
func expectLocalNode(t *testing.T, e *localPolicyEngine, want string) {
	t.Helper()
	_, id, err := e.selectProxy("p")
	if want == "" {
		if err == nil {
			t.Fatal("expected explicit reject")
		}
		return
	}
	if err != nil || id != want {
		t.Fatalf("node=%s err=%v, want %s", id, err, want)
	}
}
func TestLocalPolicyStrictOrderMissingAndHardExclusion(t *testing.T) {
	e, cfg, leaves, now := localFixture(t)
	healthyLocalNodes(e)
	e.install(cfg)
	expectLocalNode(t, e, "a1")
	r := e.policies["p"]
	r.health["a1"].healthy = false
	expectLocalNode(t, e, "b2")
	r.health["a1"].healthy = true
	r.health["a1"].healthySince = *now
	expectLocalNode(t, e, "b2")
	*now = now.Add(301 * time.Second)
	expectLocalNode(t, e, "a1")
	expiry := now.UnixMilli()
	e.sources["a"] = LocalPolicySource{ID: "a", ExpiresAt: &expiry}
	expectLocalNode(t, e, "b2")
	delete(e.proxies, "b2")
	expectLocalNode(t, e, "")
	if leaves["c3"].calls.Load() != 0 {
		t.Fatal("unexpected third node")
	}
	target := cfg.Proxies["managed"].(*adapter.Proxy)
	if _, ok := target.ProxyAdapter.(*localManagedAdapter); !ok {
		t.Fatal("cached proxy graph was not guarded")
	}
}
func TestLocalPolicyGuardBoundariesAndUnknown(t *testing.T) {
	e, _, _, now := localFixture(t)
	p := e.policies["p"].definition
	if reason := e.sourceReasonLocked("a1", p, *now); reason != "" {
		t.Fatal("disabled metadata conditions require unknown metadata", reason)
	}
	p.Guard.ExpiryMarginSeconds = 60
	p.Guard.MinRemainingBytes = 100
	p.Guard.MetadataMaxAgeSeconds = 30
	if reason := e.sourceReasonLocked("a1", p, *now); reason != "metadata_unknown" {
		t.Fatal(reason)
	}
	expire := now.Add(61 * time.Second).UnixMilli()
	remaining := int64(101)
	observed := now.UnixMilli()
	e.sources["a"] = LocalPolicySource{ID: "a", ExpiresAt: &expire, RemainingBytes: &remaining, ObservedAt: &observed}
	if reason := e.sourceReasonLocked("a1", p, *now); reason != "" {
		t.Fatal(reason)
	}
	expire = now.Add(time.Minute).UnixMilli()
	if reason := e.sourceReasonLocked("a1", p, *now); reason != "source_expiring" {
		t.Fatal(reason)
	}
	expire = now.Add(time.Hour).UnixMilli()
	remaining = 100
	if reason := e.sourceReasonLocked("a1", p, *now); reason != "source_remaining" {
		t.Fatal(reason)
	}
	remaining = 101
	observed = now.Add(-31 * time.Second).UnixMilli()
	if reason := e.sourceReasonLocked("a1", p, *now); reason != "metadata_stale" {
		t.Fatal(reason)
	}
	p.Guard.UnknownBehavior = "allow"
	if reason := e.sourceReasonLocked("a1", p, *now); reason != "" {
		t.Fatal(reason)
	}
	expire = now.Add(-time.Second).UnixMilli()
	p.Guard.ExpiryMarginSeconds = 0
	if reason := e.sourceReasonLocked("a1", p, *now); reason != "source_expiring" {
		t.Fatal("known expiry ignored", reason)
	}
}
func TestLocalPolicyFailureThresholdAndRecovery(t *testing.T) {
	e, _, _, now := localFixture(t)
	healthyLocalNodes(e)
	expectLocalNode(t, e, "a1")
	r := e.policies["p"]
	e.probe = func(context.Context, C.Proxy, LocalPolicyProbe) error { return errors.New("offline") }
	run := func(id string) { e.wg.Add(1); e.workers++; e.runProbe(r, id, e.proxies[id]) }
	run("a1")
	run("a1")
	expectLocalNode(t, e, "a1")
	run("a1")
	expectLocalNode(t, e, "b2")
	e.probe = func(context.Context, C.Proxy, LocalPolicyProbe) error { return nil }
	run("a1")
	run("a1")
	expectLocalNode(t, e, "b2")
	*now = now.Add(299 * time.Second)
	run("a1")
	expectLocalNode(t, e, "b2")
	*now = now.Add(time.Second)
	run("a1")
	expectLocalNode(t, e, "a1")
}
func TestLocalPolicyScheduleAndOverrideCannotBypassGuard(t *testing.T) {
	e, _, _, now := localFixture(t)
	healthyLocalNodes(e)
	r := e.policies["p"]
	r.definition.Schedule = &LocalPolicySchedule{TimeZone: "Asia/Shanghai", Windows: []LocalPolicyScheduleWindow{{Weekdays: []int{2}, StartMinute: 0, EndMinute: 720}}}
	expectLocalNode(t, e, "")
	if r.reason != "schedule_inactive" {
		t.Fatal(r.reason)
	}
	r.definition.Schedule.Windows = nil
	expectLocalNode(t, e, "a1")
	e.config.Overrides = []LocalPolicyOverride{{PolicyID: "p", NodeID: "b2", ExpiresAt: now.Add(time.Minute).UnixMilli()}}
	expectLocalNode(t, e, "b2")
	expire := now.UnixMilli()
	e.sources["b"] = LocalPolicySource{ID: "b", ExpiresAt: &expire}
	expectLocalNode(t, e, "a1")
}
func TestLocalPolicyProbeUsesExactNodeAndExpectedStatus(t *testing.T) {
	e, cfg, leaves, _ := localFixture(t)
	e.install(cfg)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(http.StatusUnauthorized) }))
	defer server.Close()
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	if err := probeLocalPolicyNode(ctx, e.proxies["a1"], LocalPolicyProbe{URL: server.URL}); err == nil {
		t.Fatal("401 accepted as healthy")
	}
	if leaves["a1"].calls.Load() != 1 || leaves["b2"].calls.Load() != 0 || leaves["c3"].calls.Load() != 0 {
		t.Fatal("probe used unexpected node")
	}
	if err := probeLocalPolicyNode(ctx, e.proxies["a1"], LocalPolicyProbe{URL: server.URL, ExpectedStatus: "401"}); err != nil {
		t.Fatal(err)
	}
}
func TestLocalPolicyTCPUDPAdmissionAndIndependentScopedClosure(t *testing.T) {
	e, cfg, leaves, now := localFixture(t)
	healthyLocalNodes(e)
	e.policies["p"].definition.TerminateConnectionsOnExclusion = true
	e.install(cfg)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {}))
	defer server.Close()
	metadata := &C.Metadata{NetWork: C.TCP}
	if err := metadata.SetRemoteAddress(server.Listener.Addr().String()); err != nil {
		t.Fatal(err)
	}
	group := cfg.Proxies["managed"]
	tcp, err := group.DialContext(context.Background(), metadata)
	if err != nil {
		t.Fatal(err)
	}
	udp, err := group.ListenPacketContext(context.Background(), metadata)
	if err != nil {
		t.Fatal(err)
	}
	untouched, err := e.proxies["b2"].ListenPacketContext(context.Background(), metadata)
	if err != nil {
		t.Fatal(err)
	}
	defer untouched.Close()
	expire := now.UnixMilli()
	e.sources["a"] = LocalPolicySource{ID: "a", ExpiresAt: &expire}
	delete(e.proxies, "b2")
	calls := leaves["a1"].calls.Load()
	packets := leaves["a1"].packets.Load()
	if conn, err := group.DialContext(context.Background(), metadata); err == nil {
		conn.Close()
		t.Fatal("TCP admission bypass")
	}
	if conn, err := group.ListenPacketContext(context.Background(), metadata); err == nil {
		conn.Close()
		t.Fatal("UDP admission bypass")
	}
	if calls != leaves["a1"].calls.Load() || packets != leaves["a1"].packets.Load() {
		t.Fatal("excluded node was dialed")
	}
	e.tick()
	if _, err := tcp.Write([]byte("closed")); err == nil {
		t.Fatal("existing TCP was not closed")
	}
	if _, err := udp.WriteTo([]byte("closed"), &net.UDPAddr{IP: net.ParseIP("127.0.0.1"), Port: server.Listener.Addr().(*net.TCPAddr).Port}); err == nil {
		t.Fatal("existing UDP was not closed")
	}
	if err := untouched.SetReadDeadline(time.Now()); err != nil {
		t.Fatal("unrelated source closed", err)
	}
}
func TestLocalPolicyBudgetCountsBuffersAndRetainsIdentity(t *testing.T) {
	e, cfg, _, now := localFixture(t)
	e.ledger.configure([]LocalPolicyBudget{{SourceID: "a", LimitBytes: 5, ResetDay: 1, TimeZone: "Asia/Shanghai"}}, *now)
	e.install(cfg)
	left, right := net.Pipe()
	defer right.Close()
	conn := &localPolicyConn{Conn: outbound.NewConn(left, outbound.NewBase(outbound.BaseOption{Name: "test"})), engine: e, identity: LocalPolicyIdentity{SourceID: "a", NodeID: "a1", PolicyID: "p", Revision: 3}, account: true}
	defer conn.Close()
	done := make(chan struct{})
	go func() {
		buffer := make([]byte, 3)
		_, _ = right.Read(buffer)
		_, _ = right.Write([]byte("ok"))
		close(done)
	}()
	if err := conn.WriteBuffer(buf.As([]byte("abc"))); err != nil {
		t.Fatal(err)
	}
	buffer := make([]byte, 2)
	if _, err := conn.Read(buffer); err != nil {
		t.Fatal(err)
	}
	<-done
	if reason := e.ledger.reason("a", *now, "exclude"); reason != "budget_exhausted" {
		t.Fatal(reason)
	}
	tracker := statistic.NewTCPTracker(conn, statistic.DefaultManager, &C.Metadata{NetWork: C.TCP}, nil, 0, 0, false)
	defer tracker.Close()
	collector := newUsageCollector()
	collector.enabled = true
	collector.track(tracker)
	dimensions := collector.tracked[tracker.ID()].dimensions
	e.config.Revision = 4
	e.nodes["a1"] = LocalPolicyNode{ID: "a1", SourceID: "changed"}
	if dimensions.sourceID != "a" || dimensions.nodeID != "a1" || dimensions.policyID != "p" {
		t.Fatalf("identity not frozen %+v", dimensions)
	}
}
func TestLocalPolicyBudgetPersistenceCrashClockAndFailure(t *testing.T) {
	path := filepath.Join(t.TempDir(), "budget.json")
	now := time.Date(2026, 10, 25, 0, 0, 0, 0, time.UTC)
	b := LocalPolicyBudget{SourceID: "a", LimitBytes: 100, ResetDay: 1, TimeZone: "Asia/Shanghai"}
	l := newLocalBudgetLedger(path)
	l.configure([]LocalPolicyBudget{b}, now)
	l.count("a", 45, now)
	l.save(true)
	clean := newLocalBudgetLedger(path)
	clean.configure([]LocalPolicyBudget{b}, now)
	if status := clean.status(now)[0]; status.UsedBytes != 45 || !status.Trusted {
		t.Fatal(status)
	}
	clean.save(false)
	crash := newLocalBudgetLedger(path)
	crash.configure([]LocalPolicyBudget{b}, now)
	if reason := crash.reason("a", now, "exclude"); reason != "budget_untrusted" {
		t.Fatal(reason)
	}
	if reason := crash.reason("a", now, "allow"); reason != "budget_untrusted" {
		t.Fatal(reason)
	}
	later := now.AddDate(0, 1, 0)
	if reason := crash.reason("a", later, "exclude"); reason != "" {
		t.Fatal(reason)
	}
	crash.count("a", 80, later)
	if status := crash.status(now)[0]; status.UsedBytes != 80 {
		t.Fatal("backward clock reset", status)
	}
	b.ResetDay = 20
	crash.configure([]LocalPolicyBudget{b}, later)
	if status := crash.status(later)[0]; status.UsedBytes != 80 {
		t.Fatal("schedule edit reset", status)
	}
	if err := os.WriteFile(path, []byte("broken"), 0600); err != nil {
		t.Fatal(err)
	}
	bad := newLocalBudgetLedger(path)
	bad.configure([]LocalPolicyBudget{b}, now)
	if reason := bad.reason("a", now, "exclude"); reason != "budget_untrusted" {
		t.Fatal(reason)
	}
	bad.path = filepath.Join(path, "not-a-directory")
	bad.save(false)
	if bad.errorMessage() == "" {
		t.Fatal("persistence failure hidden")
	}
}
func TestLocalPolicyValidationDisabledMissingAndUnknownFields(t *testing.T) {
	e, cfg, _, _ := localFixture(t)
	c := e.config
	c.Policies[0].CandidateNodeIDs = []string{"missing", "b2"}
	if err := validateLocalPolicyConfig(&c); err != nil {
		t.Fatal(err)
	}
	if engine, err := prepareLocalPolicy(&c, cfg, e.ledger); err != nil {
		t.Fatal(err)
	} else {
		engine.cancel()
	}
	c.Enabled = false
	cfg.General.Mode = tunnel.Global
	if engine, err := prepareLocalPolicy(&c, cfg, e.ledger); err != nil || engine != nil {
		t.Fatal("disabled changed legacy behavior", err)
	}
	data, err := yaml.Marshal(map[string]any{"flclash-local-policy": c})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := parseLocalPolicyConfig(data); err != nil {
		t.Fatal(err)
	}
	if _, err := parseLocalPolicyConfig([]byte("mode: rule\n")); err != nil {
		t.Fatal(err)
	}
	if _, err := parseLocalPolicyConfig([]byte("flclash-local-policy:\n  schemaVersion: 1\n  unexpected: true\n")); err == nil {
		t.Fatal("unknown extension field accepted")
	}
}

func TestLocalPolicyProbeSharingConcurrencyAndStaleShutdown(t *testing.T) {
	e, _, _, _ := localFixture(t)
	release := make(chan struct{})
	started := make(chan string, 20)
	e.probe = func(ctx context.Context, p C.Proxy, _ LocalPolicyProbe) error {
		started <- p.Name()
		select {
		case <-release:
			return nil
		case <-ctx.Done():
			return ctx.Err()
		}
	}
	first := e.policies["p"]
	second := &localPolicyRuntime{definition: first.definition, health: map[string]*localNodeHealth{"a1": {}, "b2": {}}}
	second.definition.ID = "p2"
	second.definition.GroupName = "managed2"
	e.policies["p2"] = second
	e.config.Policies = append(e.config.Policies, second.definition)
	e.tick()
	for index := 0; index < 2; index++ {
		select {
		case <-started:
		case <-time.After(time.Second):
			t.Fatal("probe not started")
		}
	}
	e.mu.Lock()
	workers := e.workers
	pending := len(e.inFlight)
	e.mu.Unlock()
	if workers != 2 || pending != 2 {
		t.Fatalf("identical probes not shared: workers=%d pending=%d", workers, pending)
	}
	e.stop()
	if first.health["a1"].healthy || second.health["a1"].healthy {
		t.Fatal("cancelled result admitted node")
	}
	close(release)
}
func TestLocalPolicyBudgetOnlyAdmissionAndKnownExpiry(t *testing.T) {
	e, cfg, leaves, now := localFixture(t)
	c := e.config
	c.Policies = nil
	c.Budgets = []LocalPolicyBudget{{SourceID: "a", LimitBytes: 0, ResetDay: 1, TimeZone: "Asia/Shanghai"}}
	cfg.General.Mode = tunnel.Global
	budgetOnly, err := prepareLocalPolicy(&c, cfg, e.ledger)
	if err != nil {
		t.Fatal(err)
	}
	defer budgetOnly.stop()
	budgetOnly.now = e.now
	e.ledger.configure(c.Budgets, *now)
	budgetOnly.install(cfg)
	metadata := &C.Metadata{NetWork: C.TCP}
	_ = metadata.SetRemoteAddress("127.0.0.1:1")
	if _, err := cfg.Proxies["A1"].DialContext(context.Background(), metadata); err == nil {
		t.Fatal("zero budget admitted TCP")
	}
	if _, err := cfg.Proxies["A1"].ListenPacketContext(context.Background(), metadata); err == nil {
		t.Fatal("zero budget admitted UDP")
	}
	expire := now.UnixMilli()
	budgetOnly.sources["b"] = LocalPolicySource{ID: "b", ExpiresAt: &expire}
	if _, err := cfg.Proxies["B2"].DialContext(context.Background(), metadata); err == nil {
		t.Fatal("known expiry admitted source")
	}
	if leaves["a1"].calls.Load() != 0 || leaves["a1"].packets.Load() != 0 || leaves["b2"].calls.Load() != 0 {
		t.Fatal("blocked source was dialed")
	}
	snapshot := budgetOnly.snapshot()
	if !snapshot.Enabled || len(snapshot.Policies) != 0 || len(snapshot.Budgets) != 1 {
		t.Fatal(snapshot)
	}
}

type failingLocalCloser struct{}

func (failingLocalCloser) Close() error { return errors.New("close failure") }
func TestLocalPolicyTerminationFailureKeepsAdmissionBlocked(t *testing.T) {
	e, _, _, now := localFixture(t)
	healthyLocalNodes(e)
	r := e.policies["p"]
	r.definition.TerminateConnectionsOnExclusion = true
	if _, err := e.register("p", "a1", failingLocalCloser{}); err != nil {
		t.Fatal(err)
	}
	expire := now.UnixMilli()
	e.sources["a"] = LocalPolicySource{ID: "a", ExpiresAt: &expire}
	delete(e.proxies, "b2")
	e.tick()
	expectLocalNode(t, e, "")
	if r.terminationError == "" {
		t.Fatal("termination error hidden")
	}
	if clean := closeLocalPolicyConnections(); clean {
		t.Fatal("failed termination marked clean")
	}
}

func TestLocalPolicySchemaFixtureAndReadOnlyValidation(t *testing.T) {
	data, err := os.ReadFile("testdata/local_policy.yaml")
	if err != nil {
		t.Fatal(err)
	}
	c, err := parseLocalPolicyConfig(data)
	if err != nil {
		t.Fatal(err)
	}
	if c.Revision != 3 || len(c.Policies) != 1 || c.Sources[1].ExpiresAt != nil {
		t.Fatal("fixture contract lost null identity")
	}
	path := filepath.Join(t.TempDir(), "candidate.yaml")
	if err := os.WriteFile(path, data, 0600); err != nil {
		t.Fatal(err)
	}
	prior := activeLocalPolicy.Load()
	if result := handleValidateConfig(path); result != "" {
		t.Fatal(result)
	}
	if activeLocalPolicy.Load() != prior {
		t.Fatal("validation changed active engine")
	}
}

func TestLocalPolicyExpiredOverrideReturnsLongTermControl(t *testing.T) {
	e, _, _, now := localFixture(t)
	healthyLocalNodes(e)
	e.policies["p"].definition.AutoRecover = false
	e.config.Overrides = []LocalPolicyOverride{{PolicyID: "p", NodeID: "b2", ExpiresAt: now.Add(time.Second).UnixMilli()}}
	expectLocalNode(t, e, "b2")
	*now = now.Add(time.Second)
	expectLocalNode(t, e, "a1")
}

func TestLocalPolicyProbeConcurrencyBoundAndFairness(t *testing.T) {
	e, _, _, now := localFixture(t)
	r := e.policies["p"]
	r.definition.CandidateNodeIDs = nil
	r.definition.Probe.IntervalSeconds = 1
	r.definition.Probe.TimeoutSeconds = 1
	r.health = map[string]*localNodeHealth{}
	for index := 0; index < 10; index++ {
		id := string(rune('d' + index))
		r.definition.CandidateNodeIDs = append(r.definition.CandidateNodeIDs, id)
		r.health[id] = &localNodeHealth{}
		e.nodes[id] = LocalPolicyNode{ID: id, SourceID: "a", ProxyName: id}
		e.proxies[id] = adapter.NewProxy(outbound.NewBase(outbound.BaseOption{Name: id, Type: C.Shadowsocks}))
	}
	e.config.Policies = []LocalPolicyDefinition{r.definition}
	started := make(chan string, 20)
	release := make(chan struct{})
	e.probe = func(ctx context.Context, p C.Proxy, _ LocalPolicyProbe) error {
		started <- p.Name()
		select {
		case <-release:
			return nil
		case <-ctx.Done():
			return ctx.Err()
		}
	}
	e.tick()
	seen := map[string]bool{}
	for index := 0; index < 8; index++ {
		select {
		case name := <-started:
			seen[name] = true
		case <-time.After(time.Second):
			t.Fatal("probe not started")
		}
	}
	e.mu.Lock()
	workers := e.workers
	e.mu.Unlock()
	if workers != 8 {
		t.Fatalf("worker bound %d", workers)
	}
	status := e.snapshot()
	if !status.Policies[0].Nodes[9].DetectionDelayed {
		t.Fatal("saturated probe not marked delayed")
	}
	close(release)
	e.wg.Wait()
	*now = now.Add(time.Second)
	e.tick()
	e.wg.Wait()
	for len(started) > 0 {
		seen[<-started] = true
	}
	if !seen["l"] || !seen["m"] {
		t.Fatal("late candidates starved", seen)
	}
}

type shortLocalConn struct{ net.Conn }

func (shortLocalConn) Write([]byte) (int, error) { return 2, errors.New("partial write") }
func TestLocalPolicyPartialBufferAccountingAndFailedStorageAcrossReset(t *testing.T) {
	e, _, _, now := localFixture(t)
	budget := LocalPolicyBudget{SourceID: "a", LimitBytes: 100, ResetDay: 1, TimeZone: "Asia/Shanghai"}
	e.ledger.configure([]LocalPolicyBudget{budget}, *now)
	left, right := net.Pipe()
	defer right.Close()
	connection := &localPolicyConn{Conn: outbound.NewConn(shortLocalConn{Conn: left}, outbound.NewBase(outbound.BaseOption{Name: "partial"})), engine: e, identity: LocalPolicyIdentity{SourceID: "a"}, account: true}
	defer connection.Close()
	if err := connection.WriteBuffer(buf.As([]byte("abcdef"))); err == nil {
		t.Fatal("partial write error hidden")
	}
	if status := e.ledger.status(*now)[0]; status.UsedBytes != 2 {
		t.Fatal("partial write lost bytes", status)
	}
	e.ledger.path = filepath.Join(t.TempDir(), "missing", "budget.json")
	e.ledger.save(false)
	future := now.AddDate(0, 1, 0)
	if reason := e.ledger.reason("a", future, "exclude"); reason != "budget_untrusted" {
		t.Fatal("period reset bypassed broken storage", reason)
	}
	if !e.ledger.waitForIO() {
		t.Fatal("completed I/O remained active")
	}
}

func TestLocalPolicyRejectsExternalControllersAndModeBypass(t *testing.T) {
	e, cfg, _, _ := localFixture(t)
	variations := []*config.Controller{{ExternalController: "127.0.0.1:9090"}, {ExternalControllerTLS: "127.0.0.1:9091"}, {ExternalControllerUnix: "controller.sock"}, {ExternalControllerPipe: "controller"}}
	for _, controller := range variations {
		cfg.Controller = controller
		if engine, err := prepareLocalPolicy(&e.config, cfg, e.ledger); err == nil {
			engine.cancel()
			t.Fatal("external controller accepted")
		}
	}
	cfg.Controller = nil
	cfg.General.Mode = tunnel.Global
	if engine, err := prepareLocalPolicy(&e.config, cfg, e.ledger); err == nil {
		engine.cancel()
		t.Fatal("managed policy accepted global mode")
	}
	prior := activeLocalPolicy.Swap(e)
	defer activeLocalPolicy.Store(prior)
	mode := tunnel.Direct
	controller := "127.0.0.1:9090"
	if err := updateConfig(&UpdateParams{Mode: &mode}); err == nil {
		t.Fatal("mode mutation bypassed guard")
	}
	if err := updateConfig(&UpdateParams{ExternalController: &controller}); err == nil {
		t.Fatal("controller mutation bypassed guard")
	}
}

func TestLocalPolicySetupCannotResumeAfterShutdownState(t *testing.T) {
	previous := isInit.Swap(false)
	defer isInit.Store(previous)
	prior := activeLocalPolicy.Load()
	if err := applyConfig(defaultSetupParams()); err == nil || err.Error() != "not initialized" {
		t.Fatal("shutdown setup admitted", err)
	}
	if activeLocalPolicy.Load() != prior {
		t.Fatal("shutdown setup changed active engine")
	}
}

func TestLocalPolicyStatusSeparatesDocumentAndActivationRevision(t *testing.T) {
	e, _, _, _ := localFixture(t)
	documentRevision := int64(1)
	e.config.DocumentRevision = &documentRevision
	snapshot := e.snapshot()
	if snapshot.Revision != 3 || snapshot.DocumentRevision != 1 {
		t.Fatal(snapshot)
	}
	e.config.DocumentRevision = nil
	if fallback := e.snapshot().DocumentRevision; fallback != 3 {
		t.Fatal("missing document revision did not default", fallback)
	}
}

func TestBudgetPeriodTimeZones(t *testing.T) {
	instant := time.Date(2026, time.November, 1, 0, 30, 0, 0, time.FixedZone("Asia/Shanghai", 8*60*60))
	utc := LocalPolicyBudget{ResetDay: 1, TimeZone: "UTC"}
	shanghai := LocalPolicyBudget{ResetDay: 1, TimeZone: "Asia/Shanghai"}
	if actual := budgetPeriod(instant, utc); actual != time.Date(2026, time.October, 1, 0, 0, 0, 0, time.UTC).UnixMilli() {
		t.Fatalf("UTC month boundary: %d", actual)
	}
	if actual := budgetPeriod(instant, shanghai); actual != time.Date(2026, time.November, 1, 0, 0, 0, 0, instant.Location()).UnixMilli() {
		t.Fatalf("Shanghai month boundary: %d", actual)
	}
	instant = time.Date(2026, time.November, 1, 0, 0, 0, 0, time.UTC)
	if actual := budgetPeriod(instant, utc); actual != instant.UnixMilli() {
		t.Fatalf("UTC reset equality: %d", actual)
	}
}

func TestBudgetTimeZoneEditsPreserveUsage(t *testing.T) {
	ledger := newLocalBudgetLedger("")
	now := time.Date(2026, time.October, 13, 0, 0, 0, 0, time.UTC)
	budget := LocalPolicyBudget{SourceID: "a", LimitBytes: 100, ResetDay: 1, TimeZone: "Asia/Shanghai"}
	ledger.configure([]LocalPolicyBudget{budget}, now)
	ledger.count("a", 80, now)
	budget.TimeZone = "UTC"
	ledger.configure([]LocalPolicyBudget{budget}, now)
	if got := ledger.status(now)[0]; got.UsedBytes != 80 || !got.Trusted {
		t.Fatalf("zone edit reset usage: %+v", got)
	}
	budget.TimeZone = "Asia/Shanghai"
	ledger.configure([]LocalPolicyBudget{budget}, now)
	if got := ledger.status(now)[0].UsedBytes; got != 80 {
		t.Fatalf("reverse zone edit reset usage: %d", got)
	}
	if got := ledger.status(now.AddDate(0, 1, 0))[0].UsedBytes; got != 0 {
		t.Fatalf("new cycle did not reset: %d", got)
	}
}

func TestLocalPolicySourceRefreshImmediatelyClosesAndGatesTCPUDP(t *testing.T) {
	e, cfg, leaves, now := localFixture(t)
	healthyLocalNodes(e)
	e.install(cfg)
	previous := activeLocalPolicy.Swap(e)
	defer activeLocalPolicy.Store(previous)
	server := httptest.NewServer(http.HandlerFunc(func(http.ResponseWriter, *http.Request) {}))
	defer server.Close()
	metadata := &C.Metadata{NetWork: C.TCP}
	if err := metadata.SetRemoteAddress(server.Listener.Addr().String()); err != nil {
		t.Fatal(err)
	}
	tcp, err := cfg.Proxies["managed"].DialContext(context.Background(), metadata)
	if err != nil {
		t.Fatal(err)
	}
	defer tcp.Close()
	udp, err := cfg.Proxies["managed"].ListenPacketContext(context.Background(), metadata)
	if err != nil {
		t.Fatal(err)
	}
	defer udp.Close()
	unrelated, err := e.proxies["b2"].ListenPacketContext(context.Background(), metadata)
	if err != nil {
		t.Fatal(err)
	}
	defer unrelated.Close()
	delete(e.proxies, "b2")
	expiry := now.UnixMilli()
	if result := handleRefreshLocalPolicySource(LocalPolicySourceRefresh{Revision: 3, Sequence: 1, Source: LocalPolicySourceMetadata{ID: "a", ExpiresAt: &expiry, ObservedAt: &expiry}}); result != "" {
		t.Fatal(result)
	}
	if activeLocalPolicy.Load() != e || cfg.Proxies["managed"].Name() != "managed" {
		t.Fatal("refresh replaced the configuration")
	}
	for _, target := range []C.Proxy{cfg.Proxies["managed"], e.proxies["a1"]} {
		if conn, err := target.DialContext(context.Background(), metadata); err == nil {
			conn.Close()
			t.Fatal("refreshed expiry bypassed TCP admission")
		}
		if conn, err := target.ListenPacketContext(context.Background(), metadata); err == nil {
			conn.Close()
			t.Fatal("refreshed expiry bypassed UDP admission")
		}
	}
	if leaves["a1"].calls.Load() != 1 || leaves["a1"].packets.Load() != 1 {
		t.Fatal("expired source was dialed")
	}
	if _, err := tcp.Write([]byte("closed")); err == nil {
		t.Fatal("existing TCP remains open")
	}
	if _, err := udp.WriteTo([]byte("closed"), server.Listener.Addr()); err == nil {
		t.Fatal("existing UDP remains open")
	}
	if err := unrelated.SetReadDeadline(time.Now()); err != nil {
		t.Fatal("unrelated source closed", err)
	}
	if _, err := e.register("", "a1", failingLocalCloser{}); err == nil {
		t.Fatal("expiry update during dial bypassed registration gate")
	}
}

func TestLocalPolicySourceRefreshCASUnknownAndBoundaries(t *testing.T) {
	e, _, _, now := localFixture(t)
	expiry, remaining, observed := now.Add(time.Hour).UnixMilli(), int64(1000), now.UnixMilli()
	e.sources["a"] = LocalPolicySource{ID: "a", Label: "preserved", ExpiresAt: &expiry, RemainingBytes: &remaining, ObservedAt: &observed}
	input := LocalPolicySourceRefresh{Revision: 2, Sequence: 1, Source: LocalPolicySourceMetadata{ID: "a"}}
	if result := e.refreshSource(input); result != "local_policy_source_revision_conflict" {
		t.Fatal(result)
	}
	if e.sources["a"].RemainingBytes == nil {
		t.Fatal("stale CAS mutated data")
	}
	input.Revision = 3
	stale := observed - 1
	input.Source.ObservedAt = &stale
	if result := e.refreshSource(input); result != "local_policy_source_observation_stale" {
		t.Fatal(result)
	}
	input.Source.ObservedAt = nil
	input.Sequence = 2
	if result := e.refreshSource(input); result != "" {
		t.Fatal(result)
	}
	actual := e.sources["a"]
	if actual.ExpiresAt == nil || *actual.ExpiresAt != expiry || actual.Label != "preserved" || actual.RemainingBytes != nil || actual.ObservedAt != nil {
		t.Fatal("unknown snapshot did not clear remaining/observed or lost expiry", actual)
	}
	p := e.policies["p"].definition
	p.Guard.MinRemainingBytes = 1
	if reason := e.sourceReasonLocked("a1", p, *now); reason != "metadata_unknown" {
		t.Fatal(reason)
	}
	input.Source.ID = "new"
	if result := e.refreshSource(input); result != "local_policy_source_missing" {
		t.Fatal(result)
	}
	if len(e.sources) != 3 {
		t.Fatal("refresh introduced a source")
	}
	input.Source.ID = "a"
	invalid := int64(9007199254740992)
	input.Source.RemainingBytes = &invalid
	if result := e.refreshSource(input); result != "local_policy_source_invalid" {
		t.Fatal(result)
	}
}

func TestLocalPolicySourceRefreshTerminationFailureStaysExcluded(t *testing.T) {
	e, _, _, now := localFixture(t)
	healthyLocalNodes(e)
	if _, err := e.register("p", "a1", failingLocalCloser{}); err != nil {
		t.Fatal(err)
	}
	expiry := now.UnixMilli()
	delete(e.proxies, "b2")
	if result := e.refreshSource(LocalPolicySourceRefresh{Revision: 3, Sequence: 1, Source: LocalPolicySourceMetadata{ID: "a", ExpiresAt: &expiry}}); result != "local_policy_source_termination_failed" {
		t.Fatal(result)
	}
	expectLocalNode(t, e, "")
	if e.sources["a"].ExpiresAt == nil || e.policies["p"].terminationError == "" {
		t.Fatal("failure erased the admission guard or diagnostic")
	}
}

func TestLocalPolicySourceRefreshStrictJSONContract(t *testing.T) {
	for _, data := range []string{
		`{"revision":3,"sequence":1,"source":{"id":"a","expiresAt":null,"remainingBytes":null,"observedAt":null}}`,
		`{"revision":3,"sequence":1,"source":{"id":"a","remainingBytes":0,"observedAt":0}}`,
	} {
		if _, err := decodeLocalPolicySourceRefresh([]byte(data)); err != nil {
			t.Fatal(data, err)
		}
	}
	for _, data := range []string{
		`{"revision":3,"source":{"id":"a","remainingBytes":null,"observedAt":null}}`,
		`{"revision":3,"sequence":null,"source":{"id":"a","remainingBytes":null,"observedAt":null}}`,
		`{"revision":3,"sequence":0,"source":{"id":"a","remainingBytes":null,"observedAt":null}}`,
		`{"revision":3,"sequence":9007199254740992,"source":{"id":"a","remainingBytes":null,"observedAt":null}}`,
		`{"revision":null,"sequence":1,"source":{"id":"a","remainingBytes":null,"observedAt":null}}`,
		`{"revision":3,"sequence":1,"source":{"id":"a","observedAt":1}}`,
		`{"revision":3,"sequence":1,"source":{"id":"a","remainingBytes":1}}`,
		`{"revision":3,"sequence":1,"source":{"id":"a","remainingBytes":null,"observedAt":null,"label":"changed"}}`,
		`{"revision":3,"sequence":1,"source":{"id":"a","remainingBytes":null,"observedAt":null},"nodes":[]}`,
		`{"revision":3,"sequence":1,"source":{"id":"a","remainingBytes":null,"observedAt":null}} {}`,
	} {
		if _, err := decodeLocalPolicySourceRefresh([]byte(data)); err == nil {
			t.Fatal("accepted invalid contract", data)
		}
	}
}

func TestLocalPolicySourceRefreshSequencePreventsExpiredSourceReopening(t *testing.T) {
	e, cfg, leaves, now := localFixture(t)
	healthyLocalNodes(e)
	e.install(cfg)
	expired, future, observed := now.UnixMilli(), now.Add(time.Hour).UnixMilli(), now.UnixMilli()
	input := LocalPolicySourceRefresh{Revision: 3, Sequence: 2, Source: LocalPolicySourceMetadata{ID: "a", ExpiresAt: &expired, ObservedAt: &observed}}
	if result := e.refreshSource(input); result != "" {
		t.Fatal(result)
	}
	for _, sequence := range []int64{1, 2} {
		for _, observation := range []*int64{nil, &observed} {
			old := LocalPolicySourceRefresh{Revision: 3, Sequence: sequence, Source: LocalPolicySourceMetadata{ID: "a", ExpiresAt: &future, ObservedAt: observation}}
			if result := e.refreshSource(old); result != "local_policy_source_sequence_stale" {
				t.Fatal(result)
			}
			if *e.sources["a"].ExpiresAt != expired || *e.sources["a"].ObservedAt != observed {
				t.Fatal("older request overwrote the expired snapshot")
			}
			if conn, err := e.proxies["a1"].DialContext(context.Background(), &C.Metadata{}); err == nil {
				conn.Close()
				t.Fatal("older request reopened TCP")
			}
			if conn, err := e.proxies["a1"].ListenPacketContext(context.Background(), &C.Metadata{}); err == nil {
				conn.Close()
				t.Fatal("older request reopened UDP")
			}
		}
	}
	if leaves["a1"].calls.Load() != 0 || leaves["a1"].packets.Load() != 0 {
		t.Fatal("stale refresh attempted an outbound")
	}
	input.Source.ID = "b"
	input.Sequence = 1
	if result := e.refreshSource(input); result != "" {
		t.Fatal("sequence was shared across sources", result)
	}
	input.Source.ID = "a"
	input.Sequence = 3
	input.Source.ExpiresAt = &future
	input.Source.ObservedAt = nil
	if result := e.refreshSource(input); result != "" {
		t.Fatal("latest snapshot with unknown observation was rejected", result)
	}
	if *e.sources["a"].ExpiresAt != future || e.sources["a"].ObservedAt != nil {
		t.Fatal("latest snapshot was not applied")
	}
}
