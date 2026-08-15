package main

import (
	"crypto/rand"
	"encoding/hex"
	"net/netip"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/metacubex/mihomo/component/process"
	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/tunnel"
	"github.com/metacubex/mihomo/tunnel/statistic"
	"golang.org/x/net/publicsuffix"
)

const (
	usageSampleInterval       = time.Second
	usageInactiveGrace        = 2 * time.Second
	usageBatchMaxBucketNum    = 2000
	usagePendingMaxBuckets    = 20000
	usageOverflowMaxBuckets   = 4320
	usageProcessLookupDelay   = 10 * time.Millisecond
	usageProcessLookupQueue   = 64
	usageProcessLookupWorkers = 2
)

type usageProcessResolver func(string, netip.Addr, int) (string, string, error)

type usageProcessLookupJob struct {
	collector *usageCollector
	id        string
	network   string
	ip        netip.Addr
	port      int
	resolver  usageProcessResolver
}

var usageProcessLookups = make(chan usageProcessLookupJob, usageProcessLookupQueue)

type UsageCollectionParams struct {
	Enabled      bool   `json:"enabled"`
	ProfileID    *int64 `json:"profileId"`
	ProfileLabel string `json:"profileLabel"`
	Revision     int64  `json:"revision"`
}

type UsageBatchAck struct {
	SessionID string `json:"sessionId"`
	Sequence  int64  `json:"sequence"`
}

type UsageBucket struct {
	Minute        int64  `json:"minute"`
	ProfileID     *int64 `json:"profileId"`
	ProfileLabel  string `json:"profileLabel"`
	Route         string `json:"route"`
	Node          string `json:"node"`
	Process       string `json:"process"`
	ProcessPath   string `json:"processPath"`
	Domain        string `json:"domain"`
	Host          string `json:"host"`
	DestinationIP string `json:"destinationIP"`
	Upload        int64  `json:"upload"`
	Download      int64  `json:"download"`
	Connections   int64  `json:"connections"`
}

type UsageBatch struct {
	SessionID           string        `json:"sessionId"`
	Sequence            int64         `json:"sequence"`
	Buckets             []UsageBucket `json:"buckets"`
	Degraded            bool          `json:"degraded"`
	DegradedStartMinute int64         `json:"degradedStartMinute"`
	DegradedEndMinute   int64         `json:"degradedEndMinute"`
}

type usageProfileContext struct {
	id    *int64
	label string
}

type usageDimensions struct {
	profile       usageProfileContext
	profileID     int64
	hasProfileID  bool
	profileLabel  string
	route         string
	node          string
	process       string
	processPath   string
	domain        string
	host          string
	destinationIP string
}

type usageTrackedConnection struct {
	tracker      statistic.Tracker
	dimensions   usageDimensions
	registeredAt time.Time
	lastUpload   int64
	lastDownload int64
	counted      bool
	seenActive   bool
}

type usageBucketKey struct {
	minute        int64
	profileID     int64
	hasProfileID  bool
	profileLabel  string
	route         string
	node          string
	process       string
	processPath   string
	domain        string
	host          string
	destinationIP string
}

type usageOverflowKey struct {
	minute int64
	route  string
}

type usageSample struct {
	id       string
	tracked  *usageTrackedConnection
	upload   int64
	download int64
	active   bool
	valid    bool
}

type usageCollector struct {
	mu                   sync.Mutex
	collectMu            sync.Mutex
	enabled              bool
	configured           bool
	configRevision       int64
	profile              usageProfileContext
	tracked              map[string]*usageTrackedConnection
	samples              []usageSample
	pending              map[usageBucketKey]*UsageBucket
	overflow             map[usageOverflowKey]*UsageBucket
	overflowFallback     map[string]*UsageBucket
	inFlight             *UsageBatch
	session              string
	sequence             int64
	degradedStart        int64
	degradedEnd          int64
	maxPending           int
	now                  func() time.Time
	isActive             func(string) bool
	rangeConnections     func(func(statistic.Tracker) bool)
	processResolver      usageProcessResolver
	processLookupEnabled func() bool
}

