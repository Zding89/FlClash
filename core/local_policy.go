package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"github.com/metacubex/mihomo/common/utils"
	"io"
	"net"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/metacubex/mihomo/adapter"
	"github.com/metacubex/mihomo/adapter/outbound"
	"github.com/metacubex/mihomo/config"
	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/tunnel"
	"gopkg.in/yaml.v3"
)

type LocalPolicyConfig struct {
	TargetID         string                  `json:"targetId" yaml:"targetId"`
	DocumentRevision *int64                  `json:"documentRevision,omitempty" yaml:"documentRevision,omitempty"`
	SchemaVersion    int                     `json:"schemaVersion" yaml:"schemaVersion"`
	Revision         int64                   `json:"revision" yaml:"revision"`
	Enabled          bool                    `json:"enabled" yaml:"enabled"`
	Sources          []LocalPolicySource     `json:"sources" yaml:"sources"`
	Nodes            []LocalPolicyNode       `json:"nodes" yaml:"nodes"`
	Budgets          []LocalPolicyBudget     `json:"budgets" yaml:"budgets"`
	Policies         []LocalPolicyDefinition `json:"policies" yaml:"policies"`
	NodeSets         []LocalNodeSet          `json:"nodeSets" yaml:"nodeSets"`
	Overrides        []LocalPolicyOverride   `json:"overrides" yaml:"overrides"`
}
type LocalPolicySource struct {
	ID             string `json:"id" yaml:"id"`
	Label          string `json:"label" yaml:"label"`
	ExpiresAt      *int64 `json:"expiresAt" yaml:"expiresAt"`
	RemainingBytes *int64 `json:"remainingBytes" yaml:"remainingBytes"`
	ObservedAt     *int64 `json:"observedAt" yaml:"observedAt"`
}
type LocalPolicySourceMetadata struct {
	ID             string `json:"id"`
	ExpiresAt      *int64 `json:"expiresAt"`
	RemainingBytes *int64 `json:"remainingBytes"`
	ObservedAt     *int64 `json:"observedAt"`
}
type LocalPolicySourceRefresh struct {
	Revision int64                     `json:"revision"`
	Sequence int64                     `json:"sequence"`
	Source   LocalPolicySourceMetadata `json:"source"`
}

func decodeLocalPolicySourceRefresh(data []byte) (LocalPolicySourceRefresh, error) {
	var input LocalPolicySourceRefresh
	if len(data) > 4096 {
		return input, errors.New("local_policy_source_invalid")
	}
	decoder := json.NewDecoder(bytes.NewReader(data))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&input); err != nil {
		return input, errors.New("local_policy_source_invalid")
	}
	var extra any
	if decoder.Decode(&extra) != io.EOF {
		return input, errors.New("local_policy_source_invalid")
	}
	var envelope map[string]json.RawMessage
	var source map[string]json.RawMessage
	_ = json.Unmarshal(data, &envelope)
	_ = json.Unmarshal(envelope["source"], &source)
	if _, ok := source["remainingBytes"]; !ok {
		return input, errors.New("local_policy_source_invalid")
	}
	if _, ok := source["observedAt"]; !ok {
		return input, errors.New("local_policy_source_invalid")
	}
	if revision, ok := envelope["revision"]; !ok || string(revision) == "null" {
		return input, errors.New("local_policy_source_invalid")
	}
	if input.Sequence <= 0 || input.Sequence > 9007199254740991 {
		return input, errors.New("local_policy_source_invalid")
	}
	return input, nil
}

func handleRefreshLocalPolicySource(input LocalPolicySourceRefresh) string {
	runLock.Lock()
	defer runLock.Unlock()
	engine := activeLocalPolicy.Load()
	if engine == nil {
		return "local_policy_source_inactive"
	}
	return engine.refreshSource(input)
}

func (e *localPolicyEngine) refreshSource(input LocalPolicySourceRefresh) string {
	s := input.Source
	if input.Revision < 0 || input.Revision > 9007199254740991 || input.Sequence <= 0 || input.Sequence > 9007199254740991 || len(s.ID) == 0 || len(s.ID) > 256 || strings.TrimSpace(s.ID) != s.ID {
		return "local_policy_source_invalid"
	}
	for _, value := range []*int64{s.ExpiresAt, s.RemainingBytes, s.ObservedAt} {
		if value != nil && (*value < 0 || *value > 9007199254740991) {
			return "local_policy_source_invalid"
		}
	}
	e.mu.Lock()
	if e.stopped {
		e.mu.Unlock()
		return "local_policy_source_inactive"
	}
	if e.config.Revision != input.Revision {
		e.mu.Unlock()
		return "local_policy_source_revision_conflict"
	}
	current, exists := e.sources[s.ID]
	if !exists {
		e.mu.Unlock()
		return "local_policy_source_missing"
	}
	if input.Sequence <= e.sourceSequences[s.ID] {
		e.mu.Unlock()
		return "local_policy_source_sequence_stale"
	}
	e.sourceSequences[s.ID] = input.Sequence
	if s.ObservedAt != nil && current.ObservedAt != nil && *s.ObservedAt < *current.ObservedAt {
		e.mu.Unlock()
		return "local_policy_source_observation_stale"
	}
	clone := func(value *int64) *int64 {
		if value == nil {
			return nil
		}
		copy := *value
		return &copy
	}
	if s.ExpiresAt != nil {
		current.ExpiresAt = clone(s.ExpiresAt)
	}
	if s.RemainingBytes != nil || current.RemainingBytes == nil || *current.RemainingBytes > 0 {
		current.RemainingBytes = clone(s.RemainingBytes)
	}
	current.ObservedAt = clone(s.ObservedAt)
	e.sources[s.ID] = current
	for index := range e.config.Sources {
		if e.config.Sources[index].ID == s.ID {
			e.config.Sources[index] = current
		}
	}
	now := e.now()
	for _, runtime := range e.policies {
		e.evaluateLocked(runtime, now)
	}
	var closers []localPolicyConnection
	localConnections.Lock()
	for _, connection := range localConnections.values {
		if e.nodes[connection.nodeID].SourceID != s.ID {
			continue
		}
		excluded := current.ExpiresAt != nil && *current.ExpiresAt > 0 && *current.ExpiresAt <= now.UnixMilli()
		if runtime := e.policies[connection.policyID]; runtime != nil && runtime.definition.TerminateConnectionsOnExclusion {
			excluded = excluded || e.sourceReasonLocked(connection.nodeID, runtime.definition, now) != ""
		}
		if excluded {
			closers = append(closers, connection)
		}
	}
	localConnections.Unlock()
	e.mu.Unlock()
	result := ""
	for _, connection := range closers {
		if err := connection.closer.Close(); err != nil {
			result = "local_policy_source_termination_failed"
			e.mu.Lock()
			if runtime := e.policies[connection.policyID]; runtime != nil {
				runtime.terminationError = "connection termination failed"
			}
			e.mu.Unlock()
		}
	}
	return result
}

