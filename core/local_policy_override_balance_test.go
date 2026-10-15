package main

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/metacubex/mihomo/adapter/outbound"
	C "github.com/metacubex/mihomo/constant"
)

func TestBalancedOverridePinsTCPUDPAndStatusUntilExpiry(t *testing.T) {
	e := v3Fixture(t)
	now := e.now()
	e.now = func() time.Time { return now }
	set := e.setDefinitions["pool"]
	set.SelectionMode = "loadBalance"
	set.BalanceStrategy = "roundRobin"
	e.setDefinitions["pool"] = set
	e.config.Overrides = []LocalPolicyOverride{{PolicyID: "p", NodeSetID: "pool", NodeID: "b2", ExpiresAt: now.Add(time.Second).UnixMilli()}}
	a := &localManagedAdapter{Base: outbound.NewBase(outbound.BaseOption{Name: "managed", Type: C.Selector, UDP: true}), engine: e, policyID: "p"}
	server := httptest.NewServer(http.HandlerFunc(func(http.ResponseWriter, *http.Request) {}))
	defer server.Close()
	m := &C.Metadata{NetWork: C.TCP}
	_ = m.SetRemoteAddress(server.Listener.Addr().String())
	for i := 0; i < 6; i++ {
		status := e.snapshot().Policies[0]
		if status.SelectedNodeID != "b2" || status.Reason != "manual_override" || status.SelectionMode != "priority" || status.ActiveNodeCount != 1 {
			t.Fatalf("override status: %+v", status)
		}
		conn, err := a.DialContext(context.Background(), m)
		if err != nil {
			t.Fatal(err)
		}
		identity := conn.(interface{ LocalPolicyIdentity() LocalPolicyIdentity }).LocalPolicyIdentity()
		_ = conn.Close()
		if identity.NodeID != "b2" {
			t.Fatalf("TCP allocated %+v", identity)
		}
		udp, err := a.ListenPacketContext(context.Background(), &C.Metadata{NetWork: C.UDP})
		if err != nil {
			t.Fatal(err)
		}
		identity = udp.(interface{ LocalPolicyIdentity() LocalPolicyIdentity }).LocalPolicyIdentity()
		_ = udp.Close()
		if identity.NodeID != "b2" {
			t.Fatalf("UDP allocated %+v", identity)
		}
	}
	now = now.Add(time.Second)
	seen := map[string]bool{}
	for i := 0; i < 3; i++ {
		_, id, err := e.selectProxyForRequest("p", m, true)
		if err != nil {
			t.Fatal(err)
		}
		seen[id] = true
	}
	status := e.snapshot().Policies[0]
	if len(seen) != 3 || status.SelectionMode != "loadBalance" || status.Reason == "manual_override" || status.SelectedNodeID != "" {
		t.Fatalf("balance did not resume: %v, %+v", seen, status)
	}
}

func TestBalancedOverrideStillRequiresHealthAndMembership(t *testing.T) {
	for _, reason := range []string{"unhealthy", "excluded"} {
		t.Run(reason, func(t *testing.T) {
			e := v3Fixture(t)
			set := e.setDefinitions["pool"]
			set.SelectionMode = "loadBalance"
			set.BalanceStrategy = "roundRobin"
			if reason == "unhealthy" {
				e.sets["pool"].health["b2"].healthy = false
			} else {
				set.ExcludedSourceIDs = []string{"b"}
			}
			e.setDefinitions["pool"] = set
			e.config.Overrides = []LocalPolicyOverride{{PolicyID: "p", NodeSetID: "pool", NodeID: "b2", ExpiresAt: e.now().Add(time.Minute).UnixMilli()}}
			for i := 0; i < 6; i++ {
				_, id, err := e.selectProxyForRequest("p", nil, true)
				if err != nil || id == "b2" {
					t.Fatalf("ineligible override allocated %s: %v", id, err)
				}
			}
			if status := e.snapshot().Policies[0]; status.Reason == "manual_override" || status.SelectionMode != "loadBalance" {
				t.Fatalf("ineligible override status %+v", status)
			}
		})
	}
}
