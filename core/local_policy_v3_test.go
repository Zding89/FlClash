package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"net/netip"
	"os"
	"path/filepath"
	"reflect"
	"sync"
	"testing"
	"time"

	"github.com/metacubex/mihomo/adapter"
	"github.com/metacubex/mihomo/adapter/outbound"
	"github.com/metacubex/mihomo/component/geodata"
	"github.com/metacubex/mihomo/component/geodata/router"
	_ "github.com/metacubex/mihomo/component/geodata/standard"
	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/rules"
	RC "github.com/metacubex/mihomo/rules/common"
	"github.com/metacubex/mihomo/tunnel"
	"google.golang.org/protobuf/proto"
)

func v3Fixture(t *testing.T) *localPolicyEngine {
	t.Helper()
	e, _, _, now := localFixture(t)
	yes := true
	e.config.SchemaVersion = 3
	e.config.Policies[0].Action = "proxy"
	e.config.Policies[0].SkipUnavailable = &yes
	e.config.Policies[0].CandidateNodeIDs = nil
	e.config.Policies[0].Choices = []LocalPolicyChoice{{Type: "nodeSet", ID: "pool"}}
	e.config.NodeSets = []LocalNodeSet{{ID: "pool", SourceIDs: []string{"a", "b", "c"}, SelectionMode: "priority", Strategy: "stable", UnknownMultiplier: "assumeOne", ImprovementPercent: 20, Probe: e.config.Policies[0].Probe}}
	if err := validateLocalPolicyConfig(&e.config); err != nil {
		t.Fatal(err)
	}
	if err := e.prepareNodeSets(&e.config); err != nil {
		t.Fatal(err)
	}
	e.policies["p"].definition = e.config.Policies[0]
	for _, h := range e.sets["pool"].health {
		h.healthy = true
		h.lastProbe = *now
	}
	return e
}

func TestV3ValidationActionsSchedulesAndPreferences(t *testing.T) {
	e := v3Fixture(t)
	baseline, _ := json.Marshal(e.config)
	cases := []struct {
		name   string
		change func(*LocalPolicyConfig)
	}{
		{"skip missing", func(c *LocalPolicyConfig) { c.Policies[0].SkipUnavailable = nil }},
		{"skip false", func(c *LocalPolicyConfig) { no := false; c.Policies[0].SkipUnavailable = &no }},
		{"action", func(c *LocalPolicyConfig) { c.Policies[0].Action = "unknown" }},
		{"equal window", func(c *LocalPolicyConfig) {
			c.NodeSets[0].Schedule = &LocalPolicySchedule{TimeZone: "UTC", Windows: []LocalPolicyScheduleWindow{{Weekdays: []int{1}, StartMinute: 30, EndMinute: 30}}}
		}},
		{"preference duplicate", func(c *LocalPolicyConfig) {
			c.NodeSets[0].Preferences = []LocalNodePreference{{Type: "latency", Direction: "ascending"}, {Type: "latency", Direction: "descending"}}
		}},
		{"preference direction", func(c *LocalPolicyConfig) {
			c.NodeSets[0].Preferences = []LocalNodePreference{{Type: "remaining", Direction: "up"}}
		}},
		{"selection", func(c *LocalPolicyConfig) { c.NodeSets[0].SelectionMode = "weighted" }},
		{"balance", func(c *LocalPolicyConfig) { c.NodeSets[0].BalanceStrategy = "random" }},
		{"source exclusion", func(c *LocalPolicyConfig) { c.NodeSets[0].ExcludedSourceIDs = []string{"missing"} }},
		{"empty name", func(c *LocalPolicyConfig) { c.NodeSets[0].NameIncludes = []string{" "} }},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			var c LocalPolicyConfig
			_ = json.Unmarshal(baseline, &c)
			tc.change(&c)
			if validateLocalPolicyConfig(&c) == nil {
				t.Fatal("invalid config accepted")
			}
		})
	}
	for _, action := range []string{"direct", "reject"} {
		var c LocalPolicyConfig
		_ = json.Unmarshal(baseline, &c)
		c.Policies[0].Action = action
		c.Policies[0].Choices = nil
		c.Policies[0].CandidateNodeIDs = nil
		c.Policies[0].Probe = LocalPolicyProbe{}
		if err := validateLocalPolicyConfig(&c); err != nil {
			t.Fatal(action, err)
		}
	}
}