type LocalPolicyNode struct {
	Label           string   `json:"label" yaml:"label"`
	ID              string   `json:"id" yaml:"id"`
	SourceID        string   `json:"sourceId" yaml:"sourceId"`
	ProxyName       string   `json:"proxyName" yaml:"proxyName"`
	Region          *string  `json:"region" yaml:"region"`
	Multiplier      *float64 `json:"multiplier" yaml:"multiplier"`
	RegionBasis     string   `json:"regionBasis" yaml:"regionBasis"`
	MultiplierBasis string   `json:"multiplierBasis" yaml:"multiplierBasis"`
}
type LocalPolicyBudget struct {
	SourceID   string `json:"sourceId" yaml:"sourceId"`
	LimitBytes int64  `json:"limitBytes" yaml:"limitBytes"`
	ResetDay   int    `json:"resetDay" yaml:"resetDay"`
	TimeZone   string `json:"timeZone" yaml:"timeZone"`
}
type LocalPolicyScheduleWindow struct {
	Weekdays    []int `json:"weekdays" yaml:"weekdays"`
	StartMinute int   `json:"startMinute" yaml:"startMinute"`
	EndMinute   int   `json:"endMinute" yaml:"endMinute"`
}
type LocalPolicySchedule struct {
	TimeZone string                      `json:"timeZone" yaml:"timeZone"`
	Windows  []LocalPolicyScheduleWindow `json:"windows" yaml:"windows"`
}
type LocalPolicyProbe struct {
	Method           string `json:"method" yaml:"method"`
	Automatic        *bool  `json:"automatic" yaml:"automatic"`
	RetrySeconds     int    `json:"retrySeconds" yaml:"retrySeconds"`
	ValiditySeconds  int    `json:"validitySeconds" yaml:"validitySeconds"`
	ExpectedStatus   string `json:"expectedStatus" yaml:"expectedStatus"`
	URL              string `json:"url" yaml:"url"`
	IntervalSeconds  int    `json:"intervalSeconds" yaml:"intervalSeconds"`
	TimeoutSeconds   int    `json:"timeoutSeconds" yaml:"timeoutSeconds"`
	FailureThreshold int    `json:"failureThreshold" yaml:"failureThreshold"`
	SuccessThreshold int    `json:"successThreshold" yaml:"successThreshold"`
}
type LocalPolicyGuard struct {
	ExpiryMarginSeconds   int64  `json:"expiryMarginSeconds" yaml:"expiryMarginSeconds"`
	MinRemainingBytes     int64  `json:"minRemainingBytes" yaml:"minRemainingBytes"`
	MetadataMaxAgeSeconds int64  `json:"metadataMaxAgeSeconds" yaml:"metadataMaxAgeSeconds"`
	UnknownBehavior       string `json:"unknownBehavior" yaml:"unknownBehavior"`
}
type LocalPolicyDefinition struct {
	Action                          string               `json:"action" yaml:"action"`
	SkipUnavailable                 *bool                `json:"skipUnavailable" yaml:"skipUnavailable"`
	Schedule                        *LocalPolicySchedule `json:"schedule" yaml:"schedule"`
	ID                              string               `json:"id" yaml:"id"`
	Label                           string               `json:"label" yaml:"label"`
	Enabled                         bool                 `json:"enabled" yaml:"enabled"`
	GroupName                       string               `json:"groupName" yaml:"groupName"`
	Choices                         []LocalPolicyChoice  `json:"choices" yaml:"choices"`
	CandidateNodeIDs                []string             `json:"candidateNodeIds" yaml:"candidateNodeIds"`
	Probe                           LocalPolicyProbe     `json:"probe" yaml:"probe"`
	Guard                           LocalPolicyGuard     `json:"guard" yaml:"guard"`
	RecoverySeconds                 int                  `json:"recoverySeconds" yaml:"recoverySeconds"`
	CooldownSeconds                 int                  `json:"cooldownSeconds" yaml:"cooldownSeconds"`
	AutoRecover                     bool                 `json:"autoRecover" yaml:"autoRecover"`
	Fallback                        string               `json:"fallback" yaml:"fallback"`
	TerminateConnectionsOnExclusion bool                 `json:"terminateConnectionsOnExclusion" yaml:"terminateConnectionsOnExclusion"`
}
type LocalPolicyOverride struct {
	PolicyID  string `json:"policyId" yaml:"policyId"`
	NodeID    string `json:"nodeId" yaml:"nodeId"`
	NodeSetID string `json:"nodeSetId,omitempty" yaml:"nodeSetId,omitempty"`
	ExpiresAt int64  `json:"expiresAt" yaml:"expiresAt"`
}

func parseLocalPolicyConfig(data []byte) (*LocalPolicyConfig, error) {
	if len(data) > 32*1024*1024 {
		return nil, errors.New("configuration exceeds 32 MiB")
	}
	var document yaml.Node
	if err := yaml.Unmarshal(data, &document); err != nil {
		return nil, err
	}
	if len(document.Content) == 0 {
		return nil, nil
	}
	root := document.Content[0]
	for i := 0; i+1 < len(root.Content); i += 2 {
		if root.Content[i].Value != "flclash-local-policy" {
			continue
		}
		raw, err := yaml.Marshal(root.Content[i+1])
		if err != nil {
			return nil, err
		}
		decoder := yaml.NewDecoder(bytes.NewReader(raw))
		decoder.KnownFields(true)
		var cfg LocalPolicyConfig
		if err = decoder.Decode(&cfg); err != nil {
			return nil, fmt.Errorf("local policy: %w", err)
		}
		if err = validateLocalPolicyConfig(&cfg); err != nil {
			return nil, err
		}
		return &cfg, nil
	}
	return nil, nil
}

