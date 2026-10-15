package main

import (
	"bufio"
	"context"
	"encoding/json"
	"net"
	"net/netip"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
	"time"

	"github.com/metacubex/mihomo/adapter"
	"github.com/metacubex/mihomo/adapter/outbound"
	C "github.com/metacubex/mihomo/constant"
)

func localSocksLab(t *testing.T) int {
	t.Helper()
	node, err := exec.LookPath("node")
	if err != nil {
		t.Skip("Node.js is required for the real SOCKS5 lab regression")
	}
	command := exec.Command(node, filepath.Join("..", "scripts", "agent_traffic_lab.mjs"), "serve", "--ephemeral")
	command.Stderr = os.Stderr
	stdout, err := command.StdoutPipe()
	if err != nil {
		t.Fatal(err)
	}
	if err = command.Start(); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		_ = command.Process.Signal(os.Interrupt)
		done := make(chan error, 1)
		go func() { done <- command.Wait() }()
		select {
		case <-done:
		case <-time.After(3 * time.Second):
			_ = command.Process.Kill()
			<-done
		}
	})
	ready := make(chan []byte, 1)
	go func() {
		scanner := bufio.NewScanner(stdout)
		if scanner.Scan() {
			ready <- append([]byte(nil), scanner.Bytes()...)
		} else {
			ready <- nil
		}
	}()
	select {
	case data := <-ready:
		var result struct {
			Ready bool `json:"ready"`
			Ports struct {
				MZ int `json:"mz"`
			} `json:"ports"`
		}
		if err = json.Unmarshal(data, &result); err != nil || !result.Ready || result.Ports.MZ == 0 {
			t.Fatalf("SOCKS lab startup failed: %q %v", data, err)
		}
		return result.Ports.MZ
	case <-time.After(5 * time.Second):
		t.Fatal("SOCKS lab startup timed out")
		return 0
	}
}

func TestPolicyUDPRealSocksLeafIPv4AndIPv6Reply(t *testing.T) {
	port := localSocksLab(t)
	for _, destination := range []string{"198.51.100.20", "2001:db8::42"} {
		t.Run(destination, func(t *testing.T) {
			e, cfg, leaves, _ := localFixture(t)
			healthyLocalNodes(e)
			localSetUDP(t, e, "a1", false)
			leaf, err := outbound.NewSocks5(outbound.Socks5Option{Name: "B2", Server: "127.0.0.1", Port: port, UserName: "mz-us-udp", Password: "acceptance-only", UDP: true})
			if err != nil {
				t.Fatal(err)
			}
			proxy := adapter.NewProxy(leaf)
			cfg.Proxies["B2"], e.proxies["b2"] = proxy, proxy
			e.ledger.configure([]LocalPolicyBudget{{SourceID: "a", LimitBytes: 10000, ResetDay: 1, TimeZone: "UTC"}, {SourceID: "b", LimitBytes: 10000, ResetDay: 1, TimeZone: "UTC"}}, e.now())
			e.install(cfg)
			metadata := &C.Metadata{NetWork: C.UDP, Host: "api.openai.com", DstIP: netip.MustParseAddr(destination), DstPort: 49390}
			packet, err := cfg.Proxies["managed"].ListenPacketContext(context.Background(), metadata)
			if err != nil {
				t.Fatal(err)
			}
			defer packet.Close()
			_ = packet.SetDeadline(time.Now().Add(3 * time.Second))
			payload := []byte("real-socks-leaf-nonce")
			if _, err = packet.WriteTo(payload, &net.UDPAddr{IP: net.ParseIP(destination), Port: 49390}); err != nil {
				t.Fatal(err)
			}
			buffer := make([]byte, 1024)
			n, source, err := packet.ReadFrom(buffer)
			if err != nil {
				t.Fatalf("real SOCKS UDP reply failed: %v", err)
			}
			want := "mz-us-udp:" + string(payload)
			addr, ok := source.(*net.UDPAddr)
			if string(buffer[:n]) != want || !ok || !addr.IP.Equal(net.ParseIP(destination)) || addr.Port != 49390 {
				t.Fatalf("reply=%q source=%v want=%s:49390", buffer[:n], source, destination)
			}
			identity := packet.(interface{ LocalPolicyIdentity() LocalPolicyIdentity }).LocalPolicyIdentity()
			if identity.NodeID != "b2" || identity.SourceID != "b" || leaves["a1"].packets.Load() != 0 {
				t.Fatalf("wrong protocol-qualified leaf: %+v", identity)
			}
			used := map[string]int64{}
			for _, row := range e.ledger.status(e.now()) {
				used[row.SourceID] = row.UsedBytes
			}
			if used["a"] != 0 || used["b"] != int64(len(payload)+len(want)) {
				t.Fatalf("incorrect SOCKS source accounting: %v", used)
			}
		})
	}
}
