package main

import (
	"context"
	"fmt"
	"net"
	"net/http"
	"net/http/httptest"
	"net/netip"
	"reflect"
	"testing"
	"time"

	"github.com/metacubex/mihomo/adapter"
	"github.com/metacubex/mihomo/adapter/outbound"
	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/rules"
	"github.com/metacubex/mihomo/tunnel"
	"github.com/metacubex/mihomo/tunnel/statistic"
)

func localSetUDP(t *testing.T, e *localPolicyEngine, id string, enabled bool) *localTestLeaf {
	t.Helper()
	leaf := e.proxies[id].(*adapter.Proxy).ProxyAdapter.(*localTestLeaf)
	leaf.Base = outbound.NewBase(outbound.BaseOption{Name: leaf.Name(), Type: C.Shadowsocks, UDP: enabled})
	return leaf
}

func TestPolicyUDPQualifiedPriorityAndAllBalanceStrategies(t *testing.T) {
	for _, mode := range []string{"priority", "roundRobin", "consistentHashing", "stickySessions"} {
		t.Run(mode, func(t *testing.T) {
			e := v3Fixture(t)
			localSetUDP(t, e, "a1", false)
			set := e.setDefinitions["pool"]
			set.Preferences = []LocalNodePreference{{Type: "source", Direction: "ascending"}}
			if mode != "priority" {
				set.SelectionMode, set.BalanceStrategy = "loadBalance", mode
			}
			e.setDefinitions["pool"] = set
			a := &localManagedAdapter{Base: outbound.NewBase(outbound.BaseOption{Name: "managed", Type: C.Selector, UDP: true}), engine: e, policyID: "p"}
			seen := map[string]bool{}
			for i := 0; i < 64; i++ {
				m := &C.Metadata{NetWork: C.UDP, Host: fmt.Sprintf("destination%d.example", i), SrcIP: netip.MustParseAddr("127.0.0.1")}
				if a.Unwrap(m, false) != nil || !a.SupportUDP() {
					t.Fatal("eligible UDP rule was skipped")
				}
				_, preview, err := e.selectProxyForRequest("p", m, false)
				if err != nil {
					t.Fatal(err)
				}
				proxy, id, err := e.selectProxyForRequest("p", m, true)
				if err != nil || id == "a1" || !proxy.SupportUDP() || id != preview {
					t.Fatalf("preview=%s allocated=%s err=%v", preview, id, err)
				}
				seen[id] = true
			}
			if mode == "priority" && !reflect.DeepEqual(seen, map[string]bool{"b2": true}) || mode != "priority" && len(seen) != 2 {
				t.Fatalf("qualified pool=%v", seen)
			}
			_, tcp, err := e.selectProxyForRequest("p", &C.Metadata{NetWork: C.TCP}, true)
			if err != nil || mode == "priority" && tcp != "a1" {
				t.Fatalf("TCP selection changed: %s %v", tcp, err)
			}
		})
	}
}

func TestPolicyUDPOverrideRequiresProtocolMembershipAndGuard(t *testing.T) {
	for _, disqualify := range []string{"protocol", "membership", "health", "guard"} {
		t.Run(disqualify, func(t *testing.T) {
			e := v3Fixture(t)
			set := e.setDefinitions["pool"]
			set.SelectionMode, set.BalanceStrategy = "loadBalance", "roundRobin"
			set.Preferences = []LocalNodePreference{{Type: "source", Direction: "ascending"}}
			e.setDefinitions["pool"] = set
			switch disqualify {
			case "protocol":
				localSetUDP(t, e, "a1", false)
			case "membership":
				set.ExcludedSourceIDs = []string{"a"}
				e.setDefinitions["pool"] = set
			case "health":
				e.sets["pool"].health["a1"].healthy = false
			case "guard":
				zero := int64(0)
				e.sources["a"] = LocalPolicySource{ID: "a", RemainingBytes: &zero}
			}
			e.config.Overrides = []LocalPolicyOverride{{PolicyID: "p", NodeSetID: "pool", NodeID: "a1", ExpiresAt: e.now().Add(time.Minute).UnixMilli()}}
			for i := 0; i < 6; i++ {
				_, id, err := e.selectProxyForRequest("p", &C.Metadata{NetWork: C.UDP}, true)
				if err != nil || id == "a1" {
					t.Fatalf("override bypassed %s: %s %v", disqualify, id, err)
				}
			}
			if disqualify == "protocol" {
				_, id, err := e.selectProxyForRequest("p", &C.Metadata{NetWork: C.TCP}, true)
				if err != nil || id != "a1" {
					t.Fatalf("TCP override lost: %s %v", id, err)
				}
			}
		})
	}
}