func TestV3OrderedPreferencesDirectionsAndUnknowns(t *testing.T) {
	e := v3Fixture(t)
	now := e.now()
	expiryA, expiryB := now.Add(time.Hour).UnixMilli(), now.Add(2*time.Hour).UnixMilli()
	remainingA, remainingB := int64(100), int64(200)
	e.sources["a"] = LocalPolicySource{ID: "a", ExpiresAt: &expiryA, RemainingBytes: &remainingA}
	e.sources["b"] = LocalPolicySource{ID: "b", ExpiresAt: &expiryB, RemainingBytes: &remainingB}
	latencyA, latencyB := int64(20), int64(10)
	e.sets["pool"].health["a1"].latencyMillis = &latencyA
	e.sets["pool"].health["b2"].latencyMillis = &latencyB
	multiplier := 0.5
	n := e.nodes["a1"]
	n.Multiplier = &multiplier
	e.nodes["a1"] = n
	cases := []struct{ kind, direction, want string }{
		{"expiry", "ascending", "a1"}, {"expiry", "descending", "b2"},
		{"remaining", "ascending", "a1"}, {"remaining", "descending", "b2"},
		{"latency", "ascending", "b2"}, {"latency", "descending", "a1"},
		{"multiplier", "ascending", "a1"}, {"multiplier", "descending", "b2"},
		{"source", "ascending", "a1"}, {"source", "descending", "c3"},
	}
	for _, tc := range cases {
		t.Run(tc.kind+tc.direction, func(t *testing.T) {
			set := e.setDefinitions["pool"]
			set.Preferences = []LocalNodePreference{{Type: tc.kind, Direction: tc.direction}}
			e.setDefinitions["pool"] = set
			expectLocalNode(t, e, tc.want)
		})
	}
	set := e.setDefinitions["pool"]
	set.Preferences = []LocalNodePreference{{Type: "remaining", Direction: "descending"}, {Type: "latency", Direction: "ascending"}}
	e.setDefinitions["pool"] = set
	e.sources["b"] = LocalPolicySource{ID: "b", RemainingBytes: &remainingA}
	expectLocalNode(t, e, "b2")
	e.sets["pool"].health["b2"].healthy = false
	expectLocalNode(t, e, "a1")
	zero := int64(0)
	source := e.sources["a"]
	source.ExpiresAt = &zero
	e.sources["a"] = source
	p := e.policies["p"].definition
	p.Guard.ExpiryMarginSeconds = 3600
	stamp := now.UnixMilli()
	source.ObservedAt = &stamp
	e.sources["a"] = source
	if reason := e.sourceReasonLocked("a1", p, now); reason != "" {
		t.Fatal("known unlimited expiry excluded", reason)
	}
	p.Guard.MetadataMaxAgeSeconds = 1
	if reason := e.sourceReasonLocked("a1", p, now.Add(2*time.Second)); reason != "metadata_stale" {
		t.Fatal("unlimited expiry bypassed observation freshness", reason)
	}
	largeA, largeB := int64(9007199254740992), int64(9007199254740993)
	e.sources["a"] = LocalPolicySource{ID: "a", RemainingBytes: &largeA}
	e.sources["b"] = LocalPolicySource{ID: "b", RemainingBytes: &largeB}
	e.sets["pool"].health["b2"].healthy = true
	set.Preferences = []LocalNodePreference{{Type: "remaining", Direction: "descending"}}
	e.setDefinitions["pool"] = set
	expectLocalNode(t, e, "b2")
}

func TestV3LoadBalanceRootStateRemainsBounded(t *testing.T) {
	e := largeDetailsFixture(t)
	set := e.setDefinitions["all"]
	set.SelectionMode = "loadBalance"
	e.setDefinitions["all"] = set
	snapshot := e.snapshot()
	raw, err := json.Marshal(snapshot)
	if err != nil || len(raw) >= 1<<20 {
		t.Fatalf("unbounded root %d: %v", len(raw), err)
	}
	for _, status := range snapshot.Policies {
		if status.SelectionMode != "loadBalance" || status.SelectedNodeID != "" || status.ActiveNodeCount != 5000 || len(status.ActiveNodeIDs) != 10 {
			t.Fatal("incomplete load-balance state", status.PolicyID, status.ActiveNodeCount, len(status.ActiveNodeIDs))
		}
	}
}

