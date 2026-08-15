package main

import (
	"net/netip"
	"strconv"
	"testing"
	"time"

	"github.com/metacubex/mihomo/common/atomic"
	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/tunnel/statistic"
)

type fakeUsageTracker struct {
	id   string
	info *statistic.TrackerInfo
}

func newFakeUsageTracker(id string, chain C.Chain, host string) *fakeUsageTracker {
	return &fakeUsageTracker{
		id: id,
		info: &statistic.TrackerInfo{
			Metadata: &C.Metadata{
				Host:        host,
				DstIP:       netip.MustParseAddr("1.1.1.1"),
				Process:     "Safari",
				ProcessPath: "/Applications/Safari.app/Contents/MacOS/Safari",
			},
			UploadTotal:   atomic.NewInt64(0),
			DownloadTotal: atomic.NewInt64(0),
			Chain:         chain,
		},
	}
}

func (t *fakeUsageTracker) ID() string { return t.id }

func (t *fakeUsageTracker) Close() error { return nil }

func (t *fakeUsageTracker) Info() *statistic.TrackerInfo { return t.info }

func (t *fakeUsageTracker) Chains() C.Chain { return t.info.Chain }

func (t *fakeUsageTracker) ProviderChains() C.Chain { return nil }

func (t *fakeUsageTracker) AppendToChains(adapter C.ProxyAdapter) {}

func (t *fakeUsageTracker) RemoteDestination() string { return "" }

func TestUsageCollectorDisabledAndProfileSnapshot(t *testing.T) {
	collector := newUsageCollector()
	now := time.Date(2026, time.August, 14, 12, 0, 10, 0, time.UTC)
	collector.now = func() time.Time { return now }
	collector.isActive = func(string) bool { return true }
	tracker := newFakeUsageTracker("one", C.Chain{"Node A"}, "api.example.com")

	collector.track(tracker)
	collector.collect()
	if batch := collector.readBatch(); batch != nil {
		t.Fatalf("disabled collector returned batch: %#v", batch)
	}

	profileID := int64(42)
	collector.configure(UsageCollectionParams{
		Enabled:      true,
		ProfileID:    &profileID,
		ProfileLabel: "Work",
		Revision:     1,
	})
	collector.track(tracker)
	collector.configure(UsageCollectionParams{
		Enabled:      true,
		ProfileID:    nil,
		ProfileLabel: "Other",
		Revision:     2,
	})
	tracker.info.UploadTotal.Add(12)
	collector.collect()
	batch := collector.readBatch()
	if batch == nil || len(batch.Buckets) != 1 {
		t.Fatalf("unexpected batch: %#v", batch)
	}
	bucket := batch.Buckets[0]
	if bucket.ProfileID == nil || *bucket.ProfileID != profileID || bucket.ProfileLabel != "Work" {
		t.Fatalf("profile snapshot changed: %#v", bucket)
	}
}

func TestUsageCollectorSplitsLongConnectionByMinute(t *testing.T) {
	collector := newUsageCollector()
	now := time.Date(2026, time.August, 14, 12, 0, 10, 0, time.UTC)
	collector.now = func() time.Time { return now }
	collector.isActive = func(string) bool { return true }
	collector.configure(UsageCollectionParams{Enabled: true, Revision: 1})
	tracker := newFakeUsageTracker("one", C.Chain{"Node A"}, "cdn.example.co.uk")
	collector.track(tracker)
	tracker.info.UploadTotal.Add(100)
	tracker.info.DownloadTotal.Add(200)
	collector.collect()

	now = now.Add(time.Minute)
	tracker.info.UploadTotal.Add(50)
	tracker.info.DownloadTotal.Add(75)
	collector.collect()

	batch := collector.readBatch()
	if batch == nil || len(batch.Buckets) != 2 {
		t.Fatalf("unexpected batch: %#v", batch)
	}
	first, second := batch.Buckets[0], batch.Buckets[1]
	if first.Upload != 100 || first.Download != 200 || first.Connections != 1 {
		t.Fatalf("unexpected first minute: %#v", first)
	}
	if second.Upload != 50 || second.Download != 75 || second.Connections != 0 {
		t.Fatalf("unexpected second minute: %#v", second)
	}
	if first.Domain != "example.co.uk" || first.Host != "cdn.example.co.uk" {
		t.Fatalf("unexpected domain normalization: %#v", first)
	}
}