func TestPolicyUDPQualifiedOrderedChoicesAndFixedCandidates(t *testing.T) {
	for _, choices := range []bool{false, true} {
		t.Run(fmt.Sprint(choices), func(t *testing.T) {
			e, _, _, now := localFixture(t)
			healthyLocalNodes(e)
			localSetUDP(t, e, "a1", false)
			if choices {
				e.policies["p"].definition.Choices = []LocalPolicyChoice{{Type: "node", ID: "a1"}, {Type: "node", ID: "b2"}}
			}
			e.config.Overrides = []LocalPolicyOverride{{PolicyID: "p", NodeID: "a1", ExpiresAt: now.Add(time.Minute).UnixMilli()}}
			_, id, err := e.selectProxyForRequest("p", &C.Metadata{NetWork: C.UDP}, true)
			if err != nil || id != "b2" {
				t.Fatalf("UDP fixed candidate=%s %v", id, err)
			}
			expectLocalNode(t, e, "a1")
		})
	}
}

func TestPolicyUDPRealConnectionsUseQualifiedLeafAndActualAccounting(t *testing.T) {
	for _, mode := range []string{"priority", "roundRobin", "consistentHashing", "stickySessions"} {
		t.Run(mode, func(t *testing.T) { testPolicyUDPRealConnections(t, mode) })
	}
}