func TestV3NameSourceRegionAndOvernightScheduleFilters(t *testing.T) {
	jp, hk := "JP", "HK"
	set := LocalNodeSet{SourceIDs: []string{"a", "b"}, Regions: []string{"JP", "HK"}, NameIncludes: []string{"tokyo", "HK"}, NameExcludes: []string{"TEST"}, ExcludedSourceIDs: []string{"b"}, ExcludedRegions: []string{"HK"}}
	for _, tc := range []struct {
		node LocalPolicyNode
		want bool
	}{
		{LocalPolicyNode{SourceID: "a", Label: "TOKYO premium", Region: &jp}, true},
		{LocalPolicyNode{SourceID: "a", Label: "tokyo test", Region: &jp}, false},
		{LocalPolicyNode{SourceID: "b", Label: "tokyo", Region: &jp}, false},
		{LocalPolicyNode{SourceID: "a", Label: "HK premium", Region: &hk}, false},
		{LocalPolicyNode{SourceID: "a", Label: "Other", Region: &jp}, false},
	} {
		if set.includes(tc.node) != tc.want {
			t.Fatalf("filter %+v", tc.node)
		}
	}
	schedule := &LocalPolicySchedule{TimeZone: "UTC", Windows: []LocalPolicyScheduleWindow{{Weekdays: []int{1}, StartMinute: 22 * 60, EndMinute: 2 * 60}}}
	monday := time.Date(2026, 10, 12, 22, 0, 0, 0, time.UTC)
	for _, tc := range []struct {
		at   time.Time
		want bool
	}{{monday.Add(-time.Minute), false}, {monday, true}, {monday.Add(3 * time.Hour), true}, {monday.Add(4 * time.Hour), false}, {monday.Add(24 * time.Hour), false}} {
		if localPolicyScheduleActive(schedule, tc.at) != tc.want {
			t.Fatal(tc)
		}
	}
	schedule.Windows[0].EndMinute = 0
	if !validLocalSchedule(schedule) || !localPolicyScheduleActive(schedule, monday) || localPolicyScheduleActive(schedule, monday.Add(2*time.Hour)) {
		t.Fatal("midnight end boundary")
	}
	e := v3Fixture(t)
	group := e.setDefinitions["pool"]
	group.Schedule = schedule
	e.setDefinitions["pool"] = group
	e.now = func() time.Time { return monday.Add(time.Hour) }
	if (&localManagedAdapter{engine: e, policyID: "p"}).Type() != C.Selector {
		t.Fatal("active group skipped")
	}
	e.now = func() time.Time { return monday.Add(3 * time.Hour) }
	if (&localManagedAdapter{engine: e, policyID: "p"}).Type() != C.Pass {
		t.Fatal("inactive group captured traffic")
	}
}

func TestV3UnavailablePassesAndOriginalRuleReceivesConnection(t *testing.T) {
	e, cfg, leaves, _ := localFixture(t)
	yes := true
	e.config.SchemaVersion = 3
	e.policies["p"].definition.SkipUnavailable = &yes
	e.install(cfg)
	if cfg.Proxies["managed"].Type() != C.Pass {
		t.Fatal("unprobed rule did not pass")
	}
	oldRules, oldProxies, oldProviders, oldRuleProviders, oldMode, oldStatus := tunnel.Rules(), tunnel.Proxies(), tunnel.Providers(), tunnel.RuleProviders(), tunnel.Mode(), tunnel.Status()
	t.Cleanup(func() {
		tunnel.UpdateRules(oldRules, nil, oldRuleProviders)
		tunnel.UpdateProxies(oldProxies, oldProviders)
		tunnel.SetMode(oldMode)
		if oldStatus == tunnel.Running {
			tunnel.OnRunning()
		} else if oldStatus == tunnel.Inner {
			tunnel.OnInnerLoading()
		} else {
			tunnel.OnSuspend()
		}
	})
	first, _ := rules.ParseRule("MATCH", "", "managed", nil, nil)
	original, _ := rules.ParseRule("MATCH", "", "C3", nil, nil)
	tunnel.UpdateProxies(cfg.Proxies, nil)
	tunnel.UpdateRules([]C.Rule{first, original}, nil, nil)
	tunnel.SetMode(tunnel.Rule)
	tunnel.OnRunning()
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { _, _ = w.Write([]byte("ok")) }))
	defer server.Close()
	metadata := &C.Metadata{NetWork: C.TCP, Type: C.HTTP, SrcIP: netip.MustParseAddr("127.0.0.1"), SrcPort: 12345}
	if err := metadata.SetRemoteAddress(server.Listener.Addr().String()); err != nil {
		t.Fatal(err)
	}
	client, internal := net.Pipe()
	defer client.Close()
	_ = client.SetDeadline(time.Now().Add(3 * time.Second))
	done := make(chan struct{})
	go func() { tunnel.Tunnel.HandleTCPConn(internal, metadata); close(done) }()
	_, err := io.WriteString(client, "GET / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n")
	if err != nil {
		t.Fatal(err)
	}
	response, err := io.ReadAll(client)
	if err != nil {
		t.Fatal(err)
	}
	if len(response) == 0 || leaves["c3"].calls.Load() != 1 || leaves["a1"].calls.Load() != 0 {
		t.Fatalf("original rule not reached: response=%q calls=%d", response, leaves["c3"].calls.Load())
	}
	select {
	case <-done:
	case <-time.After(time.Second):
		t.Fatal("tunnel connection not cleaned up")
	}
}