func newUsageCollector() *usageCollector {
	return &usageCollector{
		tracked:          make(map[string]*usageTrackedConnection),
		pending:          make(map[usageBucketKey]*UsageBucket),
		overflow:         make(map[usageOverflowKey]*UsageBucket),
		overflowFallback: make(map[string]*UsageBucket),
		maxPending:       usagePendingMaxBuckets,
		now:              time.Now,
		isActive: func(id string) bool {
			return statistic.DefaultManager.Get(id) != nil
		},
		rangeConnections: statistic.DefaultManager.Range,
		processResolver:  newUsageProcessResolver(),
		processLookupEnabled: func() bool {
			return tunnel.FindProcessMode() == process.FindProcessAlways
		},
	}
}

func runUsageProcessLookupWorker() {
	for job := range usageProcessLookups {
		time.Sleep(usageProcessLookupDelay)
		processName, processPath, err := job.resolver(job.network, job.ip, job.port)
		if err != nil || processPath == "" {
			continue
		}
		job.collector.applyProcessLookup(job.id, processName, processPath)
	}
}

func (c *usageCollector) enqueueProcessLookup(id string, metadata *C.Metadata) {
	if c.processResolver == nil || !c.processLookupEnabled() || metadata == nil || metadata.ProcessPath != "" ||
		!metadata.SrcIP.IsValid() || metadata.SrcPort == 0 {
		return
	}
	job := usageProcessLookupJob{
		collector: c,
		id:        id,
		network:   metadata.NetWork.String(),
		ip:        metadata.SrcIP,
		port:      int(metadata.SrcPort),
		resolver:  c.processResolver,
	}
	select {
	case usageProcessLookups <- job:
	default:
	}
}

func (c *usageCollector) applyProcessLookup(id, processName, processPath string) {
	c.mu.Lock()
	defer c.mu.Unlock()
	tracked, exists := c.tracked[id]
	if !exists || tracked.dimensions.processPath != "" {
		return
	}
	tracked.dimensions.process = processName
	tracked.dimensions.processPath = processPath
}

func newUsageSessionID() string {
	bytes := make([]byte, 16)
	if _, err := rand.Read(bytes); err != nil {
		return hex.EncodeToString([]byte(time.Now().UTC().Format(time.RFC3339Nano)))[:32]
	}
	return hex.EncodeToString(bytes)
}

func cloneProfileID(value *int64) *int64 {
	if value == nil {
		return nil
	}
	copyValue := *value
	return &copyValue
}

func sameProfileID(a, b *int64) bool {
	if a == nil || b == nil {
		return a == nil && b == nil
	}
	return *a == *b
}

func (c *usageCollector) configure(params UsageCollectionParams) bool {
	c.collectMu.Lock()
	defer c.collectMu.Unlock()

	c.mu.Lock()
	if c.configured {
		if params.Revision < c.configRevision {
			c.mu.Unlock()
			return false
		}
		if params.Revision == c.configRevision {
			accepted := params.Enabled == c.enabled &&
				sameProfileID(params.ProfileID, c.profile.id) &&
				params.ProfileLabel == c.profile.label
			c.mu.Unlock()
			return accepted
		}
	}
	wasEnabled := c.enabled
	c.mu.Unlock()

	if wasEnabled && !params.Enabled {
		c.collectLocked(true)
	}

	c.mu.Lock()
	c.configured = true
	c.configRevision = params.Revision
	c.profile = usageProfileContext{
		id:    cloneProfileID(params.ProfileID),
		label: params.ProfileLabel,
	}
	if !params.Enabled {
		c.enabled = false
		c.mu.Unlock()
		return true
	}
	if !wasEnabled {
		resumeSession := c.session != "" &&
			(c.inFlight != nil || len(c.pending) > 0 || len(c.overflow) > 0 || len(c.overflowFallback) > 0)
		if !resumeSession {
			c.session = newUsageSessionID()
			c.sequence = 0
			c.pending = make(map[usageBucketKey]*UsageBucket)
			c.overflow = make(map[usageOverflowKey]*UsageBucket)
			c.overflowFallback = make(map[string]*UsageBucket)
			c.inFlight = nil
			c.degradedStart = 0
			c.degradedEnd = 0
		}
		c.tracked = make(map[string]*usageTrackedConnection)
	}
	c.enabled = true
	c.mu.Unlock()

	if !wasEnabled {
		c.rangeConnections(func(tracker statistic.Tracker) bool {
			c.trackWithBaseline(tracker)
			return true
		})
	}
	return true
}