func validateLocalPolicyConfig(c *LocalPolicyConfig) error {
	fail := func(message string) error { return fmt.Errorf("local policy: %s", message) }
	if (c.SchemaVersion != 1 && c.SchemaVersion != 2 && c.SchemaVersion != 3) || c.Revision < 0 || (c.DocumentRevision != nil && *c.DocumentRevision < 0) {
		return fail("unsupported schema or invalid revision")
	}
	if len(c.Sources) > 20 || len(c.Nodes) > 5000 || len(c.Policies) > 100 || len(c.Budgets) > 20 || len(c.Overrides) > 100 {
		return fail("capacity exceeded")
	}
	sources := map[string]bool{}
	nodes := map[string]LocalPolicyNode{}
	names := map[string]bool{}
	groups := map[string]bool{}
	policies := map[string]LocalPolicyDefinition{}
	validID := func(id string) bool { return len(id) > 0 && len(id) <= 256 && strings.TrimSpace(id) == id }
	for _, s := range c.Sources {
		if !validID(s.ID) || sources[s.ID] || len(s.Label) > 1024 {
			return fail("invalid or duplicate source")
		}
		sources[s.ID] = true
		if (s.RemainingBytes != nil && *s.RemainingBytes < 0) || (s.ExpiresAt != nil && *s.ExpiresAt < 0) || (s.ObservedAt != nil && *s.ObservedAt < 0) {
			return fail("negative source metadata")
		}
	}
	for _, n := range c.Nodes {
		if !validID(n.ID) || nodes[n.ID].ID != "" || !sources[n.SourceID] || !validID(n.ProxyName) || names[n.ProxyName] || len(n.Label) > 1024 {
			return fail("invalid or duplicate node identity")
		}
		nodes[n.ID] = n
		names[n.ProxyName] = true
	}
	budgetSources := map[string]bool{}
	for _, b := range c.Budgets {
		if !sources[b.SourceID] || budgetSources[b.SourceID] || b.LimitBytes < 0 || b.ResetDay < 1 || b.ResetDay > 28 || (b.TimeZone != "Asia/Shanghai" && b.TimeZone != "UTC") {
			return fail("invalid budget (resetDay 1..28, Asia/Shanghai required)")
		}
		budgetSources[b.SourceID] = true
	}
	for _, p := range c.Policies {
		if !validID(p.ID) || policies[p.ID].ID != "" || !validID(p.GroupName) || groups[p.GroupName] || names[p.GroupName] || len(p.Label) > 1024 {
			return fail("invalid or duplicate policy/group")
		}
		if p.Action != "" && p.Action != "proxy" && p.Action != "direct" && p.Action != "reject" || c.SchemaVersion == 3 && (p.SkipUnavailable == nil || !*p.SkipUnavailable) {
			return fail("invalid policy action or skip behavior")
		}
		if (localPolicyAction(p) == "proxy" && len(p.CandidateNodeIDs) == 0 && len(p.Choices) == 0) || len(p.CandidateNodeIDs) > 10 || len(p.Choices) > 10 || (len(p.CandidateNodeIDs) > 0 && len(p.Choices) > 0) {
			return fail("candidate count must be 1..10")
		}
		seen := map[string]bool{}
		for _, id := range p.CandidateNodeIDs {
			if !validID(id) || seen[id] {
				return fail("missing or duplicate candidate")
			}
			seen[id] = true
		}
		if !validLocalSchedule(p.Schedule) {
			return fail("invalid schedule")
		}
		if localPolicyAction(p) != "proxy" {
			policies[p.ID] = p
			groups[p.GroupName] = true
			continue
		}
		expected := p.Probe.ExpectedStatus
		if expected == "" {
			expected = "200-399"
		}
		ranges, rangeErr := utils.NewUnsignedRanges[uint16](expected)
		if rangeErr != nil || len(ranges) == 0 {
			return fail("invalid expected probe status")
		}
		validStatus := true
		ranges.Range(func(value uint16) bool {
			if value < 100 || value > 599 {
				validStatus = false
			}
			return validStatus
		})
		if !validStatus {
			return fail("invalid expected probe status")
		}
		u, err := url.Parse(p.Probe.URL)
		if err != nil || len(p.Probe.URL) > 4096 || (u.Scheme != "http" && u.Scheme != "https") || u.Hostname() == "" || u.User != nil {
			return fail("invalid probe URL")
		}
		if p.Probe.IntervalSeconds < 1 || p.Probe.IntervalSeconds > 86400 || p.Probe.TimeoutSeconds < 1 || p.Probe.TimeoutSeconds > 60 || p.Probe.TimeoutSeconds > p.Probe.IntervalSeconds || p.Probe.FailureThreshold < 1 || p.Probe.FailureThreshold > 100 || p.Probe.SuccessThreshold < 1 || p.Probe.SuccessThreshold > 100 {
			return fail("invalid probe limits")
		}
		if p.RecoverySeconds < 0 || p.RecoverySeconds > 604800 || p.CooldownSeconds < 0 || p.CooldownSeconds > 604800 || p.Guard.ExpiryMarginSeconds < 0 || p.Guard.ExpiryMarginSeconds > 31536000 || p.Guard.MinRemainingBytes < 0 || p.Guard.MetadataMaxAgeSeconds < 0 || p.Guard.MetadataMaxAgeSeconds > 31536000 || (p.Guard.UnknownBehavior != "allow" && p.Guard.UnknownBehavior != "exclude") || (c.SchemaVersion < 3 && p.Fallback != "reject" && p.Fallback != "direct") {
			return fail("invalid policy guard/recovery/fallback")
		}
		policies[p.ID] = p
		groups[p.GroupName] = true
	}
	overrides := map[string]bool{}
	for _, o := range c.Overrides {
		p := policies[o.PolicyID]
		if p.ID == "" || !validID(o.NodeID) || o.NodeSetID != "" && !validID(o.NodeSetID) || overrides[o.PolicyID] || o.ExpiresAt <= 0 {
			return fail("invalid override")
		}
		overrides[o.PolicyID] = true
	}
	return validateLocalNodeSets(c)
}

type localNodeHealth struct {
	checkSequence uint64
	healthy       bool
	recovering    bool
	failures      int
	successes     int
	healthySince  time.Time
	lastProbe     time.Time
	nextProbe     time.Time
	pending       bool
	latencyMillis *int64
}
type LocalPolicyHistory struct {
	At     int64  `json:"at"`
	NodeID string `json:"nodeId"`
	Reason string `json:"reason"`
}
type LocalPolicyNodeStatus struct {
	FixedEligible    *bool  `json:"fixedEligible,omitempty"`
	ProbePending     bool   `json:"probePending"`
	DetectionDelayed bool   `json:"detectionDelayed"`
	NodeID           string `json:"nodeId"`
	Eligible         bool   `json:"eligible"`
	Reason           string `json:"reason"`
	Healthy          bool   `json:"healthy"`
	LastProbeAt      *int64 `json:"lastProbeAt"`
	LatencyMillis    *int64 `json:"latencyMillis"`
}
type LocalPolicyStatus struct {
	ActiveNodeCount int      `json:"activeNodeCount,omitempty"`
	SelectionMode   string   `json:"selectionMode,omitempty"`
	ActiveNodeIDs   []string `json:"activeNodeIds,omitempty"`
	LocalPolicyCounts
	TerminationError string                  `json:"terminationError,omitempty"`
	PolicyID         string                  `json:"policyId"`
	GroupName        string                  `json:"groupName"`
	SelectedNodeID   string                  `json:"selectedNodeId"`
	State            string                  `json:"state"`
	Reason           string                  `json:"reason"`
	UpdatedAt        int64                   `json:"updatedAt"`
	History          []LocalPolicyHistory    `json:"history"`
	Nodes            []LocalPolicyNodeStatus `json:"nodes"`
}
type LocalBudgetStatus struct {
	SourceID    string `json:"sourceId"`
	PeriodStart int64  `json:"periodStart"`
	UsedBytes   int64  `json:"usedBytes"`
	LimitBytes  int64  `json:"limitBytes"`
	Trusted     bool   `json:"trusted"`
}
type LocalPolicySnapshot struct {
	TargetID                     string              `json:"targetId"`
	DocumentRevision             int64               `json:"documentRevision"`
	Revision                     int64               `json:"revision"`
	Enabled                      bool                `json:"enabled"`
	Policies                     []LocalPolicyStatus `json:"policies"`
	Budgets                      []LocalBudgetStatus `json:"budgets"`
	PersistenceError             string              `json:"persistenceError"`
	ChecksInFlight               int                 `json:"checksInFlight"`
	ChecksWaiting                int                 `json:"checksWaiting"`
	CheckTaskCount               int                 `json:"checkTaskCount"`
	MaxCheckTimeoutSeconds       int                 `json:"maxCheckTimeoutSeconds"`
	RecommendedCheckCycleSeconds int                 `json:"recommendedCheckCycleSeconds"`
	NodeSets                     []LocalPolicyStatus `json:"nodeSets"`
}
type localPolicyRuntime struct {
	network           C.NetWork
	udpSelection      *localPolicyRuntime
	activeNodeIDs     []string
	selectionMode     string
	balanceStrategy   string
	balanceCursor     uint64
	terminationError  string
	definition        LocalPolicyDefinition
	setID             string
	selectedChoice    int
	choiceSelections  map[int]*localPolicyRuntime
	optimizationNode  string
	optimizationSince time.Time
	recoveryNode      string
	recoveryChoice    int
	recoverySince     time.Time
	health            map[string]*localNodeHealth
	selected          string
	reason            string
	updated           time.Time
	switched          time.Time
	history           []LocalPolicyHistory
}