func TestV3ExplicitActionsWithoutCandidates(t *testing.T) {
	e, cfg, leaves, _ := localFixture(t)
	r := e.policies["p"]
	r.definition.CandidateNodeIDs = nil
	r.definition.Choices = nil
	r.definition.Action = "reject"
	a := &localManagedAdapter{engine: e, policyID: "p", direct: cfg.Proxies["C3"]}
	if a.Type() != C.Reject {
		t.Fatal("reject action missing")
	}
	if conn, err := a.DialContext(context.Background(), &C.Metadata{}); err == nil {
		conn.Close()
		t.Fatal("reject dialed")
	}
	r.definition.Action = "direct"
	if a.Type() != C.Direct {
		t.Fatal("direct action missing")
	}
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {}))
	defer server.Close()
	m := &C.Metadata{NetWork: C.TCP}
	_ = m.SetRemoteAddress(server.Listener.Addr().String())
	conn, err := a.DialContext(context.Background(), m)
	if err != nil {
		t.Fatal(err)
	}
	_ = conn.Close()
	if leaves["c3"].calls.Load() != 1 {
		t.Fatal("direct action not executed")
	}
}

func TestV3RoundRobinConnectionsChargeActualSourcesAndDoNotAdvanceOnStatus(t *testing.T) {
	e := v3Fixture(t)
	set := e.setDefinitions["pool"]
	set.SelectionMode = "loadBalance"
	set.BalanceStrategy = "roundRobin"
	set.Preferences = []LocalNodePreference{{Type: "source", Direction: "ascending"}}
	e.setDefinitions["pool"] = set
	e.ledger.configure([]LocalPolicyBudget{{SourceID: "a", LimitBytes: 10000, ResetDay: 1, TimeZone: "UTC"}, {SourceID: "b", LimitBytes: 10000, ResetDay: 1, TimeZone: "UTC"}, {SourceID: "c", LimitBytes: 10000, ResetDay: 1, TimeZone: "UTC"}}, e.now())
	for _, node := range e.config.Nodes {
		proxy := e.proxies[node.ID].(*adapter.Proxy)
		proxy.ProxyAdapter = &localSourceAdapter{ProxyAdapter: proxy.ProxyAdapter, engine: e, node: node}
	}
	a := &localManagedAdapter{Base: outbound.NewBase(outbound.BaseOption{Name: "managed", Type: C.Selector, UDP: true}), engine: e, policyID: "p"}
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {}))
	defer server.Close()
	m := &C.Metadata{NetWork: C.TCP}
	_ = m.SetRemoteAddress(server.Listener.Addr().String())
	for i, want := range []string{"a1", "b2", "c3", "a1", "b2", "c3"} {
		_ = e.snapshot()
		_ = a.Type()
		_, _, _ = e.selectProxy("p")
		conn, err := a.DialContext(context.Background(), m)
		if err != nil {
			t.Fatal(err)
		}
		identity := conn.(interface{ LocalPolicyIdentity() LocalPolicyIdentity }).LocalPolicyIdentity()
		if identity.NodeID != want || identity.SourceID != e.nodes[want].SourceID {
			t.Fatalf("connection %d: %+v", i, identity)
		}
		if _, err = conn.Write([]byte("x")); err != nil {
			t.Fatal(err)
		}
		_ = conn.Close()
	}
	snapshot := e.snapshot().Policies[0]
	if snapshot.SelectedNodeID != "" || snapshot.SelectionMode != "loadBalance" || snapshot.ActiveNodeCount != 3 {
		t.Fatalf("misleading state %+v", snapshot)
	}
	udp, err := a.ListenPacketContext(context.Background(), m)
	if err != nil {
		t.Fatal(err)
	}
	identity := udp.(interface{ LocalPolicyIdentity() LocalPolicyIdentity }).LocalPolicyIdentity()
	if identity.NodeID != "a1" {
		t.Fatal(identity)
	}
	_, err = udp.WriteTo([]byte("udp"), &net.UDPAddr{IP: net.ParseIP("127.0.0.1"), Port: 9})
	if err != nil {
		t.Fatal(err)
	}
	_ = udp.Close()
	used := map[string]int64{}
	for _, row := range e.ledger.status(e.now()) {
		used[row.SourceID] = row.UsedBytes
	}
	if !reflect.DeepEqual(used, map[string]int64{"a": 5, "b": 2, "c": 2}) {
		t.Fatal("wrong or duplicated source accounting", used)
	}
}

