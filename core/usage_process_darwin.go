//go:build darwin

package main

import (
	"bufio"
	"bytes"
	"context"
	"errors"
	"io"
	"net"
	"net/netip"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"
	"unsafe"

	"golang.org/x/sys/unix"
)

const (
	usageProcessSnapshotInterval = 250 * time.Millisecond
	usageProcessSnapshotTimeout  = 500 * time.Millisecond
	usageProcessSnapshotMaxBytes = 4 << 20
)

type usageProcessSocketKey struct {
	network string
	ip      netip.Addr
	port    int
}

type usageProcessRecord struct {
	pid  int
	name string
}

type darwinUsageProcessResolver struct {
	mu          sync.Mutex
	refreshedAt time.Time
	snapshot    map[usageProcessSocketKey]usageProcessRecord
	paths       map[int]string
	now         func() time.Time
	load        func() ([]byte, error)
	path        func(int) (string, error)
}

func newUsageProcessResolver() usageProcessResolver {
	resolver := &darwinUsageProcessResolver{
		snapshot: make(map[usageProcessSocketKey]usageProcessRecord),
		paths:    make(map[int]string),
		now:      time.Now,
		load:     loadDarwinUsageProcessSnapshot,
		path:     darwinProcessPath,
	}
	return resolver.resolve
}

func (r *darwinUsageProcessResolver) resolve(network string, ip netip.Addr, port int) (string, string, error) {
	key := usageProcessSocketKey{
		network: strings.ToLower(network),
		ip:      ip.Unmap(),
		port:    port,
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	now := r.now()
	record, found := r.snapshot[key]
	if !found && now.Sub(r.refreshedAt) >= usageProcessSnapshotInterval {
		r.refreshedAt = now
		output, err := r.load()
		if err != nil {
			r.snapshot = make(map[usageProcessSocketKey]usageProcessRecord)
			r.paths = make(map[int]string)
			return "", "", err
		}
		r.snapshot = parseDarwinUsageProcessSnapshot(output)
		r.paths = make(map[int]string)
		record, found = r.snapshot[key]
	}
	if !found || record.pid <= 0 {
		return "", "", errors.New("process not found")
	}
	path := r.paths[record.pid]
	if path == "" {
		var err error
		path, err = r.path(record.pid)
		if err != nil || path == "" {
			return "", "", err
		}
		r.paths[record.pid] = path
	}
	name := filepath.Base(path)
	if name == "" || name == "." {
		name = record.name
	}
	return name, path, nil
}

func loadDarwinUsageProcessSnapshot() ([]byte, error) {
	ctx, cancel := context.WithTimeout(context.Background(), usageProcessSnapshotTimeout)
	defer cancel()
	command := exec.CommandContext(
		ctx,
		"/usr/sbin/lsof",
		"-nP",
		"-iTCP",
		"-iUDP",
		"-FpcPtn",
	)
	stdout, err := command.StdoutPipe()
	if err != nil {
		return nil, err
	}
	if err := command.Start(); err != nil {
		return nil, err
	}
	output, readErr := io.ReadAll(io.LimitReader(stdout, usageProcessSnapshotMaxBytes+1))
	if len(output) > usageProcessSnapshotMaxBytes {
		_ = command.Process.Kill()
		_ = command.Wait()
		return nil, errors.New("process snapshot exceeded size limit")
	}
	waitErr := command.Wait()
	if readErr != nil {
		return nil, readErr
	}
	if waitErr != nil {
		return nil, waitErr
	}
	return output, nil
}

func parseDarwinUsageProcessSnapshot(output []byte) map[usageProcessSocketKey]usageProcessRecord {
	result := make(map[usageProcessSocketKey]usageProcessRecord)
	scanner := bufio.NewScanner(bytes.NewReader(output))
	pid := 0
	name := ""
	network := ""
	for scanner.Scan() {
		line := scanner.Text()
		if len(line) < 2 {
			continue
		}
		value := line[1:]
		switch line[0] {
		case 'p':
			pid, _ = strconv.Atoi(value)
			name = ""
			network = ""
		case 'c':
			name = value
		case 'f':
			network = ""
		case 'P':
			network = strings.ToLower(value)
		case 'n':
			key, ok := darwinUsageProcessSocketKey(network, value)
			if !ok || pid <= 0 {
				continue
			}
			record := usageProcessRecord{pid: pid, name: name}
			if existing, exists := result[key]; exists && existing.pid != pid {
				result[key] = usageProcessRecord{}
				continue
			}
			result[key] = record
		}
	}
	return result
}

func darwinUsageProcessSocketKey(network, endpoint string) (usageProcessSocketKey, bool) {
	local, _, _ := strings.Cut(endpoint, "->")
	host, portText, err := net.SplitHostPort(local)
	if err != nil || host == "*" || portText == "*" {
		return usageProcessSocketKey{}, false
	}
	ip, err := netip.ParseAddr(host)
	if err != nil {
		return usageProcessSocketKey{}, false
	}
	port, err := strconv.Atoi(portText)
	if err != nil || port <= 0 || port > 65535 {
		return usageProcessSocketKey{}, false
	}
	return usageProcessSocketKey{
		network: network,
		ip:      ip.Unmap(),
		port:    port,
	}, true
}

func darwinProcessPath(pid int) (string, error) {
	buffer := make([]byte, 4096)
	_, _, errno := syscall.Syscall6(
		syscall.SYS_PROC_INFO,
		2,
		uintptr(pid),
		11,
		0,
		uintptr(unsafe.Pointer(&buffer[0])),
		uintptr(len(buffer)),
	)
	if errno != 0 {
		return "", errno
	}
	return unix.ByteSliceToString(buffer), nil
}