var localConnections = struct {
	sync.Mutex
	next   uint64
	values map[uint64]localPolicyConnection
}{values: map[uint64]localPolicyConnection{}}

type localPolicyConnection struct {
	nodeID   string
	policyID string
	closer   io.Closer
}
type localProbeKey struct {
	nodeID  string
	method  string
	url     string
	status  string
	timeout int
	unknown string
}
type localProbeCandidate struct {
	runtime *localPolicyRuntime
	nodeID  string
}
type localPolicyEngine struct {
	mu                   sync.Mutex
	config               LocalPolicyConfig
	sources              map[string]LocalPolicySource
	sourceSequences      map[string]int64
	nodes                map[string]LocalPolicyNode
	proxies              map[string]C.Proxy
	policies             map[string]*localPolicyRuntime
	sets                 map[string]*localPolicyRuntime
	setDefinitions       map[string]LocalNodeSet
	ledger               *localBudgetLedger
	now                  func() time.Time
	probe                func(context.Context, C.Proxy, LocalPolicyProbe) error
	ctx                  context.Context
	cancel               context.CancelFunc
	wg                   sync.WaitGroup
	workers              int
	lastTick             time.Time
	probeCursor          int
	priorityStarts       int
	priorityCursor       int
	inFlight             map[localProbeKey][]localProbeCandidate
	epoch                uint64
	checks               map[string]*localPolicyCheck
	healthPool           map[localHealthKey]*localNodeHealth
	nodeIdentities       map[string][32]byte
	evaluatedSets        map[string]bool
	selectionRoundActive bool
	stopped              bool
}

type localPolicyAdmissionKey struct{}

func localUnknownBehavior(ctx context.Context) string {
	if behavior, ok := ctx.Value(localPolicyAdmissionKey{}).(string); ok {
		return behavior
	}
	return "exclude"
}

var activeLocalPolicy atomic.Pointer[localPolicyEngine]

func localConcreteProxy(proxy C.Proxy) bool {
	if proxy == nil || proxy.ProxyInfo().DialerProxy != "" {
		return false
	}
	switch proxy.Type() {
	case C.Direct, C.Reject, C.RejectDrop, C.Compatible, C.Pass, C.PassRule, C.Rematch, C.Dns, C.Relay, C.Selector, C.Fallback, C.URLTest, C.LoadBalance:
		return false
	}
	return true
}

func prepareLocalPolicy(c *LocalPolicyConfig, cfg *config.Config, ledger *localBudgetLedger) (*localPolicyEngine, error) {
	if c == nil || !c.Enabled {
		return nil, nil
	}
	if controller := cfg.Controller; controller != nil && (controller.ExternalController != "" || controller.ExternalControllerTLS != "" || controller.ExternalControllerUnix != "" || controller.ExternalControllerPipe != "") {
		return nil, errors.New("local policy requires all external controllers to be disabled")
	}
	if ledger != nil && !ledger.canConfigure(c.Budgets) {
		return nil, errors.New("local budget history capacity exceeded")
	}
	managed := false
	for _, p := range c.Policies {
		if p.Enabled {
			managed = true
		}
	}
	if managed && cfg.General.Mode != tunnel.Rule {
		return nil, errors.New("local policy requires rule mode")
	}
	e := &localPolicyEngine{config: *c, sources: map[string]LocalPolicySource{}, sourceSequences: map[string]int64{}, nodes: map[string]LocalPolicyNode{}, proxies: map[string]C.Proxy{}, policies: map[string]*localPolicyRuntime{}, inFlight: map[localProbeKey][]localProbeCandidate{}, ledger: ledger, now: time.Now}
	e.ctx, e.cancel = context.WithCancel(context.Background())
	e.probe = probeLocalPolicyNode
	for _, s := range c.Sources {
		e.sources[s.ID] = s
	}
	for _, n := range c.Nodes {
		p := cfg.Proxies[n.ProxyName]
		if p == nil {
			e.nodes[n.ID] = n
			continue
		}
		if !localConcreteProxy(p) {
			e.cancel()
			return nil, fmt.Errorf("local policy node %s is missing or is not an independent static leaf", n.ID)
		}
		if _, ok := p.(*adapter.Proxy); !ok {
			e.cancel()
			return nil, fmt.Errorf("local policy node %s adapter cannot be guarded", n.ID)
		}
		e.nodes[n.ID] = n
		e.proxies[n.ID] = p
	}
	e.retainBoundOverrides(c)
	if err := e.prepareNodeSets(c); err != nil {
		e.cancel()
		return nil, err
	}
	for _, p := range c.Policies {
		if !p.Enabled {
			continue
		}
		if target, ok := cfg.Proxies[p.GroupName].(*adapter.Proxy); !ok || target.Type() != C.Selector {
			e.cancel()
			return nil, fmt.Errorf("local policy group %s is missing or not select", p.GroupName)
		}
		r := &localPolicyRuntime{definition: p, health: map[string]*localNodeHealth{}}
		for _, id := range localFixedCandidates(p) {
			r.health[id] = e.sharedHealthLocked(r, id)
		}
		e.policies[p.ID] = r
	}
	return e, nil
}

func (e *localPolicyEngine) install(cfg *config.Config) {
	for _, n := range e.config.Nodes {
		p, ok := cfg.Proxies[n.ProxyName].(*adapter.Proxy)
		if !ok {
			continue
		}
		p.ProxyAdapter = &localSourceAdapter{ProxyAdapter: p.ProxyAdapter, engine: e, node: e.nodes[n.ID]}
	}
	for _, p := range e.config.Policies {
		if !p.Enabled {
			continue
		}
		target := cfg.Proxies[p.GroupName].(*adapter.Proxy)
		target.ProxyAdapter = &localManagedAdapter{Base: outbound.NewBase(outbound.BaseOption{Name: p.GroupName, Type: C.Selector, UDP: true}), engine: e, policyID: p.ID, direct: cfg.Proxies["DIRECT"]}
	}
}