func normalizedHost(metadata *C.Metadata) (string, string, string) {
	if metadata == nil {
		return "", "", ""
	}
	host := strings.TrimSuffix(strings.ToLower(strings.TrimSpace(metadata.RuleHost())), ".")
	domain := ""
	if host != "" {
		if value, err := publicsuffix.EffectiveTLDPlusOne(host); err == nil {
			domain = value
		}
	}
	destinationIP := ""
	if metadata.DstIP.IsValid() {
		destinationIP = metadata.DstIP.Unmap().String()
	}
	return host, domain, destinationIP
}

func usageRoute(chain C.Chain) (string, string) {
	if len(chain) == 0 || strings.TrimSpace(chain[0]) == "" {
		return "unknown", ""
	}
	node := chain[0]
	if node == "DIRECT" {
		return "direct", node
	}
	return "proxy", node
}

func usageConnectionDimensions(profile usageProfileContext, info *statistic.TrackerInfo) usageDimensions {
	profileID := int64(0)
	hasProfileID := profile.id != nil
	if hasProfileID {
		profileID = *profile.id
	}
	route, node := usageRoute(info.Chain)
	host, domain, destinationIP := normalizedHost(info.Metadata)
	return usageDimensions{
		profile:       usageProfileContext{id: cloneProfileID(profile.id), label: profile.label},
		profileID:     profileID,
		hasProfileID:  hasProfileID,
		profileLabel:  profile.label,
		route:         route,
		node:          node,
		process:       info.Metadata.Process,
		processPath:   info.Metadata.ProcessPath,
		domain:        domain,
		host:          host,
		destinationIP: destinationIP,
	}
}

func (c *usageCollector) track(tracker statistic.Tracker) {
	c.trackInternal(tracker, false)
}

func (c *usageCollector) trackWithBaseline(tracker statistic.Tracker) {
	c.trackInternal(tracker, true)
}

func (c *usageCollector) trackInternal(tracker statistic.Tracker, baseline bool) {
	if tracker == nil {
		return
	}
	info := tracker.Info()
	if info == nil || info.Metadata == nil {
		return
	}
	c.mu.Lock()
	if !c.enabled {
		c.mu.Unlock()
		return
	}
	id := tracker.ID()
	if _, exists := c.tracked[id]; exists {
		c.mu.Unlock()
		return
	}
	tracked := &usageTrackedConnection{
		tracker:      tracker,
		dimensions:   usageConnectionDimensions(c.profile, info),
		registeredAt: c.now(),
	}
	if baseline {
		tracked.lastUpload = info.UploadTotal.Load()
		tracked.lastDownload = info.DownloadTotal.Load()
		tracked.counted = true
		tracked.seenActive = true
	}
	c.tracked[id] = tracked
	c.mu.Unlock()
	c.enqueueProcessLookup(id, info.Metadata)
}

func usageKey(minute int64, dimensions usageDimensions) (usageBucketKey, *UsageBucket) {
	key := usageBucketKey{
		minute:        minute,
		profileID:     dimensions.profileID,
		hasProfileID:  dimensions.hasProfileID,
		profileLabel:  dimensions.profileLabel,
		route:         dimensions.route,
		node:          dimensions.node,
		process:       dimensions.process,
		processPath:   dimensions.processPath,
		domain:        dimensions.domain,
		host:          dimensions.host,
		destinationIP: dimensions.destinationIP,
	}
	bucket := &UsageBucket{
		Minute:        minute,
		ProfileID:     cloneProfileID(dimensions.profile.id),
		ProfileLabel:  dimensions.profileLabel,
		Route:         dimensions.route,
		Node:          dimensions.node,
		Process:       dimensions.process,
		ProcessPath:   dimensions.processPath,
		Domain:        dimensions.domain,
		Host:          dimensions.host,
		DestinationIP: dimensions.destinationIP,
	}
	return key, bucket
}