func TestUsageCollectorRetainsShortClosedConnection(t *testing.T) {
	collector := newUsageCollector()
	now := time.Date(2026, time.August, 14, 12, 0, 10, 0, time.UTC)
	collector.now = func() time.Time { return now }
	collector.isActive = func(string) bool { return false }
	collector.configure(UsageCollectionParams{Enabled: true, Revision: 1})
	tracker := newFakeUsageTracker("short", C.Chain{"DIRECT"}, "")
	tracker.info.UploadTotal.Add(7)
	tracker.info.DownloadTotal.Add(9)
	collector.track(tracker)

	collector.collect()
	if len(collector.tracked) != 1 {
		t.Fatal("short connection was removed before the join/store grace elapsed")
	}
	now = now.Add(usageInactiveGrace)
	collector.collect()
	if len(collector.tracked) != 0 {
		t.Fatal("closed connection was not removed after final sampling")
	}
	batch := collector.readBatch()
	if batch == nil || len(batch.Buckets) != 1 {
		t.Fatalf("unexpected batch: %#v", batch)
	}
	bucket := batch.Buckets[0]
	if bucket.Route != "direct" || bucket.Node != "DIRECT" || bucket.Upload != 7 || bucket.Download != 9 {
		t.Fatalf("unexpected direct bucket: %#v", bucket)
	}
}

func TestUsageCollectorKeepsUnknownMetadataAndIPFallback(t *testing.T) {
	collector := newUsageCollector()
	collector.isActive = func(string) bool { return true }
	collector.configure(UsageCollectionParams{Enabled: true, Revision: 1})
	tracker := newFakeUsageTracker("unknown", nil, "")
	tracker.info.Metadata.Process = ""
	tracker.info.Metadata.ProcessPath = ""
	collector.track(tracker)

	batch := collector.readBatch()
	if batch == nil || len(batch.Buckets) != 1 {
		t.Fatalf("unexpected batch: %#v", batch)
	}
	bucket := batch.Buckets[0]
	if bucket.Route != "unknown" || bucket.Node != "" || bucket.DestinationIP != "1.1.1.1" {
		t.Fatalf("unexpected unknown route fallback: %#v", bucket)
	}
	if bucket.Process != "" || bucket.ProcessPath != "" || bucket.Connections != 1 {
		t.Fatalf("unexpected unknown process bucket: %#v", bucket)
	}
}

func TestUsageCollectorRetriesMissingDarwinProcess(t *testing.T) {
	collector := newUsageCollector()
	collector.isActive = func(string) bool { return true }
	collector.processLookupEnabled = func() bool { return true }
	resolved := make(chan struct{}, 1)
	collector.processResolver = func(network string, ip netip.Addr, port int) (string, string, error) {
		if network != "tcp" || ip.String() != "127.0.0.1" || port != 54321 {
			t.Fatalf("unexpected lookup tuple: %s %s %d", network, ip, port)
		}
		resolved <- struct{}{}
		return "Safari", "/Applications/Safari.app/Contents/MacOS/Safari", nil
	}
	collector.configure(UsageCollectionParams{Enabled: true, Revision: 1})
	tracker := newFakeUsageTracker("retry", C.Chain{"Node A"}, "example.com")
	tracker.info.Metadata.Process = ""
	tracker.info.Metadata.ProcessPath = ""
	tracker.info.Metadata.NetWork = C.TCP
	tracker.info.Metadata.SrcIP = netip.MustParseAddr("127.0.0.1")
	tracker.info.Metadata.SrcPort = 54321
	collector.track(tracker)

	select {
	case <-resolved:
	case <-time.After(time.Second):
		t.Fatal("process lookup was not attempted")
	}
	deadline := time.Now().Add(time.Second)
	for {
		collector.mu.Lock()
		processPath := collector.tracked[tracker.ID()].dimensions.processPath
		collector.mu.Unlock()
		if processPath != "" {
			break
		}
		if time.Now().After(deadline) {
			t.Fatal("resolved process was not applied")
		}
		time.Sleep(time.Millisecond)
	}

	tracker.info.DownloadTotal.Add(10)
	batch := collector.readBatch()
	if batch == nil || len(batch.Buckets) != 1 {
		t.Fatalf("unexpected batch: %#v", batch)
	}
	bucket := batch.Buckets[0]
	if bucket.Process != "Safari" || bucket.ProcessPath != "/Applications/Safari.app/Contents/MacOS/Safari" {
		t.Fatalf("retry did not update process dimensions: %#v", bucket)
	}
}