func (e *localPolicyEngine) sourceReasonLocked(nodeID string, p LocalPolicyDefinition, now time.Time) string {
	n, ok := e.nodes[nodeID]
	if !ok || e.proxies[nodeID] == nil {
		return "missing_node"
	}
	s := e.sources[n.SourceID]
	if s.ExpiresAt != nil && *s.ExpiresAt > 0 && *s.ExpiresAt-now.UnixMilli() <= p.Guard.ExpiryMarginSeconds*1000 {
		return "source_expiring"
	}
	if s.RemainingBytes != nil && *s.RemainingBytes <= p.Guard.MinRemainingBytes {
		return "source_remaining"
	}
	if reason := e.ledger.reason(n.SourceID, now, p.Guard.UnknownBehavior); reason != "" {
		return reason
	}
	needsMetadata := p.Guard.ExpiryMarginSeconds > 0 || p.Guard.MinRemainingBytes > 0
	unknown := (p.Guard.ExpiryMarginSeconds > 0 && s.ExpiresAt == nil) || (p.Guard.MinRemainingBytes > 0 && s.RemainingBytes == nil) || (needsMetadata && s.ObservedAt == nil)
	stale := needsMetadata && s.ObservedAt != nil && (*s.ObservedAt > now.UnixMilli()+60000 || (p.Guard.MetadataMaxAgeSeconds > 0 && now.UnixMilli()-*s.ObservedAt > p.Guard.MetadataMaxAgeSeconds*1000))
	if p.Guard.UnknownBehavior == "exclude" {
		if stale {
			return "metadata_stale"
		}
		if unknown {
			return "metadata_unknown"
		}
	}
	return ""
}
func (e *localPolicyEngine) requestNodeReasonLocked(r *localPolicyRuntime, id string) string {
	if r.network == C.UDP && e.proxies[id] != nil && !e.proxies[id].SupportUDP() {
		return "udp_unsupported"
	}
	return ""
}

func (e *localPolicyEngine) nodeReasonLocked(r *localPolicyRuntime, id string, now time.Time) string {
	if reason := e.requestNodeReasonLocked(r, id); reason != "" {
		return reason
	}
	if r.setID != "" && !localPolicyScheduleActive(e.setDefinitions[r.setID].Schedule, now) {
		return "schedule_inactive"
	}
	if reason := e.sourceReasonLocked(id, r.definition, now); reason != "" {
		return reason
	}
	h := r.health[id]
	if h == nil {
		return "missing_node"
	}
	if h.healthy && r.definition.Probe.ValiditySeconds > 0 && now.Sub(h.lastProbe) >= time.Duration(r.definition.Probe.ValiditySeconds)*time.Second {
		return "probe_expired"
	}
	if !h.healthy {
		if h.lastProbe.IsZero() {
			return "probing"
		}
		return "unhealthy"
	}
	return ""
}
func (e *localPolicyEngine) evaluateLocked(r *localPolicyRuntime, now time.Time) {
	if selection := r.udpSelection; selection != nil {
		selection.definition, selection.health = r.definition, r.health
		defer e.evaluateLocked(selection, now)
	}
	if localPolicyAction(r.definition) != "proxy" {
		r.activeNodeIDs = nil
		reason := localPolicyAction(r.definition)
		if !localPolicyScheduleActive(r.definition.Schedule, now) {
			reason = "schedule_inactive"
		}
		e.recordSelectionLocked(r, "", reason, now)
		return
	}
	if r.setID != "" {
		e.evaluateSetLocked(r, now)
		return
	}
	if len(r.definition.Choices) > 0 {
		e.evaluateChoicesLocked(r, now)
		return
	}
	old := r.selected
	for _, id := range r.definition.CandidateNodeIDs {
		_ = e.nodeReasonLocked(r, id, now)
	}
	if !localPolicyScheduleActive(r.definition.Schedule, now) {
		changed := old != "" || r.reason != "schedule_inactive"
		r.selected = ""
		r.reason = "schedule_inactive"
		if changed {
			r.updated = now
			r.history = append(r.history, LocalPolicyHistory{At: now.UnixMilli(), Reason: r.reason})
			if len(r.history) > 64 {
				r.history = r.history[len(r.history)-64:]
			}
		}
		return
	}
	currentValid := old != "" && e.nodeReasonLocked(r, old, now) == ""
	desired := ""
	reason := "no_eligible_candidates"
	for _, o := range e.config.Overrides {
		if o.PolicyID == r.definition.ID && o.NodeSetID == "" && localContains(r.definition.CandidateNodeIDs, o.NodeID) && o.ExpiresAt > now.UnixMilli() && e.nodeReasonLocked(r, o.NodeID, now) == "" {
			desired = o.NodeID
			reason = "manual_override"
			break
		}
	}
	if desired == "" {
		for _, id := range r.definition.CandidateNodeIDs {
			if e.nodeReasonLocked(r, id, now) == "" {
				desired = id
				reason = "strict_order"
				break
			}
		}
		if currentValid && desired != old && r.reason != "manual_override" {
			h := r.health[desired]
			if !r.definition.AutoRecover || now.Sub(r.switched) < time.Duration(r.definition.CooldownSeconds)*time.Second || (h != nil && now.Sub(h.healthySince) < time.Duration(r.definition.RecoverySeconds)*time.Second) {
				desired = old
				reason = "recovery_hold"
			}
		}
	}
	if old != desired || r.reason != reason {
		r.selected = desired
		r.reason = reason
		r.updated = now
		if old != desired {
			r.switched = now
		}
		r.history = append(r.history, LocalPolicyHistory{At: now.UnixMilli(), NodeID: desired, Reason: reason})
		if len(r.history) > 64 {
			r.history = append([]LocalPolicyHistory(nil), r.history[len(r.history)-64:]...)
		}
	}
}

func (e *localPolicyEngine) selectProxy(policyID string) (C.Proxy, string, error) {
	return e.selectProxyForRequest(policyID, nil, false)
}

func (e *localPolicyEngine) selectProxyForRequest(policyID string, metadata *C.Metadata, allocate bool) (C.Proxy, string, error) {
	e.mu.Lock()
	defer e.mu.Unlock()
	if e.stopped {
		return nil, "", errors.New("local policy stopped")
	}
	r := e.policies[policyID]
	if r == nil {
		return nil, "", errors.New("local policy missing")
	}
	owner := r
	if metadata != nil && metadata.NetWork == C.UDP {
		if r.udpSelection == nil {
			r.udpSelection = &localPolicyRuntime{network: C.UDP}
		}
		selection := r.udpSelection
		selection.definition, selection.health = r.definition, r.health
		selection.balanceCursor = r.balanceCursor
		r = selection
	}
	defer e.beginSelectionRoundLocked()()
	e.evaluateLocked(r, e.now())
	if !localPolicyScheduleActive(r.definition.Schedule, e.now()) {
		return nil, "", errors.New("local policy schedule inactive")
	}
	if localPolicyAction(r.definition) == "direct" {
		return nil, "", nil
	}
	if localPolicyAction(r.definition) == "reject" {
		return nil, "", errors.New("local policy rejected by explicit action")
	}
	if r.selectionMode == "loadBalance" && len(r.activeNodeIDs) > 0 {
		r.selected = localBalancedNode(r, metadata, allocate)
		owner.balanceCursor = r.balanceCursor
	}
	if r.selected == "" {
		if !localPolicySkipsUnavailable(e.config, r.definition) && r.definition.Fallback == "direct" {
			return nil, "", nil
		}
		return nil, "", errors.New("local policy rejected: no eligible candidate")
	}
	return e.proxies[r.selected], r.selected, nil
}
func (e *localPolicyEngine) register(policyID, nodeID string, closer io.Closer) (uint64, error) {
	e.mu.Lock()
	defer e.mu.Unlock()
	if e.stopped {
		return 0, errors.New("local policy stopped")
	}
	if source := e.sources[e.nodes[nodeID].SourceID]; (source.ExpiresAt != nil && *source.ExpiresAt > 0 && *source.ExpiresAt <= e.now().UnixMilli()) || (source.RemainingBytes != nil && *source.RemainingBytes <= 0) {
		return 0, errors.New("local source rejected: source_expired")
	}
	if policyID != "" && (!localPolicyScheduleActive(e.policies[policyID].definition.Schedule, e.now()) || e.policyNodeReasonLocked(e.policies[policyID], nodeID, e.now()) != "") {
		return 0, errors.New("local policy candidate excluded during dial")
	}
	localConnections.Lock()
	defer localConnections.Unlock()
	if len(localConnections.values) >= 20000 {
		return 0, errors.New("local policy connection capacity exceeded")
	}
	localConnections.next++
	localConnections.values[localConnections.next] = localPolicyConnection{nodeID: nodeID, policyID: policyID, closer: closer}
	return localConnections.next, nil
}
func (e *localPolicyEngine) unregister(id uint64) {
	localConnections.Lock()
	delete(localConnections.values, id)
	localConnections.Unlock()
}