func TestV3BalancedConcurrentAllocationAndHashAffinity(t *testing.T) {
	e := v3Fixture(t)
	set := e.setDefinitions["pool"]
	set.SelectionMode = "loadBalance"
	set.BalanceStrategy = "roundRobin"
	e.setDefinitions["pool"] = set
	counts := map[string]int{}
	var mu sync.Mutex
	var wg sync.WaitGroup
	for i := 0; i < 120; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			_, id, err := e.selectProxyForRequest("p", nil, true)
			mu.Lock()
			defer mu.Unlock()
			if err != nil {
				t.Error(err)
			}
			counts[id]++
		}()
	}
	wg.Wait()
	if !reflect.DeepEqual(counts, map[string]int{"a1": 40, "b2": 40, "c3": 40}) {
		t.Fatal(counts)
	}
	for _, strategy := range []string{"consistentHashing", "stickySessions"} {
		set.BalanceStrategy = strategy
		e.setDefinitions["pool"] = set
		m := &C.Metadata{Host: "api.example.com", SrcIP: netip.MustParseAddr("10.0.0.1")}
		_, first, _ := e.selectProxyForRequest("p", m, true)
		for i := 0; i < 10; i++ {
			_, id, _ := e.selectProxyForRequest("p", m, true)
			if id != first {
				t.Fatal("affinity changed")
			}
		}
		used := map[string]bool{}
		for i := 0; i < 120; i++ {
			m.Host = fmt.Sprintf("host%d.example%d.com", i, i)
			_, id, _ := e.selectProxyForRequest("p", m, true)
			used[id] = true
		}
		if len(used) < 2 {
			t.Fatal("hash did not distribute pool", strategy, used)
		}
	}
	e.sets["pool"].health["b2"].healthy = false
	for i := 0; i < 20; i++ {
		_, id, _ := e.selectProxyForRequest("p", nil, true)
		if id == "b2" {
			t.Fatal("unhealthy node allocated")
		}
	}
}