func TestUsageCollectorDoesNotOverrideDisabledProcessLookup(t *testing.T) {
	collector := newUsageCollector()
	collector.isActive = func(string) bool { return true }
	collector.processLookupEnabled = func() bool { return false }
	called := make(chan struct{}, 1)
	collector.processResolver = func(string, netip.Addr, int) (string, string, error) {
		called <- struct{}{}
		return "Safari", "/Applications/Safari.app/Contents/MacOS/Safari", nil
	}
	collector.configure(UsageCollectionParams{Enabled: true, Revision: 1})
	tracker := newFakeUsageTracker("disabled", C.Chain{"Node A"}, "example.com")
	tracker.info.Metadata.Process = ""
	tracker.info.Metadata.ProcessPath = ""
	tracker.info.Metadata.NetWork = C.TCP
	tracker.info.Metadata.SrcIP = netip.MustParseAddr("127.0.0.1")
	tracker.info.Metadata.SrcPort = 54321
	collector.track(tracker)

	select {
	case <-called:
		t.Fatal("disabled process recognition triggered a fallback lookup")
	case <-time.After(usageProcessLookupDelay * 2):
	}
}

func TestUsageCollectorPauseDropsNewDataAndReenableStartsSession(t *testing.T) {
	collector := newUsageCollector()
	collector.isActive = func(string) bool { return true }
	collector.configure(UsageCollectionParams{Enabled: true, Revision: 1})
	tracker := newFakeUsageTracker("one", C.Chain{"Node A"}, "example.com")
	collector.track(tracker)
	first := collector.readBatch()
	if first == nil {
		t.Fatal("enabled collector did not create a batch")
	}
	if !collector.ackBatch(UsageBatchAck{SessionID: first.SessionID, Sequence: first.Sequence}) {
		t.Fatal("failed to acknowledge initial batch")
	}

	tracker.info.UploadTotal.Add(10)
	collector.configure(UsageCollectionParams{Enabled: false, Revision: 2})
	if cap(collector.samples) != 0 {
		t.Fatalf("pause retained the sampling buffer: %d", cap(collector.samples))
	}
	final := collector.readBatch()
	if final == nil || len(final.Buckets) != 1 || final.Buckets[0].Upload != 10 {
		t.Fatalf("pause did not expose final counters: %#v", final)
	}
	if !collector.ackBatch(UsageBatchAck{SessionID: final.SessionID, Sequence: final.Sequence}) {
		t.Fatal("failed to acknowledge final batch")
	}
	tracker.info.UploadTotal.Add(15)
	if batch := collector.readBatch(); batch != nil {
		t.Fatalf("paused collector recorded new data: %#v", batch)
	}

	collector.configure(UsageCollectionParams{Enabled: true, Revision: 3})
	collector.track(tracker)
	second := collector.readBatch()
	if second == nil || second.SessionID == first.SessionID {
		t.Fatalf("re-enabled collector reused session: first=%#v second=%#v", first, second)
	}
}

func TestUsagePauseKeepsUnacknowledgedBatchReadable(t *testing.T) {
	collector := newUsageCollector()
	collector.isActive = func(string) bool { return true }
	collector.configure(UsageCollectionParams{Enabled: true, Revision: 1})
	tracker := newFakeUsageTracker("one", C.Chain{"Node A"}, "example.com")
	collector.track(tracker)
	tracker.info.DownloadTotal.Add(9)
	first := collector.readBatch()
	if first == nil {
		t.Fatal("missing initial batch")
	}

	collector.configure(UsageCollectionParams{Enabled: false, Revision: 2})
	retry := collector.readBatch()
	if retry == nil || retry.SessionID != first.SessionID || retry.Sequence != first.Sequence {
		t.Fatalf("pause discarded in-flight batch: first=%#v retry=%#v", first, retry)
	}
	if !collector.ackBatch(UsageBatchAck{SessionID: retry.SessionID, Sequence: retry.Sequence}) {
		t.Fatal("paused collector rejected acknowledgement")
	}
	if batch := collector.readBatch(); batch != nil {
		t.Fatalf("drained paused collector returned data: %#v", batch)
	}
}