func (e *localPolicyEngine) tick() {
	now := e.now()
	e.mu.Lock()
	if e.stopped {
		e.mu.Unlock()
		return
	}
	if !e.lastTick.IsZero() && now.Sub(e.lastTick) > 5*time.Second {
		e.epoch++
		for _, r := range e.checkRuntimes() {
			for _, h := range r.health {
				h.healthy = false
				h.failures = 0
				h.successes = 0
				h.healthySince = time.Time{}
				h.nextProbe = now
				h.recovering = false
			}
		}
	}
	e.lastTick = now
	finishRound := e.beginSelectionRoundLocked()
	var closeList []localPolicyConnection
	for _, r := range e.checkRuntimes() {
		e.evaluateLocked(r, now)
	}
	localConnections.Lock()
	for _, connection := range localConnections.values {
		r := e.policies[connection.policyID]
		if r != nil && r.definition.TerminateConnectionsOnExclusion && e.sourceReasonLocked(connection.nodeID, r.definition, now) != "" {
			closeList = append(closeList, connection)
		}
	}
	localConnections.Unlock()
	candidates := make([]localProbeCandidate, 0, len(e.nodes))
	queuedHealth := map[*localNodeHealth]bool{}
	for _, r := range e.checkRuntimes() {
		for _, id := range localFixedCandidates(r.definition) {
			if r.definition.Probe.Automatic != nil && !*r.definition.Probe.Automatic && !e.manualCheckNeeded(r, id) {
				continue
			}
			health := r.health[id]
			if queuedHealth[health] {
				continue
			}
			queuedHealth[health] = true
			candidates = append(candidates, localProbeCandidate{runtime: r, nodeID: id})
		}
	}
	e.startProbesLocked(candidates, now)

	finishRound()
	e.mu.Unlock()
	for _, connection := range closeList {
		if err := connection.closer.Close(); err != nil {
			e.mu.Lock()
			if r := e.policies[connection.policyID]; r != nil {
				r.terminationError = "connection termination failed"
			}
			e.mu.Unlock()
		}
	}
	e.ledger.save(false)
}
func (e *localPolicyEngine) applyProbeLocked(r *localPolicyRuntime, id string, err error, now time.Time) {
	h := r.health[id]
	h.lastProbe = now
	h.checkSequence++
	interval := r.definition.Probe.IntervalSeconds
	if err != nil && r.definition.Probe.RetrySeconds > 0 {
		interval = r.definition.Probe.RetrySeconds
	}
	h.nextProbe = now.Add(time.Duration(interval) * time.Second)
	if err != nil {
		h.failures++
		h.successes = 0
		h.healthySince = time.Time{}
		if h.failures >= r.definition.Probe.FailureThreshold {
			h.healthy = false
			h.recovering = true
		}
	} else {
		h.failures = 0
		h.successes++
		if h.healthySince.IsZero() {
			h.healthySince = now
		}
		if h.successes >= r.definition.Probe.SuccessThreshold && (!h.recovering || now.Sub(h.healthySince) >= time.Duration(r.definition.RecoverySeconds)*time.Second) {
			h.healthy = true
			h.recovering = false
		}
	}
	defer e.beginSelectionRoundLocked()()
	e.evaluateLocked(r, now)
}
func (e *localPolicyEngine) runProbe(r *localPolicyRuntime, id string, proxy C.Proxy) {
	defer e.wg.Done()
	ctx, cancel := context.WithTimeout(e.ctx, time.Duration(r.definition.Probe.TimeoutSeconds)*time.Second)
	defer cancel()
	ctx = context.WithValue(ctx, localPolicyAdmissionKey{}, r.definition.Guard.UnknownBehavior)
	err := e.probe(ctx, proxy, r.definition.Probe)
	e.mu.Lock()
	defer e.mu.Unlock()
	e.workers--
	r.health[id].pending = false
	if e.stopped || e.ctx.Err() != nil {
		return
	}
	e.applyProbeLocked(r, id, err, e.now())
}
func (e *localPolicyEngine) runSharedProbe(key localProbeKey, proxy C.Proxy, epoch uint64) {
	defer e.wg.Done()
	ctx, cancel := context.WithTimeout(e.ctx, time.Duration(key.timeout)*time.Second)
	defer cancel()
	ctx = context.WithValue(ctx, localPolicyAdmissionKey{}, key.unknown)
	started := e.now()
	err := e.probe(ctx, proxy, LocalPolicyProbe{Method: key.method, URL: key.url, ExpectedStatus: key.status, TimeoutSeconds: key.timeout})
	e.mu.Lock()
	defer e.mu.Unlock()
	e.workers--
	candidates := e.inFlight[key]
	delete(e.inFlight, key)
	now := e.now()
	for _, candidate := range candidates {
		candidate.runtime.health[candidate.nodeID].pending = false
	}
	if e.stopped || e.ctx.Err() != nil || epoch != e.epoch || now.UnixMilli()-started.UnixMilli() > int64(key.timeout+5)*1000 {
		return
	}
	seen := map[*localNodeHealth]bool{}
	for _, candidate := range candidates {
		h := candidate.runtime.health[candidate.nodeID]
		if seen[h] {
			continue
		}
		seen[h] = true
		if err == nil {
			elapsed := now.Sub(started).Milliseconds()
			candidate.runtime.health[candidate.nodeID].latencyMillis = &elapsed
		} else {
			candidate.runtime.health[candidate.nodeID].latencyMillis = nil
		}
		e.applyProbeLocked(candidate.runtime, candidate.nodeID, err, now)
	}
}
func (e *localPolicyEngine) start() {
	e.wg.Add(1)
	go func() {
		defer e.wg.Done()
		ticker := time.NewTicker(time.Second)
		defer ticker.Stop()
		e.tick()
		for {
			select {
			case <-e.ctx.Done():
				return
			case <-ticker.C:
				e.tick()
			}
		}
	}()
}
func (e *localPolicyEngine) stop() {
	e.mu.Lock()
	if e.stopped {
		e.mu.Unlock()
		return
	}
	e.stopped = true
	e.cancel()
	e.mu.Unlock()
	e.wg.Wait()
	e.ledger.save(false)
}
func (e *localPolicyEngine) snapshot() LocalPolicySnapshot {
	e.mu.Lock()
	defer e.mu.Unlock()
	now := e.now()
	defer e.beginSelectionRoundLocked()()
	documentRevision := e.config.Revision
	if e.config.DocumentRevision != nil {
		documentRevision = *e.config.DocumentRevision
	}
	result := LocalPolicySnapshot{TargetID: e.config.TargetID, DocumentRevision: documentRevision, Revision: e.config.Revision, Enabled: !e.stopped, Policies: []LocalPolicyStatus{}, Budgets: e.ledger.status(now), PersistenceError: e.ledger.errorMessage()}
	for _, p := range e.config.Policies {
		r := e.policies[p.ID]
		if r == nil {
			continue
		}
		e.evaluateLocked(r, now)
		state := "active"
		if r.selected == "" {
			state = p.Fallback
		}
		if localPolicyAction(p) != "proxy" {
			state = localPolicyAction(p)
		}
		if r.reason == "schedule_inactive" || localPolicyAction(p) == "proxy" && r.selected == "" && localPolicySkipsUnavailable(e.config, p) {
			state = "skipped"
		}
		status := LocalPolicyStatus{TerminationError: r.terminationError, PolicyID: p.ID, GroupName: p.GroupName, SelectedNodeID: r.selected, State: state, Reason: r.reason, UpdatedAt: r.updated.UnixMilli(), History: localBoundedHistory(r.history), Nodes: []LocalPolicyNodeStatus{}}
		localSelectionStatus(&status, r)
		ids := append([]string{}, localFixedCandidates(p)...)
		if r.selected != "" && !localContains(ids, r.selected) {
			ids = append(ids, r.selected)
		}
		for _, id := range ids {
			status.Nodes = append(status.Nodes, e.nodeStatusLocked(r, id, now))
		}
		result.Policies = append(result.Policies, status)
	}
	e.addSetSnapshotsLocked(&result, now)
	tasks := map[localProbeKey]bool{}
	maxWait := 0
	for _, runtime := range e.checkRuntimes() {
		for _, id := range localFixedCandidates(runtime.definition) {
			tasks[localNetworkProbeKey(runtime, id)] = true
			probe := runtime.definition.Probe
			result.MaxCheckTimeoutSeconds = max(result.MaxCheckTimeoutSeconds, probe.TimeoutSeconds)
			maxWait = max(maxWait, probe.IntervalSeconds, probe.RetrySeconds)
		}
	}
	result.CheckTaskCount = len(tasks)
	if result.CheckTaskCount > 0 {
		seconds := ((result.CheckTaskCount+7)/8)*(result.MaxCheckTimeoutSeconds+1) + maxWait
		result.RecommendedCheckCycleSeconds = ((seconds + 59) / 60) * 60
	}
	return result
}
func handleGetLocalPolicyStatus() LocalPolicySnapshot {
	if e := activeLocalPolicy.Load(); e != nil {
		return e.snapshot()
	}
	return LocalPolicySnapshot{Policies: []LocalPolicyStatus{}, Budgets: []LocalBudgetStatus{}}
}

