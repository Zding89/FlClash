//go:build darwin

package main

import (
	"errors"
	"net/netip"
	"testing"
	"time"
)

func TestParseDarwinUsageProcessSnapshot(t *testing.T) {
	output := []byte("p41\ncSafari\nf8\ntIPv4\nPTCP\nn127.0.0.1:54321->127.0.0.1:7890\n" +
		"p42\ncMail\nf9\ntIPv6\nPUDP\nn[::1]:61234\n")
	snapshot := parseDarwinUsageProcessSnapshot(output)
	tcp := snapshot[usageProcessSocketKey{
		network: "tcp",
		ip:      netip.MustParseAddr("127.0.0.1"),
		port:    54321,
	}]
	if tcp.pid != 41 || tcp.name != "Safari" {
		t.Fatalf("unexpected TCP record: %#v", tcp)
	}
	udp := snapshot[usageProcessSocketKey{
		network: "udp",
		ip:      netip.MustParseAddr("::1"),
		port:    61234,
	}]
	if udp.pid != 42 || udp.name != "Mail" {
		t.Fatalf("unexpected UDP record: %#v", udp)
	}
}

func TestParseDarwinUsageProcessSnapshotRejectsAmbiguousEndpoint(t *testing.T) {
	output := []byte("p41\ncSafari\nf8\nPTCP\nn127.0.0.1:54321->127.0.0.1:7890\n" +
		"p42\ncMail\nf9\nPTCP\nn127.0.0.1:54321->127.0.0.1:7890\n")
	snapshot := parseDarwinUsageProcessSnapshot(output)
	record := snapshot[usageProcessSocketKey{
		network: "tcp",
		ip:      netip.MustParseAddr("127.0.0.1"),
		port:    54321,
	}]
	if record.pid != 0 {
		t.Fatalf("ambiguous endpoint selected a process: %#v", record)
	}
}

func TestDarwinUsageProcessResolverCachesSnapshotAndPath(t *testing.T) {
	now := time.Date(2026, time.August, 15, 12, 0, 0, 0, time.UTC)
	loadCount := 0
	pathCount := 0
	resolver := &darwinUsageProcessResolver{
		snapshot: make(map[usageProcessSocketKey]usageProcessRecord),
		paths:    make(map[int]string),
		now:      func() time.Time { return now },
		load: func() ([]byte, error) {
			loadCount++
			return []byte("p41\ncSafari\nf8\nPTCP\nn127.0.0.1:54321->127.0.0.1:7890\n"), nil
		},
		path: func(pid int) (string, error) {
			pathCount++
			if pid != 41 {
				return "", errors.New("unexpected pid")
			}
			return "/Applications/Safari.app/Contents/MacOS/Safari", nil
		},
	}
	for index := 0; index < 2; index++ {
		name, path, err := resolver.resolve("tcp", netip.MustParseAddr("127.0.0.1"), 54321)
		if err != nil || name != "Safari" || path != "/Applications/Safari.app/Contents/MacOS/Safari" {
			t.Fatalf("unexpected resolution: %s %s %v", name, path, err)
		}
	}
	if loadCount != 1 || pathCount != 1 {
		t.Fatalf("resolver did not cache results: loads=%d paths=%d", loadCount, pathCount)
	}
}

func TestDarwinUsageProcessResolverRateLimitsSnapshotFailures(t *testing.T) {
	now := time.Date(2026, time.August, 15, 12, 0, 0, 0, time.UTC)
	loadCount := 0
	resolver := &darwinUsageProcessResolver{
		snapshot: make(map[usageProcessSocketKey]usageProcessRecord),
		paths:    make(map[int]string),
		now:      func() time.Time { return now },
		load: func() ([]byte, error) {
			loadCount++
			return nil, errors.New("snapshot failed")
		},
		path: func(int) (string, error) {
			return "", errors.New("unexpected path lookup")
		},
	}
	for index := 0; index < 2; index++ {
		_, _, _ = resolver.resolve("tcp", netip.MustParseAddr("127.0.0.1"), 54321)
	}
	if loadCount != 1 {
		t.Fatalf("snapshot failure bypassed the refresh limit: %d", loadCount)
	}
}