func (c *usageCollector) addDelta(minute int64, dimensions usageDimensions, upload, download, connections int64) {
	key, freshBucket := usageKey(minute, dimensions)
	if bucket, exists := c.pending[key]; exists {
		bucket.Upload += upload
		bucket.Download += download
		bucket.Connections += connections
		return
	}
	if len(c.pending) < c.maxPending {
		freshBucket.Upload = upload
		freshBucket.Download = download
		freshBucket.Connections = connections
		c.pending[key] = freshBucket
		return
	}
	route := dimensions.route
	if c.degradedStart == 0 || minute < c.degradedStart {
		c.degradedStart = minute
	}
	minuteEnd := minute + time.Minute.Milliseconds()
	if minuteEnd > c.degradedEnd {
		c.degradedEnd = minuteEnd
	}
	overflowKey := usageOverflowKey{minute: minute, route: route}
	bucket, exists := c.overflow[overflowKey]
	if !exists {
		if len(c.overflow) < usageOverflowMaxBuckets {
			bucket = &UsageBucket{Minute: minute, Route: route}
			if route == "direct" {
				bucket.Node = "DIRECT"
			}
			c.overflow[overflowKey] = bucket
		} else {
			bucket = c.overflowFallback[route]
			if bucket == nil {
				bucket = &UsageBucket{Minute: minute, Route: route}
				if route == "direct" {
					bucket.Node = "DIRECT"
				}
				c.overflowFallback[route] = bucket
			}
		}
	}
	bucket.Upload += upload
	bucket.Download += download
	bucket.Connections += connections
}

func (c *usageCollector) collect() {
	c.collectMu.Lock()
	defer c.collectMu.Unlock()
	c.collectLocked(false)
}

func (c *usageCollector) resetSamples(release bool) {
	clear(c.samples)
	c.samples = c.samples[:0]
	if release || cap(c.samples) > max(4096, len(c.tracked)*4) {
		c.samples = nil
	}
}

func (c *usageCollector) collectLocked(stop bool) {
	c.mu.Lock()
	if !c.enabled {
		c.mu.Unlock()
		return
	}
	session := c.session
	now := c.now()
	if stop {
		c.enabled = false
	}
	c.samples = c.samples[:0]
	for id, tracked := range c.tracked {
		c.samples = append(c.samples, usageSample{id: id, tracked: tracked})
	}
	trackedConnections := c.samples
	c.mu.Unlock()

	for index := range trackedConnections {
		info := trackedConnections[index].tracked.tracker.Info()
		if info == nil || info.Metadata == nil {
			continue
		}
		trackedConnections[index].upload = info.UploadTotal.Load()
		trackedConnections[index].download = info.DownloadTotal.Load()
		if !stop {
			trackedConnections[index].active = c.isActive(trackedConnections[index].id)
		}
		trackedConnections[index].valid = true
	}

	c.mu.Lock()
	defer c.mu.Unlock()
	if (!stop && !c.enabled) || c.session != session {
		c.resetSamples(stop)
		return
	}
	minute := now.UTC().Truncate(time.Minute).UnixMilli()
	for _, sample := range trackedConnections {
		tracked, exists := c.tracked[sample.id]
		if !exists || tracked != sample.tracked {
			continue
		}
		if !sample.valid {
			delete(c.tracked, sample.id)
			continue
		}
		uploadDelta := sample.upload - tracked.lastUpload
		downloadDelta := sample.download - tracked.lastDownload
		if uploadDelta < 0 {
			uploadDelta = 0
		}
		if downloadDelta < 0 {
			downloadDelta = 0
		}
		connectionDelta := int64(0)
		if !tracked.counted {
			connectionDelta = 1
			tracked.counted = true
		}
		if uploadDelta > 0 || downloadDelta > 0 || connectionDelta > 0 {
			c.addDelta(minute, tracked.dimensions, uploadDelta, downloadDelta, connectionDelta)
		}
		tracked.lastUpload = sample.upload
		tracked.lastDownload = sample.download
		if stop {
			delete(c.tracked, sample.id)
			continue
		}
		if sample.active {
			tracked.seenActive = true
			continue
		}
		if tracked.seenActive || now.Sub(tracked.registeredAt) >= usageInactiveGrace {
			delete(c.tracked, sample.id)
		}
	}
	c.resetSamples(stop)
}