func TestUsageBatchRequiresMatchingAck(t *testing.T) {
	collector := newUsageCollector()
	collector.isActive = func(string) bool { return true }
	collector.configure(UsageCollectionParams{Enabled: true, Revision: 1})
	tracker := newFakeUsageTracker("one", C.Chain{"Node A"}, "example.com")
	collector.track(tracker)
	collector.collect()

	first := collector.readBatch()
	second := collector.readBatch()
	if first == nil || second == nil || first.SessionID != second.SessionID || first.Sequence != second.Sequence {
		t.Fatalf("in-flight batch changed: first=%#v second=%#v", first, second)
	}
	if collector.ackBatch(UsageBatchAck{SessionID: first.SessionID, Sequence: first.Sequence + 1}) {
		t.Fatal("accepted mismatched acknowledgement")
	}
	if !collector.ackBatch(UsageBatchAck{SessionID: first.SessionID, Sequence: first.Sequence}) {
		t.Fatal("rejected matching acknowledgement")
	}
	if collector.ackBatch(UsageBatchAck{SessionID: first.SessionID, Sequence: first.Sequence}) {
		t.Fatal("accepted duplicate acknowledgement")
	}
	if batch := collector.readBatch(); batch != nil {
		t.Fatalf("acknowledged batch returned again: %#v", batch)
	}
}

func TestUsageConfigurationRejectsOutOfOrderRevision(t *testing.T) {
	collector := newUsageCollector()
	if !collector.configure(UsageCollectionParams{Enabled: true, ProfileLabel: "New", Revision: 3}) {
		t.Fatal("rejected latest configuration")
	}
	if collector.configure(UsageCollectionParams{Enabled: false, Revision: 2}) {
		t.Fatal("accepted stale configuration")
	}
	if !collector.enabled || collector.profile.label != "New" {
		t.Fatalf("stale configuration changed state: %#v", collector)
	}
	if !collector.configure(UsageCollectionParams{Enabled: true, ProfileLabel: "New", Revision: 3}) {
		t.Fatal("rejected idempotent configuration retry")
	}
}

func TestUsageEnableBaselinesExistingConnections(t *testing.T) {
	collector := newUsageCollector()
	collector.isActive = func(string) bool { return true }
	tracker := newFakeUsageTracker("existing", C.Chain{"Node A"}, "example.com")
	tracker.info.UploadTotal.Add(100)
	tracker.info.DownloadTotal.Add(200)
	collector.rangeConnections = func(callback func(statistic.Tracker) bool) {
		callback(tracker)
	}

	collector.configure(UsageCollectionParams{Enabled: true, Revision: 1})
	if batch := collector.readBatch(); batch != nil {
		t.Fatalf("enable backfilled traffic from existing connection: %#v", batch)
	}
	tracker.info.UploadTotal.Add(7)
	tracker.info.DownloadTotal.Add(9)
	batch := collector.readBatch()
	if batch == nil || len(batch.Buckets) != 1 {
		t.Fatalf("missing post-enable delta: %#v", batch)
	}
	bucket := batch.Buckets[0]
	if bucket.Upload != 7 || bucket.Download != 9 || bucket.Connections != 0 {
		t.Fatalf("unexpected existing connection delta: %#v", bucket)
	}
}

func TestUsageUsesSniffedRuleHost(t *testing.T) {
	collector := newUsageCollector()
	collector.isActive = func(string) bool { return true }
	collector.configure(UsageCollectionParams{Enabled: true, Revision: 1})
	tracker := newFakeUsageTracker("sniffed", C.Chain{"Node A"}, "original.invalid")
	tracker.info.Metadata.SniffHost = "Video.Example.COM."
	collector.track(tracker)
	batch := collector.readBatch()
	if batch == nil || len(batch.Buckets) != 1 {
		t.Fatalf("unexpected batch: %#v", batch)
	}
	bucket := batch.Buckets[0]
	if bucket.Host != "video.example.com" || bucket.Domain != "example.com" {
		t.Fatalf("did not use sniffed rule host: %#v", bucket)
	}
}