func TestV3CompilerExpressionsParseAndMatchInMihomo(t *testing.T) {
	directory := t.TempDir()
	data, err := proto.Marshal(&router.GeoIPList{Entry: []*router.GeoIP{
		{CountryCode: "CN", Cidr: []*router.CIDR{{Ip: []byte{10, 0, 0, 0}, Prefix: 8}}},
		{CountryCode: "US", Cidr: []*router.CIDR{{Ip: []byte{203, 0, 113, 0}, Prefix: 24}}},
	}})
	if err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(filepath.Join(directory, "GeoIP.dat"), data, 0600); err != nil {
		t.Fatal(err)
	}
	oldHome, oldMode, oldLoader, oldName := C.Path.HomeDir(), geodata.GeodataMode(), geodata.LoaderName(), C.GeoipName
	C.SetHomeDir(directory)
	geodata.SetGeodataMode(true)
	geodata.SetLoader("standard")
	geodata.ClearGeoIPCache()
	t.Cleanup(func() {
		geodata.ClearGeoIPCache()
		C.SetHomeDir(oldHome)
		geodata.SetGeodataMode(oldMode)
		geodata.SetLoader(oldLoader)
		C.GeoipName = oldName
	})
	const app = `^/Applications/Foo \x28Beta\x29\x2c Plus\.app/Contents/.*$`
	path := "/Applications/Foo (Beta), Plus.app/Contents/Frameworks/Helper.app/Contents/MacOS/Helper"
	metadata := func(ip, host, process string) *C.Metadata {
		return &C.Metadata{NetWork: C.TCP, DstIP: netip.MustParseAddr(ip), Host: host, ProcessPath: process}
	}
	cases := []struct {
		name, line string
		yes, no    *C.Metadata
	}{
		{"region", "GEOIP,CN,managed", metadata("10.1.2.3", "", ""), metadata("203.0.113.1", "", "")},
		{"region exclusion", "NOT,((GEOIP,CN)),managed", metadata("203.0.113.1", "", ""), metadata("10.1.2.3", "", "")},
		{"nested region domain", "AND,((GEOIP,CN),(OR,((DOMAIN-KEYWORD,video),(DOMAIN-KEYWORD,media)))),managed", metadata("10.1.2.3", "video.example", ""), metadata("203.0.113.1", "video.example", "")},
		{"application hex punctuation", "PROCESS-PATH-REGEX," + app + ",managed", metadata("10.1.2.3", "", path), metadata("10.1.2.3", "", "/Applications/FooX.app/Contents/MacOS/Foo")},
		{"logical application", "AND,((GEOIP,CN),(PROCESS-PATH-REGEX," + app + ")),managed", metadata("10.1.2.3", "", path), metadata("203.0.113.1", "", path)},
		{"multiple applications", `OR,((PROCESS-PATH-REGEX,` + app + `),(PROCESS-PATH-REGEX,^/Applications/其他\.app/Contents/.*$)),managed`, metadata("10.1.2.3", "", "/Applications/其他.app/Contents/MacOS/Main"), metadata("10.1.2.3", "", "/Applications/Unknown.app/Contents/MacOS/Main")},
		{"negative application", "AND,((IP-CIDR,10.0.0.0/8),(NOT,((PROCESS-PATH-REGEX," + app + ")))),managed", metadata("10.1.2.3", "", "/Applications/Other.app/Contents/MacOS/Main"), metadata("10.1.2.3", "", path)},
		{"ipv4 single address", "IP-CIDR,192.0.2.1/32,managed", metadata("192.0.2.1", "", ""), metadata("192.0.2.2", "", "")},
		{"ipv6 network", "IP-CIDR6,2001:db8::/32,managed", metadata("2001:db8::1", "", ""), metadata("2001:db9::1", "", "")},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			tp, payload, target, params := RC.ParseRulePayload(tc.line, true)
			rule, err := rules.ParseRule(tp, payload, target, params, nil)
			if err != nil {
				t.Fatal(tc.line, err)
			}
			if hit, adapter := rule.Match(tc.yes, C.RuleMatchHelper{}); !hit || adapter != "managed" {
				t.Fatalf("expected match: %s hit=%v adapter=%s", tc.line, hit, adapter)
			}
			if hit, _ := rule.Match(tc.no, C.RuleMatchHelper{}); hit {
				t.Fatalf("unexpected match: %s", tc.line)
			}
		})
	}
}

func TestV3EmptyFilteredSetPassesWithSourceMetadataRetained(t *testing.T) {
	e := v3Fixture(t)
	set := e.setDefinitions["pool"]
	set.NameIncludes = []string{"not-an-existing-node"}
	e.config.NodeSets[0] = set
	if err := validateLocalPolicyConfig(&e.config); err != nil {
		t.Fatal(err)
	}
	if err := e.prepareNodeSets(&e.config); err != nil {
		t.Fatal(err)
	}
	if len(e.sets["pool"].health) != 0 {
		t.Fatal("empty filtered set retained members")
	}
	a := &localManagedAdapter{engine: e, policyID: "p"}
	if a.Type() != C.Pass {
		t.Fatal("empty set did not pass matching traffic")
	}
	if status := e.snapshot().Policies[0]; status.State != "skipped" || status.SelectedNodeID != "" {
		t.Fatal(status)
	}
}
