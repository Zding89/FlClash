package main

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net"
	"sync"
	"sync/atomic"

	"github.com/metacubex/mihomo/adapter"
	"github.com/metacubex/mihomo/adapter/outbound"
	"github.com/metacubex/mihomo/common/buf"
	C "github.com/metacubex/mihomo/constant"
)

type LocalPolicyIdentity struct {
	SourceID string
	NodeID   string
	PolicyID string
	Revision int64
}
type localSourceAdapter struct {
	C.ProxyAdapter
	engine *localPolicyEngine
	node   LocalPolicyNode
}

func (a *localSourceAdapter) admission(ctx context.Context) error {
	a.engine.mu.Lock()
	defer a.engine.mu.Unlock()
	if a.engine.stopped {
		return errors.New("local policy stopped")
	}
	if source := a.engine.sources[a.node.SourceID]; (source.ExpiresAt != nil && *source.ExpiresAt > 0 && *source.ExpiresAt <= a.engine.now().UnixMilli()) || (source.RemainingBytes != nil && *source.RemainingBytes <= 0) {
		return errors.New("local source rejected: source_expired")
	}
	if reason := a.engine.ledger.reason(a.node.SourceID, a.engine.now(), localUnknownBehavior(ctx)); reason != "" {
		return errors.New("local source rejected: " + reason)
	}
	return nil
}
func (a *localSourceAdapter) DialContext(ctx context.Context, m *C.Metadata) (C.Conn, error) {
	if err := a.admission(ctx); err != nil {
		return nil, err
	}
	conn, err := a.ProxyAdapter.DialContext(ctx, m)
	if err != nil {
		return nil, err
	}
	if err = a.admission(ctx); err != nil {
		_ = conn.Close()
		return nil, err
	}
	wrapped := &localPolicyConn{Conn: conn, engine: a.engine, identity: LocalPolicyIdentity{SourceID: a.node.SourceID, NodeID: a.node.ID, Revision: a.engine.config.Revision}, account: true}
	wrapped.registration, err = a.engine.register("", a.node.ID, wrapped)
	if err != nil {
		_ = conn.Close()
		return nil, err
	}
	return wrapped, nil
}
func (a *localSourceAdapter) ListenPacketContext(ctx context.Context, m *C.Metadata) (C.PacketConn, error) {
	if err := a.admission(ctx); err != nil {
		return nil, err
	}
	conn, err := a.ProxyAdapter.ListenPacketContext(ctx, m)
	if err != nil {
		return nil, err
	}
	if err = a.admission(ctx); err != nil {
		_ = conn.Close()
		return nil, err
	}
	wrapped := &localPolicyPacketConn{PacketConn: conn, engine: a.engine, identity: LocalPolicyIdentity{SourceID: a.node.SourceID, NodeID: a.node.ID, Revision: a.engine.config.Revision}, account: true}
	wrapped.registration, err = a.engine.register("", a.node.ID, wrapped)
	if err != nil {
		_ = conn.Close()
		return nil, err
	}
	return wrapped, nil
}

type localManagedAdapter struct {
	*outbound.Base
	engine   *localPolicyEngine
	policyID string
	direct   C.Proxy
}

func (a *localManagedAdapter) SupportUDP() bool {
	proxy, _, err := a.engine.selectProxyForRequest(a.policyID, &C.Metadata{NetWork: C.UDP}, false)
	if err != nil {
		a.engine.mu.Lock()
		defer a.engine.mu.Unlock()
		r := a.engine.policies[a.policyID]
		return r != nil && localPolicyAction(r.definition) == "reject"
	}
	if proxy == nil {
		proxy = a.direct
	}
	return proxy != nil && proxy.SupportUDP()
}

func (a *localManagedAdapter) Unwrap(metadata *C.Metadata, touch bool) C.Proxy {
	if metadata == nil || metadata.NetWork != C.UDP {
		return nil
	}
	_, _, err := a.engine.selectProxyForRequest(a.policyID, metadata, false)
	if err == nil {
		return nil
	}
	a.engine.mu.Lock()
	defer a.engine.mu.Unlock()
	r := a.engine.policies[a.policyID]
	if r != nil && localPolicyAction(r.definition) == "proxy" && localPolicySkipsUnavailable(a.engine.config, r.definition) {
		return adapter.NewProxy(outbound.NewBase(outbound.BaseOption{Name: "PASS", Type: C.Pass, UDP: true}))
	}
	return nil
}

func (a *localManagedAdapter) Type() C.AdapterType {
	a.engine.mu.Lock()
	defer a.engine.mu.Unlock()
	r := a.engine.policies[a.policyID]
	if r != nil && !localPolicyScheduleActive(r.definition.Schedule, a.engine.now()) {
		return C.Pass
	}
	if r != nil {
		switch localPolicyAction(r.definition) {
		case "direct":
			return C.Direct
		case "reject":
			return C.Reject
		}
		if localPolicySkipsUnavailable(a.engine.config, r.definition) {
			defer a.engine.beginSelectionRoundLocked()()
			a.engine.evaluateLocked(r, a.engine.now())
			if r.selected == "" {
				return C.Pass
			}
		}
	}
	return C.Selector
}