func TestUsagePendingLimitDegradesDimensionsWithoutLosingTotals(t *testing.T) {
	collector := newUsageCollector()
	collector.maxPending = 1
	collector.isActive = func(string) bool { return true }
	collector.configure(UsageCollectionParams{Enabled: true, Revision: 1})
	first := newFakeUsageTracker("first", C.Chain{"Node A"}, "a.example.com")
	second := newFakeUsageTracker("second", C.Chain{"Node B"}, "b.example.com")
	collector.track(first)
	collector.track(second)
	first.info.UploadTotal.Add(11)
	second.info.DownloadTotal.Add(13)

	batch := collector.readBatch()
	if batch == nil || !batch.Degraded || len(batch.Buckets) != 2 {
		t.Fatalf("expected degraded batch: %#v", batch)
	}
	var upload, download, connections int64
	for _, bucket := range batch.Buckets {
		upload += bucket.Upload
		download += bucket.Download
		connections += bucket.Connections
	}
	if upload != 11 || download != 13 || connections != 2 {
		t.Fatalf("degraded totals changed: %#v", batch.Buckets)
	}
	if len(collector.pending) > collector.maxPending {
		t.Fatalf("pending bucket limit exceeded: %d", len(collector.pending))
	}
}

func TestUsageOverflowPreservesMinuteBuckets(t *testing.T) {
	collector := newUsageCollector()
	collector.maxPending = 1
	now := time.Date(2026, time.August, 14, 12, 0, 10, 0, time.UTC)
	collector.now = func() time.Time { return now }
	collector.isActive = func(string) bool { return true }
	collector.configure(UsageCollectionParams{Enabled: true, Revision: 1})
	first := newFakeUsageTracker("first", C.Chain{"Node A"}, "a.example.com")
	second := newFakeUsageTracker("second", C.Chain{"Node B"}, "b.example.com")
	collector.track(first)
	collector.track(second)
	first.info.UploadTotal.Add(1)
	second.info.DownloadTotal.Add(2)
	collector.collect()

	now = now.Add(time.Minute)
	second.info.DownloadTotal.Add(3)
	collector.collect()
	batch := collector.readBatch()
	if batch == nil || !batch.Degraded || len(batch.Buckets) != 3 {
		t.Fatalf("unexpected cross-minute overflow batch: %#v", batch)
	}
	minuteTotals := map[int64]int64{}
	for _, bucket := range batch.Buckets {
		minuteTotals[bucket.Minute] += bucket.Upload + bucket.Download
	}
	firstMinute := time.Date(2026, time.August, 14, 12, 0, 0, 0, time.UTC).UnixMilli()
	secondMinute := firstMinute + time.Minute.Milliseconds()
	if minuteTotals[firstMinute] != 3 || minuteTotals[secondMinute] != 3 {
		t.Fatalf("overflow changed minute totals: %#v", minuteTotals)
	}
	if batch.DegradedStartMinute != firstMinute || batch.DegradedEndMinute != secondMinute+time.Minute.Milliseconds() {
		t.Fatalf("unexpected degraded interval: %#v", batch)
	}
}

func BenchmarkUsageCollectorCollect10K(b *testing.B) {
	collector := newUsageCollector()
	collector.isActive = func(string) bool { return true }
	collector.rangeConnections = func(func(statistic.Tracker) bool) {}
	collector.configure(UsageCollectionParams{Enabled: true, Revision: 1})
	for index := 0; index < 10000; index++ {
		tracker := newFakeUsageTracker(
			strconv.Itoa(index),
			C.Chain{"Node A"},
			"api.example.com",
		)
		collector.track(tracker)
	}
	collector.collect()
	b.ReportAllocs()
	b.ResetTimer()
	for index := 0; index < b.N; index++ {
		collector.collect()
	}
}