func usageBucketLess(a, b UsageBucket) bool {
	if a.Minute != b.Minute {
		return a.Minute < b.Minute
	}
	if a.ProfileLabel != b.ProfileLabel {
		return a.ProfileLabel < b.ProfileLabel
	}
	if a.Route != b.Route {
		return a.Route < b.Route
	}
	if a.Node != b.Node {
		return a.Node < b.Node
	}
	if a.ProcessPath != b.ProcessPath {
		return a.ProcessPath < b.ProcessPath
	}
	if a.Host != b.Host {
		return a.Host < b.Host
	}
	return a.DestinationIP < b.DestinationIP
}

func copyUsageBatch(batch *UsageBatch) *UsageBatch {
	if batch == nil {
		return nil
	}
	copyBatch := *batch
	copyBatch.Buckets = append([]UsageBucket(nil), batch.Buckets...)
	return &copyBatch
}

func (c *usageCollector) readBatch() *UsageBatch {
	c.collect()
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.inFlight != nil {
		return copyUsageBatch(c.inFlight)
	}
	if len(c.pending) == 0 && len(c.overflow) == 0 && len(c.overflowFallback) == 0 {
		return nil
	}
	buckets := make([]UsageBucket, 0, min(len(c.pending)+len(c.overflow)+len(c.overflowFallback), usageBatchMaxBucketNum))
	for key, bucket := range c.pending {
		buckets = append(buckets, *bucket)
		delete(c.pending, key)
		if len(buckets) >= usageBatchMaxBucketNum {
			break
		}
	}
	degraded := false
	if len(buckets) < usageBatchMaxBucketNum {
		for key, bucket := range c.overflow {
			buckets = append(buckets, *bucket)
			delete(c.overflow, key)
			degraded = true
			if len(buckets) >= usageBatchMaxBucketNum {
				break
			}
		}
	}
	if len(buckets) < usageBatchMaxBucketNum {
		for route, bucket := range c.overflowFallback {
			buckets = append(buckets, *bucket)
			delete(c.overflowFallback, route)
			degraded = true
			if len(buckets) >= usageBatchMaxBucketNum {
				break
			}
		}
	}
	sort.Slice(buckets, func(i, j int) bool {
		return usageBucketLess(buckets[i], buckets[j])
	})
	degradedStart := int64(0)
	degradedEnd := int64(0)
	if degraded {
		degradedStart = c.degradedStart
		degradedEnd = c.degradedEnd
		if len(c.overflow) == 0 && len(c.overflowFallback) == 0 {
			c.degradedStart = 0
			c.degradedEnd = 0
		}
	}
	c.sequence++
	c.inFlight = &UsageBatch{
		SessionID:           c.session,
		Sequence:            c.sequence,
		Buckets:             buckets,
		Degraded:            degraded,
		DegradedStartMinute: degradedStart,
		DegradedEndMinute:   degradedEnd,
	}
	return copyUsageBatch(c.inFlight)
}

func (c *usageCollector) ackBatch(ack UsageBatchAck) bool {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.inFlight == nil {
		return false
	}
	if c.inFlight.SessionID != ack.SessionID || c.inFlight.Sequence != ack.Sequence {
		return false
	}
	c.inFlight = nil
	return true
}

func (c *usageCollector) run() {
	ticker := time.NewTicker(usageSampleInterval)
	defer ticker.Stop()
	for range ticker.C {
		c.collect()
	}
}

var usageStats = newUsageCollector()

func handleConfigureUsageCollection(params UsageCollectionParams) bool {
	return usageStats.configure(params)
}

func handleReadUsageBatch() *UsageBatch {
	return usageStats.readBatch()
}

func handleAckUsageBatch(ack UsageBatchAck) bool {
	return usageStats.ackBatch(ack)
}

func init() {
	for worker := 0; worker < usageProcessLookupWorkers; worker++ {
		go runUsageProcessLookupWorker()
	}
	go usageStats.run()
}