func testPolicyUDPRealConnections(t *testing.T, mode string) {
	t.Helper()
	e := v3Fixture(t)
	tcpOnly := localSetUDP(t, e, "a1", false)
	udpLeaf := localSetUDP(t, e, "b2", true)
	set := e.setDefinitions["pool"]
	set.SourceIDs = []string{"a", "b"}
	set.Preferences = []LocalNodePreference{{Type: "source", Direction: "ascending"}}
	if mode != "priority" {
		set.SelectionMode, set.BalanceStrategy = "loadBalance", mode
	}
	e.setDefinitions["pool"] = set
	e.config.Overrides = []LocalPolicyOverride{{PolicyID: "p", NodeSetID: "pool", NodeID: "a1", ExpiresAt: e.now().Add(time.Minute).UnixMilli()}}
	e.ledger.configure([]LocalPolicyBudget{{SourceID: "a", LimitBytes: 10000, ResetDay: 1, TimeZone: "UTC"}, {SourceID: "b", LimitBytes: 10000, ResetDay: 1, TimeZone: "UTC"}}, e.now())
	for _, node := range e.config.Nodes {
		proxy := e.proxies[node.ID].(*adapter.Proxy)
		proxy.ProxyAdapter = &localSourceAdapter{ProxyAdapter: proxy.ProxyAdapter, engine: e, node: node}
	}
	a := &localManagedAdapter{Base: outbound.NewBase(outbound.BaseOption{Name: "managed", Type: C.Selector, UDP: true}), engine: e, policyID: "p"}
	server := httptest.NewServer(http.HandlerFunc(func(http.ResponseWriter, *http.Request) {}))
	defer server.Close()
	m := &C.Metadata{NetWork: C.TCP}
	_ = m.SetRemoteAddress(server.Listener.Addr().String())
	conn, err := a.DialContext(context.Background(), m)
	if err != nil {
		t.Fatal(err)
	}
	defer conn.Close()
	if _, err = conn.Write([]byte("tcp")); err != nil {
		t.Fatal(err)
	}
	identity := conn.(interface{ LocalPolicyIdentity() LocalPolicyIdentity }).LocalPolicyIdentity()
	if identity.NodeID != "a1" || tcpOnly.calls.Load() != 1 {
		t.Fatalf("TCP identity=%+v calls=%d", identity, tcpOnly.calls.Load())
	}
	udp, err := net.ListenPacket("udp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer udp.Close()
	go func() {
		buffer := make([]byte, 64)
		n, addr, readErr := udp.ReadFrom(buffer)
		if readErr == nil {
			_, _ = udp.WriteTo(buffer[:n], addr)
		}
	}()
	packet, err := a.ListenPacketContext(context.Background(), &C.Metadata{NetWork: C.UDP})
	if err != nil {
		t.Fatal(err)
	}
	defer packet.Close()
	_ = packet.SetDeadline(time.Now().Add(3 * time.Second))
	if _, err = packet.WriteTo([]byte("udp"), udp.LocalAddr()); err != nil {
		t.Fatal(err)
	}
	buffer := make([]byte, 64)
	n, _, err := packet.ReadFrom(buffer)
	identity = packet.(interface{ LocalPolicyIdentity() LocalPolicyIdentity }).LocalPolicyIdentity()
	if err != nil || string(buffer[:n]) != "udp" || identity.NodeID != "b2" || tcpOnly.packets.Load() != 0 || udpLeaf.packets.Load() != 1 {
		t.Fatalf("UDP reply=%q identity=%+v err=%v", buffer[:n], identity, err)
	}
	used := map[string]int64{}
	for _, row := range e.ledger.status(e.now()) {
		used[row.SourceID] = row.UsedBytes
	}
	if !reflect.DeepEqual(used, map[string]int64{"a": 3, "b": 6}) {
		t.Fatalf("wrong source or duplicated accounting: %v", used)
	}
}

type localPolicyUDPPacket struct {
	payload []byte
	addr    net.Addr
	reply   chan []byte
}

func (p *localPolicyUDPPacket) Data() []byte        { return p.payload }
func (p *localPolicyUDPPacket) Drop()               {}
func (p *localPolicyUDPPacket) LocalAddr() net.Addr { return p.addr }
func (p *localPolicyUDPPacket) WriteBack(data []byte, _ net.Addr) (int, error) {
	p.reply <- append([]byte(nil), data...)
	return len(data), nil
}

func TestPolicyUDPAllTCPOnlyFallsThroughOriginalTunnelRule(t *testing.T) {
	e, cfg, leaves, _ := localFixture(t)
	healthyLocalNodes(e)
	e.config.SchemaVersion = 3
	localSetUDP(t, e, "a1", false)
	localSetUDP(t, e, "b2", false)
	e.install(cfg)
	managed := cfg.Proxies["managed"]
	if managed.Type() != C.Selector || managed.SupportUDP() || managed.Unwrap(&C.Metadata{NetWork: C.TCP}, false) != nil {
		t.Fatal("protocol-specific availability leaked into TCP")
	}
	pass := managed.Unwrap(&C.Metadata{NetWork: C.UDP}, false)
	if pass == nil || pass.Type() != C.Pass {
		t.Fatal("UDP-empty policy did not expose pass")
	}
	if packet, err := managed.ListenPacketContext(context.Background(), &C.Metadata{NetWork: C.UDP}); err == nil {
		_ = packet.Close()
		t.Fatal("UDP-empty policy allocated an unsupported or unauthorized member")
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
	last, _ := rules.ParseRule("MATCH", "", "C3", nil, nil)
	tunnel.UpdateProxies(cfg.Proxies, nil)
	tunnel.UpdateRules([]C.Rule{first, last}, nil, nil)
	tunnel.SetMode(tunnel.Rule)
	tunnel.OnRunning()
	server, err := net.ListenPacket("udp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer server.Close()
	go func() {
		buffer := make([]byte, 64)
		n, addr, readErr := server.ReadFrom(buffer)
		if readErr == nil {
			_, _ = server.WriteTo(buffer[:n], addr)
		}
	}()
	source, err := net.ListenPacket("udp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer source.Close()
	sourcePort := uint16(source.LocalAddr().(*net.UDPAddr).Port)
	t.Cleanup(func() {
		statistic.DefaultManager.Range(func(tracker statistic.Tracker) bool {
			if tracker.Info().Metadata.NetWork == C.UDP && tracker.Info().Metadata.SrcPort == sourcePort {
				_ = tracker.Close()
			}
			return true
		})
	})
	m := &C.Metadata{NetWork: C.UDP, Type: C.SOCKS5, SrcIP: netip.MustParseAddr("127.0.0.1"), SrcPort: sourcePort}
	if err = m.SetRemoteAddress(server.LocalAddr().String()); err != nil {
		t.Fatal(err)
	}
	packet := &localPolicyUDPPacket{payload: []byte("fallthrough"), addr: source.LocalAddr(), reply: make(chan []byte, 1)}
	tunnel.Tunnel.HandleUDPPacket(packet, m)
	select {
	case reply := <-packet.reply:
		if string(reply) != "fallthrough" || leaves["a1"].packets.Load() != 0 || leaves["b2"].packets.Load() != 0 || leaves["c3"].packets.Load() != 1 {
			t.Fatalf("reply=%q calls=%d/%d/%d", reply, leaves["a1"].packets.Load(), leaves["b2"].packets.Load(), leaves["c3"].packets.Load())
		}
	case <-time.After(3 * time.Second):
		t.Fatal("original rule did not receive UDP packet")
	}
}

func TestPolicyUDPReloadPreservesStableChoice(t *testing.T) {
	old, cfg, _ := reloadManualFixture(t)
	old.sets["manual"].health["a1"].healthy = false
	_, id, err := old.selectProxyForRequest("p", &C.Metadata{NetWork: C.UDP}, true)
	if err != nil || id != "b2" {
		t.Fatalf("initial UDP selection=%s %v", id, err)
	}
	old.sets["manual"].health["a1"].healthy = true
	next := reloadLocalFixture(t, old, cfg, nil, localReloadProxies)
	_, id, err = next.selectProxyForRequest("p", &C.Metadata{NetWork: C.UDP}, true)
	if err != nil || id != "b2" || next.policies["p"].udpSelection.switched != old.policies["p"].udpSelection.switched {
		t.Fatalf("reload reset stable UDP selection=%s %v", id, err)
	}
}

func TestPolicyUDPRecoveryAdvancesDuringNormalEngineTick(t *testing.T) {
	e, _, _, now := localFixture(t)
	healthyLocalNodes(e)
	r := e.policies["p"]
	r.definition.Choices = []LocalPolicyChoice{{Type: "node", ID: "a1"}, {Type: "node", ID: "b2"}}
	selectNode := func(want string) {
		t.Helper()
		_, id, err := e.selectProxyForRequest("p", &C.Metadata{NetWork: C.UDP}, true)
		if err != nil || id != want {
			t.Fatalf("UDP selected=%s want=%s err=%v", id, want, err)
		}
	}
	selectNode("a1")
	r.health["a1"].healthy = false
	selectNode("b2")
	*now = now.Add(61 * time.Second)
	r.health["a1"].healthy = true
	e.tick()
	*now = now.Add(299 * time.Second)
	selectNode("b2")
	*now = now.Add(time.Second)
	selectNode("a1")
}