type localBudgetRecord struct {
	ResetDay    int    `json:"resetDay"`
	TimeZone    string `json:"timeZone,omitempty"`
	PeriodStart int64  `json:"periodStart"`
	UsedBytes   int64  `json:"usedBytes"`
	Trusted     bool   `json:"trusted"`
}
type localBudgetFile struct {
	SchemaVersion int                          `json:"schemaVersion"`
	Clean         bool                         `json:"clean"`
	Records       map[string]localBudgetRecord `json:"records"`
}
type localBudgetLedger struct {
	mu               sync.Mutex
	persistMu        sync.Mutex
	path             string
	records          map[string]localBudgetRecord
	budgets          map[string]LocalPolicyBudget
	persistenceError string
	initialTrusted   bool
	version          uint64
	savedVersion     uint64
	storageHealthy   bool
	activeIO         atomic.Int64
	lastClean        bool
}

func newLocalBudgetLedger(path string) *localBudgetLedger {
	l := &localBudgetLedger{path: path, records: map[string]localBudgetRecord{}, budgets: map[string]LocalPolicyBudget{}, initialTrusted: true, storageHealthy: true}
	fileHandle, err := os.Open(path)
	if errors.Is(err, os.ErrNotExist) {
		return l
	}
	var data []byte
	if err == nil {
		data, err = io.ReadAll(io.LimitReader(fileHandle, 4*1024*1024+1))
		_ = fileHandle.Close()
		if len(data) > 4*1024*1024 {
			err = errors.New("budget ledger capacity exceeded")
		}
	}
	var file localBudgetFile
	if err == nil {
		err = json.Unmarshal(data, &file)
	}
	if err != nil || file.SchemaVersion != 1 || len(file.Records) > 10000 {
		l.initialTrusted = false
		l.persistenceError = "budget ledger unreadable"
		return l
	}
	for id, r := range file.Records {
		if r.PeriodStart < 0 || r.UsedBytes < 0 || len(id) > 256 || (r.TimeZone != "" && r.TimeZone != "Asia/Shanghai" && r.TimeZone != "UTC") {
			l.initialTrusted = false
			l.persistenceError = "budget ledger invalid"
			return l
		}
	}
	l.lastClean = file.Clean
	l.records = file.Records
	if l.records == nil {
		l.records = map[string]localBudgetRecord{}
	}
	if !file.Clean {
		for id, r := range l.records {
			r.Trusted = false
			l.records[id] = r
		}
		l.initialTrusted = false
		l.persistenceError = "budget ledger recovered after unclean exit"
	}
	return l
}
func budgetPeriod(now time.Time, b LocalPolicyBudget) int64 {
	zone := time.FixedZone("Asia/Shanghai", 8*60*60)
	if b.TimeZone == "UTC" {
		zone = time.UTC
	}
	date := now.In(zone)
	start := time.Date(date.Year(), date.Month(), b.ResetDay, 0, 0, 0, 0, zone)
	if date.Before(start) {
		start = start.AddDate(0, -1, 0)
	}
	return start.UnixMilli()
}
func (l *localBudgetLedger) configure(budgets []LocalPolicyBudget, now time.Time) {
	l.mu.Lock()
	defer l.mu.Unlock()
	l.budgets = map[string]LocalPolicyBudget{}
	for _, b := range budgets {
		l.budgets[b.SourceID] = b
		l.resetLocked(b.SourceID, now)
	}
	l.version++
}
func (l *localBudgetLedger) resetLocked(id string, now time.Time) localBudgetRecord {
	r, exists := l.records[id]
	b, hasBudget := l.budgets[id]
	if !hasBudget {
		return r
	}
	period := budgetPeriod(now, b)
	if !exists {
		r = localBudgetRecord{PeriodStart: period, Trusted: l.initialTrusted, ResetDay: b.ResetDay, TimeZone: b.TimeZone}
		l.records[id] = r
		l.version++
	} else if r.ResetDay != b.ResetDay || (r.TimeZone != b.TimeZone && !(r.TimeZone == "" && b.TimeZone == "Asia/Shanghai")) {
		r.ResetDay = b.ResetDay
		r.TimeZone = b.TimeZone
		r.PeriodStart = period
		l.records[id] = r
		l.version++
	} else if period > r.PeriodStart {
		r = localBudgetRecord{PeriodStart: period, Trusted: true, ResetDay: b.ResetDay, TimeZone: b.TimeZone}
		l.records[id] = r
		l.version++
	}
	return r
}
func (l *localBudgetLedger) reason(id string, now time.Time, unknown string) string {
	if l == nil {
		return ""
	}
	l.mu.Lock()
	defer l.mu.Unlock()
	b, exists := l.budgets[id]
	if !exists {
		return ""
	}
	r := l.resetLocked(id, now)
	if !r.Trusted || !l.storageHealthy {
		return "budget_untrusted"
	}
	if r.UsedBytes >= b.LimitBytes {
		return "budget_exhausted"
	}
	return ""
}
func (l *localBudgetLedger) count(id string, n int64, now time.Time) {
	if n <= 0 || l == nil {
		return
	}
	l.mu.Lock()
	defer l.mu.Unlock()
	if _, exists := l.budgets[id]; !exists {
		return
	}
	r := l.resetLocked(id, now)
	if n > int64(^uint64(0)>>1)-r.UsedBytes {
		r.UsedBytes = int64(^uint64(0) >> 1)
	} else {
		r.UsedBytes += n
	}
	l.records[id] = r
	l.version++
}
func (l *localBudgetLedger) status(now time.Time) []LocalBudgetStatus {
	if l == nil {
		return []LocalBudgetStatus{}
	}
	l.mu.Lock()
	defer l.mu.Unlock()
	result := []LocalBudgetStatus{}
	for id, b := range l.budgets {
		r := l.resetLocked(id, now)
		result = append(result, LocalBudgetStatus{SourceID: id, PeriodStart: r.PeriodStart, UsedBytes: r.UsedBytes, LimitBytes: b.LimitBytes, Trusted: r.Trusted && l.storageHealthy})
	}
	sort.Slice(result, func(i, j int) bool { return result[i].SourceID < result[j].SourceID })
	return result
}
func (l *localBudgetLedger) errorMessage() string {
	if l == nil {
		return ""
	}
	l.mu.Lock()
	defer l.mu.Unlock()
	return l.persistenceError
}
func (l *localBudgetLedger) save(clean bool) {
	if l == nil || l.path == "" {
		return
	}
	l.persistMu.Lock()
	defer l.persistMu.Unlock()
	l.mu.Lock()
	version := l.version
	if !clean && version == l.savedVersion && !l.lastClean && l.persistenceError == "" {
		l.mu.Unlock()
		return
	}
	file := localBudgetFile{SchemaVersion: 1, Clean: clean, Records: map[string]localBudgetRecord{}}
	for id, r := range l.records {
		file.Records[id] = r
	}
	l.mu.Unlock()
	data, err := json.Marshal(file)
	if err == nil {
		var file *os.File
		file, err = os.CreateTemp(filepath.Dir(l.path), ".local-policy-budget-*")
		if err == nil {
			temporaryPath := file.Name()
			defer os.Remove(temporaryPath)
			_, err = file.Write(data)
			if err == nil {
				err = file.Sync()
			}
			closeErr := file.Close()
			if err == nil {
				err = closeErr
			}
			if err == nil {
				err = os.Rename(temporaryPath, l.path)
			}
			if err == nil {
				var directory *os.File
				directory, err = os.Open(filepath.Dir(l.path))
				if err == nil {
					err = directory.Sync()
					_ = directory.Close()
				}
			}
		}
	}
	l.mu.Lock()
	defer l.mu.Unlock()
	if err != nil {
		l.persistenceError = "budget ledger persistence failed"
		l.storageHealthy = false
		for id, r := range l.records {
			r.Trusted = false
			l.records[id] = r
		}
		l.version++
	} else {
		l.savedVersion = version
		l.lastClean = clean
		l.storageHealthy = true
	}
}