func (a *localManagedAdapter) DialContext(ctx context.Context, m *C.Metadata) (C.Conn, error) {
	proxy, id, err := a.engine.selectProxyForRequest(a.policyID, m, true)
	if err != nil {
		return nil, err
	}
	if proxy == nil {
		if a.direct == nil {
			return nil, errors.New("local policy direct fallback unavailable")
		}
		return a.direct.DialContext(ctx, m)
	}
	ctx = context.WithValue(ctx, localPolicyAdmissionKey{}, a.engine.policies[a.policyID].definition.Guard.UnknownBehavior)
	conn, err := proxy.DialContext(ctx, m)
	if err != nil {
		return nil, err
	}
	conn.AppendToChains(a)
	n := a.engine.nodes[id]
	wrapped := &localPolicyConn{Conn: conn, engine: a.engine, identity: LocalPolicyIdentity{SourceID: n.SourceID, NodeID: n.ID, PolicyID: a.policyID, Revision: a.engine.config.Revision}}
	wrapped.registration, err = a.engine.register(a.policyID, id, wrapped)
	if err != nil {
		_ = conn.Close()
		return nil, err
	}
	return wrapped, nil
}
func (a *localManagedAdapter) ListenPacketContext(ctx context.Context, m *C.Metadata) (C.PacketConn, error) {
	metadata := C.Metadata{}
	if m != nil {
		metadata = *m
	}
	metadata.NetWork = C.UDP
	m = &metadata
	proxy, id, err := a.engine.selectProxyForRequest(a.policyID, &metadata, true)
	if err != nil {
		return nil, err
	}
	if proxy == nil {
		if a.direct == nil {
			return nil, errors.New("local policy direct fallback unavailable")
		}
		return a.direct.ListenPacketContext(ctx, m)
	}
	ctx = context.WithValue(ctx, localPolicyAdmissionKey{}, a.engine.policies[a.policyID].definition.Guard.UnknownBehavior)
	conn, err := proxy.ListenPacketContext(ctx, m)
	if err != nil {
		return nil, err
	}
	conn.AppendToChains(a)
	n := a.engine.nodes[id]
	wrapped := &localPolicyPacketConn{PacketConn: conn, engine: a.engine, identity: LocalPolicyIdentity{SourceID: n.SourceID, NodeID: n.ID, PolicyID: a.policyID, Revision: a.engine.config.Revision}}
	wrapped.registration, err = a.engine.register(a.policyID, id, wrapped)
	if err != nil {
		_ = conn.Close()
		return nil, err
	}
	return wrapped, nil
}
func (a *localManagedAdapter) IsL3Protocol(metadata *C.Metadata) bool {
	proxy, _, err := a.engine.selectProxyForRequest(a.policyID, metadata, false)
	if err != nil {
		return false
	}
	if proxy == nil {
		proxy = a.direct
	}
	return proxy != nil && proxy.IsL3Protocol(metadata)
}
func (a *localManagedAdapter) SupportUOT() bool {
	proxy, _, err := a.engine.selectProxy(a.policyID)
	if err != nil {
		return false
	}
	if proxy == nil {
		proxy = a.direct
	}
	return proxy != nil && proxy.SupportUOT()
}
func (a *localManagedAdapter) MarshalJSON() ([]byte, error) {
	typeName := "Selector"
	if a.Type() == C.Pass {
		return json.Marshal(map[string]any{"type": "Pass", "now": "PASS", "all": []string{}, "localPolicyId": a.policyID})
	}
	proxy, _, err := a.engine.selectProxy(a.policyID)
	now := "REJECT"
	if err == nil {
		if proxy == nil {
			now = "DIRECT"
			typeName = "Direct"
		} else {
			now = proxy.Name()
		}
	}
	all := []string{}
	for _, id := range a.engine.policies[a.policyID].definition.CandidateNodeIDs {
		all = append(all, a.engine.nodes[id].ProxyName)
	}
	a.engine.mu.Lock()
	r := a.engine.policies[a.policyID]
	if localPolicyAction(r.definition) == "reject" {
		typeName = "Reject"
	}
	if r.selectionMode == "loadBalance" {
		typeName = "LoadBalance"
		now = ""
	}
	a.engine.mu.Unlock()
	return json.Marshal(map[string]any{"type": typeName, "now": now, "all": all, "localPolicyId": a.policyID})
}

type localPolicyConn struct {
	C.Conn
	engine       *localPolicyEngine
	identity     LocalPolicyIdentity
	registration uint64
	account      bool
	closed       atomic.Bool
	closeOnce    sync.Once
	closeErr     error
}

func (c *localPolicyConn) LocalPolicyIdentity() LocalPolicyIdentity { return c.identity }
func (c *localPolicyConn) Upstream() any                            { return c.Conn }
func (c *localPolicyConn) ReaderReplaceable() bool                  { return false }
func (c *localPolicyConn) WriterReplaceable() bool                  { return false }
func (c *localPolicyConn) count(n int) {
	if c.account {
		c.engine.ledger.count(c.identity.SourceID, int64(n), c.engine.now())
	}
}
func (c *localPolicyConn) Read(b []byte) (int, error) {
	if c.closed.Load() {
		return 0, io.ErrClosedPipe
	}
	if c.account {
		c.engine.ledger.activeIO.Add(1)
		defer c.engine.ledger.activeIO.Add(-1)
		if c.closed.Load() {
			return 0, io.ErrClosedPipe
		}
	}
	n, err := c.Conn.Read(b)
	c.count(n)
	return n, err
}
func (c *localPolicyConn) Write(b []byte) (int, error) {
	if c.closed.Load() {
		return 0, io.ErrClosedPipe
	}
	if c.account {
		c.engine.ledger.activeIO.Add(1)
		defer c.engine.ledger.activeIO.Add(-1)
		if c.closed.Load() {
			return 0, io.ErrClosedPipe
		}
	}
	n, err := c.Conn.Write(b)
	c.count(n)
	return n, err
}
func (c *localPolicyConn) ReadBuffer(buffer *buf.Buffer) error {
	if c.closed.Load() {
		return io.ErrClosedPipe
	}
	if c.account {
		c.engine.ledger.activeIO.Add(1)
		defer c.engine.ledger.activeIO.Add(-1)
		if c.closed.Load() {
			return io.ErrClosedPipe
		}
	}
	before := buffer.Len()
	err := c.Conn.ReadBuffer(buffer)
	c.count(buffer.Len() - before)
	return err
}
func (c *localPolicyConn) WriteBuffer(buffer *buf.Buffer) error {
	defer buffer.Release()
	if c.closed.Load() {
		return io.ErrClosedPipe
	}
	if c.account {
		c.engine.ledger.activeIO.Add(1)
		defer c.engine.ledger.activeIO.Add(-1)
		if c.closed.Load() {
			return io.ErrClosedPipe
		}
	}
	data := buffer.Bytes()
	for len(data) > 0 {
		n, err := c.Conn.Write(data)
		c.count(n)
		if err != nil {
			return err
		}
		if n <= 0 {
			return io.ErrNoProgress
		}
		data = data[n:]
	}
	return nil
}

func (c *localPolicyConn) Close() error {
	c.closed.Store(true)
	c.closeOnce.Do(func() {
		c.closeErr = c.Conn.Close()
		if c.closeErr == nil {
			c.engine.unregister(c.registration)
		}
	})
	return c.closeErr
}

type localPolicyPacketConn struct {
	C.PacketConn
	engine       *localPolicyEngine
	identity     LocalPolicyIdentity
	registration uint64
	account      bool
	closed       atomic.Bool
	closeOnce    sync.Once
	closeErr     error
}

func (c *localPolicyPacketConn) LocalPolicyIdentity() LocalPolicyIdentity { return c.identity }
func (c *localPolicyPacketConn) Upstream() any                            { return c.PacketConn }
func (c *localPolicyPacketConn) ReaderReplaceable() bool                  { return false }
func (c *localPolicyPacketConn) WriterReplaceable() bool                  { return false }
func (c *localPolicyPacketConn) count(n int) {
	if c.account {
		c.engine.ledger.count(c.identity.SourceID, int64(n), c.engine.now())
	}
}
func (c *localPolicyPacketConn) ReadFrom(b []byte) (int, net.Addr, error) {
	if c.closed.Load() {
		return 0, nil, io.ErrClosedPipe
	}
	if c.account {
		c.engine.ledger.activeIO.Add(1)
		defer c.engine.ledger.activeIO.Add(-1)
		if c.closed.Load() {
			return 0, nil, io.ErrClosedPipe
		}
	}
	n, addr, err := c.PacketConn.ReadFrom(b)
	c.count(n)
	return n, addr, err
}
func (c *localPolicyPacketConn) WaitReadFrom() ([]byte, func(), net.Addr, error) {
	if c.closed.Load() {
		return nil, nil, nil, io.ErrClosedPipe
	}
	if c.account {
		c.engine.ledger.activeIO.Add(1)
		defer c.engine.ledger.activeIO.Add(-1)
		if c.closed.Load() {
			return nil, nil, nil, io.ErrClosedPipe
		}
	}
	data, put, addr, err := c.PacketConn.WaitReadFrom()
	c.count(len(data))
	return data, put, addr, err
}
func (c *localPolicyPacketConn) WriteTo(b []byte, addr net.Addr) (int, error) {
	if c.closed.Load() {
		return 0, io.ErrClosedPipe
	}
	if c.account {
		c.engine.ledger.activeIO.Add(1)
		defer c.engine.ledger.activeIO.Add(-1)
		if c.closed.Load() {
			return 0, io.ErrClosedPipe
		}
	}
	n, err := c.PacketConn.WriteTo(b, addr)
	c.count(n)
	return n, err
}
func (c *localPolicyPacketConn) Close() error {
	c.closed.Store(true)
	c.closeOnce.Do(func() {
		c.closeErr = c.PacketConn.Close()
		if c.closeErr == nil {
			c.engine.unregister(c.registration)
		}
	})
	return c.closeErr
}