func localPolicyScheduleActive(schedule *LocalPolicySchedule, now time.Time) bool {
	if schedule == nil {
		return true
	}
	if len(schedule.Windows) == 0 {
		return true
	}
	zone := time.FixedZone("Asia/Shanghai", 8*60*60)
	if schedule.TimeZone == "UTC" {
		zone = time.UTC
	}
	date := now.In(zone)
	day := int(date.Weekday())
	if day == 0 {
		day = 7
	}
	minute := date.Hour()*60 + date.Minute()
	for _, w := range schedule.Windows {
		startDay := day
		if w.StartMinute > w.EndMinute && minute < w.EndMinute {
			startDay = (day+5)%7 + 1
		} else if minute < w.StartMinute || w.StartMinute < w.EndMinute && minute >= w.EndMinute {
			continue
		}
		for _, weekday := range w.Weekdays {
			if weekday == startDay {
				return true
			}
		}
	}
	return false
}
func probeLocalPolicyNode(ctx context.Context, proxy C.Proxy, probe LocalPolicyProbe) error {
	expected := probe.ExpectedStatus
	if expected == "" {
		expected = "200-399"
	}
	ranges, err := utils.NewUnsignedRanges[uint16](expected)
	if err != nil {
		return err
	}
	transport := &http.Transport{DialContext: func(ctx context.Context, network, address string) (net.Conn, error) {
		metadata := &C.Metadata{NetWork: C.TCP}
		if err := metadata.SetRemoteAddress(address); err != nil {
			return nil, err
		}
		return proxy.DialContext(ctx, metadata)
	}, DisableKeepAlives: true, MaxConnsPerHost: 1}
	defer transport.CloseIdleConnections()
	client := &http.Client{Transport: transport, CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }}
	request, err := http.NewRequestWithContext(ctx, localProbeMethod(probe), probe.URL, nil)
	if err != nil {
		return err
	}
	response, err := client.Do(request)
	if err != nil {
		return err
	}
	defer response.Body.Close()
	if _, err := io.Copy(io.Discard, io.LimitReader(response.Body, 65537)); err != nil {
		return err
	}
	if !ranges.Check(uint16(response.StatusCode)) {
		return fmt.Errorf("probe returned unexpected status %d", response.StatusCode)
	}
	return nil
}

var localBudgetStore *localBudgetLedger

func closeLocalPolicyConnections() bool {
	localConnections.Lock()
	closers := make([]io.Closer, 0, len(localConnections.values))
	for _, connection := range localConnections.values {
		closers = append(closers, connection.closer)
	}
	localConnections.Unlock()
	clean := true
	for _, closer := range closers {
		if err := closer.Close(); err != nil {
			clean = false
		}
	}
	return clean
}

func closeLocalPolicyValidationConfig(cfg *config.Config) {
	for _, proxy := range cfg.Proxies {
		_ = proxy.Close()
	}
	for _, provider := range cfg.Providers {
		if closer, ok := provider.(io.Closer); ok {
			_ = closer.Close()
		}
	}
	for _, provider := range cfg.RuleProviders {
		if closer, ok := provider.(io.Closer); ok {
			_ = closer.Close()
		}
	}
}

func (l *localBudgetLedger) waitForIO() bool {
	if l == nil {
		return true
	}
	timeout := time.NewTimer(250 * time.Millisecond)
	defer timeout.Stop()
	ticker := time.NewTicker(time.Millisecond)
	defer ticker.Stop()
	for l.activeIO.Load() != 0 {
		select {
		case <-timeout.C:
			return false
		case <-ticker.C:
		}
	}
	return true
}

func (l *localBudgetLedger) canConfigure(budgets []LocalPolicyBudget) bool {
	l.mu.Lock()
	defer l.mu.Unlock()
	count := len(l.records)
	for _, budget := range budgets {
		if _, exists := l.records[budget.SourceID]; !exists {
			count++
		}
	}
	return count <= 10000
}
