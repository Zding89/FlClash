package main

import (
	"context"
	"errors"
	"fmt"
	"net/netip"
	"regexp"
	"strings"
	"time"

	"github.com/metacubex/mihomo/adapter"
	"github.com/metacubex/mihomo/adapter/outbound"
	"github.com/metacubex/mihomo/config"
	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/rules"
	RC "github.com/metacubex/mihomo/rules/common"
	"github.com/metacubex/mihomo/tunnel"
)

type LocalPolicySimulationProbe struct {
	NodeID  string `json:"nodeId"`
	Success bool   `json:"success"`
}
type LocalPolicySimulationStep struct {
	At      int64                        `json:"at"`
	Probes  []LocalPolicySimulationProbe `json:"probes"`
	Sources []LocalPolicySource          `json:"sources"`
	Usage   map[string]int64             `json:"usage"`
}
type LocalPolicySimulationInput struct {
	Config           LocalPolicyConfig           `json:"config"`
	AvailableNodeIDs []string                    `json:"availableNodeIds"`
	Now              int64                       `json:"now"`
	Health           map[string]*bool            `json:"health"`
	LocalUsage       map[string]int64            `json:"localUsage"`
	Steps            []LocalPolicySimulationStep `json:"steps"`
	Rules            []string                    `json:"rules"`
	Flows            []LocalPolicySimulationFlow `json:"flows"`
}
type LocalPolicySimulationFlow struct {
	Host          string `json:"host"`
	DestinationIP string `json:"destinationIp"`
	ProcessName   string `json:"processName"`
	ProcessPath   string `json:"processPath"`
	Network       string `json:"network"`
}
type LocalPolicySimulationTrace struct {
	RuleIndex int      `json:"ruleIndex"`
	Type      string   `json:"type"`
	Target    string   `json:"target"`
	Outcome   string   `json:"outcome"`
	Reason    string   `json:"reason,omitempty"`
	Needs     []string `json:"needs,omitempty"`
}
type LocalPolicySimulationFlowResult struct {
	FlowIndex      int                          `json:"flowIndex"`
	Status         string                       `json:"status"`
	Target         string                       `json:"target,omitempty"`
	PolicyID       string                       `json:"policyId,omitempty"`
	SelectedNodeID string                       `json:"selectedNodeId,omitempty"`
	Reason         string                       `json:"reason"`
	Needs          []string                     `json:"needs"`
	Trace          []LocalPolicySimulationTrace `json:"trace"`
	TraceTruncated bool                         `json:"traceTruncated"`
}
type LocalPolicySimulationDecision struct {
	PolicyID       string `json:"policyId"`
	SelectedNodeID string `json:"selectedNodeId"`
	State          string `json:"state"`
	Reason         string `json:"reason"`
}
type LocalPolicySimulationFrame struct {
	At        int64                           `json:"at"`
	Decisions []LocalPolicySimulationDecision `json:"decisions"`
}
type LocalPolicySimulationResult struct {
	Snapshot    LocalPolicySnapshot               `json:"snapshot"`
	Steps       []LocalPolicySimulationFrame      `json:"steps"`
	FlowResults []LocalPolicySimulationFlowResult `json:"flowResults"`
}

func simulateLocalPolicies(input LocalPolicySimulationInput) (LocalPolicySimulationResult, error) {
	result := LocalPolicySimulationResult{Steps: []LocalPolicySimulationFrame{}, FlowResults: []LocalPolicySimulationFlowResult{}}
	if err := validateLocalPolicyConfig(&input.Config); err != nil {
		return result, err
	}
	if input.Now < 1 || input.Now > 9007199254740991 || len(input.Steps) > 32 || len(input.Health) > 5000 || len(input.AvailableNodeIDs) > 5000 || len(input.LocalUsage) > 20 {
		return result, errors.New("simulation capacity or time is invalid")
	}
	if err := validateLocalSimulationFlows(input); err != nil {
		return result, err
	}
	if !input.Config.Enabled {
		result.Snapshot = LocalPolicySnapshot{Revision: input.Config.Revision, Policies: []LocalPolicyStatus{}, Budgets: []LocalBudgetStatus{}}
		for index := range input.Flows {
			result.FlowResults = append(result.FlowResults, LocalPolicySimulationFlowResult{FlowIndex: index, Status: "unknown", Reason: "local_policy_disabled", Needs: []string{"enabledPolicyConfiguration"}, Trace: []LocalPolicySimulationTrace{}})
		}
		return result, nil
	}
	available := map[string]bool{}
	for _, id := range input.AvailableNodeIDs {
		if available[id] {
			return result, errors.New("duplicate available node")
		}
		available[id] = true
	}
	cfg := &config.Config{General: &config.General{Mode: tunnel.Rule}, Proxies: map[string]C.Proxy{}}
	validHealth := map[string]bool{}
	for _, node := range input.Config.Nodes {
		validHealth[node.ID] = true
		if available[node.ID] {
			cfg.Proxies[node.ProxyName] = adapter.NewProxy(outbound.NewBase(outbound.BaseOption{Name: node.ProxyName, Type: C.Shadowsocks, UDP: true}))
		}
		delete(available, node.ID)
	}
	if len(available) != 0 {
		return result, errors.New("unknown available node")
	}
	for _, policy := range input.Config.Policies {
		cfg.Proxies[policy.GroupName] = adapter.NewProxy(outbound.NewBase(outbound.BaseOption{Name: policy.GroupName, Type: C.Selector}))
		for _, id := range policy.CandidateNodeIDs {
			validHealth[id] = true
		}
	}
	for id := range input.Health {
		if !validHealth[id] {
			return result, errors.New("unknown health node")
		}
	}
	ledger := newLocalBudgetLedger("")
	e, err := prepareLocalPolicy(&input.Config, cfg, ledger)
	if err != nil {
		return result, err
	}
	defer e.cancel()
	now := time.UnixMilli(input.Now)
	e.now = func() time.Time { return now }
	ledger.configure(input.Config.Budgets, now)
	applyUsage := func(usage map[string]int64, initial bool) error {
		for id, used := range usage {
			if _, ok := e.sources[id]; !ok || used < 0 || used > 9007199254740991 {
				return errors.New("invalid simulated usage")
			}
		}
		for id := range ledger.budgets {
			record := ledger.resetLocked(id, now)
			if used, ok := usage[id]; ok {
				record.UsedBytes = used
				record.Trusted = true
			} else if initial {
				record.Trusted = false
			}
			ledger.records[id] = record
		}
		return nil
	}
	if err = applyUsage(input.LocalUsage, true); err != nil {
		return result, err
	}
	for _, runtime := range e.checkRuntimes() {
		for id, health := range runtime.health {
			if state := input.Health[id]; state != nil {
				health.healthy = *state
				health.lastProbe = now
				health.recovering = !*state
				if *state {
					health.healthySince = now.Add(-time.Duration(runtime.definition.RecoverySeconds+runtime.definition.CooldownSeconds+1) * time.Second)
					health.successes = runtime.definition.Probe.SuccessThreshold
				}
			}
		}
	}
	frame := func() LocalPolicySimulationFrame {
		snapshot := e.snapshot()
		decisions := []LocalPolicySimulationDecision{}
		for _, policy := range snapshot.Policies {
			decisions = append(decisions, LocalPolicySimulationDecision{PolicyID: policy.PolicyID, SelectedNodeID: policy.SelectedNodeID, State: policy.State, Reason: policy.Reason})
		}
		return LocalPolicySimulationFrame{At: now.UnixMilli(), Decisions: decisions}
	}
	result.Steps = append(result.Steps, frame())
	for _, step := range input.Steps {
		if step.At < now.UnixMilli() || step.At > 9007199254740991 || len(step.Probes) > 1000 || len(step.Sources) > 20 || len(step.Usage) > 20 {
			return result, errors.New("invalid simulation step")
		}
		now = time.UnixMilli(step.At)
		for _, source := range step.Sources {
			original, ok := e.sources[source.ID]
			if !ok || source.ExpiresAt != nil && *source.ExpiresAt < 0 || source.RemainingBytes != nil && *source.RemainingBytes < 0 || source.ObservedAt != nil && *source.ObservedAt < 0 {
				return result, errors.New("invalid simulated source metadata")
			}
			source.Label = original.Label
			if source.ExpiresAt == nil {
				source.ExpiresAt = original.ExpiresAt
			}
			if source.RemainingBytes == nil && original.RemainingBytes != nil && *original.RemainingBytes <= 0 {
				source.RemainingBytes = original.RemainingBytes
			}
			e.sources[source.ID] = source
		}
		if err = applyUsage(step.Usage, false); err != nil {
			return result, err
		}
		for _, probe := range step.Probes {
			if !validHealth[probe.NodeID] {
				return result, fmt.Errorf("unknown simulated probe node")
			}
			var probeError error
			if !probe.Success {
				probeError = errors.New("simulated probe failure")
			}
			seenHealth := map[*localNodeHealth]bool{}
			for _, runtime := range e.checkRuntimes() {
				if h := runtime.health[probe.NodeID]; h != nil && !seenHealth[h] {
					seenHealth[h] = true
					e.applyProbeLocked(runtime, probe.NodeID, probeError, now)
				}
			}
		}
		result.Steps = append(result.Steps, frame())
	}
	result.Snapshot = e.snapshot()
	for index, flow := range input.Flows {
		trace, err := traceLocalSimulationFlow(e, input.Rules, flow, index)
		if err != nil {
			return result, err
		}
		result.FlowResults = append(result.FlowResults, trace)
	}
	return result, nil
}

func validateLocalSimulationFlows(input LocalPolicySimulationInput) error {
	if len(input.Flows) > 8 || len(input.Rules) > 2048 || len(input.Flows) > 0 && len(input.Rules) == 0 {
		return errors.New("invalid simulation flow capacity")
	}
	total := 0
	for _, line := range input.Rules {
		total += len(line)
		if len(line) > 16384 || total > 512*1024 || strings.ContainsAny(line, "\x00\n\r") {
			return errors.New("invalid simulation rule capacity")
		}
		tp, _, target, _ := RC.ParseRulePayload(line, true)
		if len(tp) == 0 || len(tp) > 64 || len(target) == 0 || len(target) > 256 {
			return errors.New("invalid simulation rule target")
		}
		depth := 0
		escaped := false
		for _, value := range line {
			if escaped {
				escaped = false
				continue
			}
			if value == '\\' {
				escaped = true
				continue
			}
			if value == '(' {
				depth++
			}
			if value == ')' {
				depth--
			}
			if depth > 24 || depth < 0 {
				return errors.New("invalid simulation rule nesting")
			}
		}
		if depth != 0 {
			return errors.New("invalid simulation rule nesting")
		}
	}
	for _, flow := range input.Flows {
		if len(flow.Host) > 1024 || len(flow.ProcessName) > 256 || len(flow.ProcessPath) > 4096 || len(flow.DestinationIP) > 64 || flow.Network != "" && flow.Network != "tcp" && flow.Network != "udp" {
			return errors.New("invalid simulation flow")
		}
		if flow.DestinationIP != "" {
			if _, err := netip.ParseAddr(flow.DestinationIP); err != nil {
				return errors.New("invalid simulation destination IP")
			}
		}
	}
	return nil
}

var localSimulationRuleTokens = regexp.MustCompile(`(?i)(?:^|[,(])\s*([A-Z][A-Z0-9-]*)\s*,`)
var localSimulationGeoTokens = regexp.MustCompile(`(?i)(?:^|[,(])\s*GEOIP\s*,\s*([^,()]+)`)

func localSimulationNeeds(line string, flow LocalPolicySimulationFlow) []string {
	needs := []string{}
	hasRegex := false
	add := func(value string) {
		if !localContains(needs, value) {
			needs = append(needs, value)
		}
	}
	_, _, _, params := RC.ParseRulePayload(line, true)
	if source, _ := RC.ParseParams(params); source {
		add("sourceIp")
	}
	for _, token := range localSimulationRuleTokens.FindAllStringSubmatch(line, -1) {
		kind := strings.ToUpper(token[1])
		if strings.HasSuffix(kind, "-REGEX") {
			hasRegex = true
		}
		switch kind {
		case "DOMAIN", "DOMAIN-SUFFIX", "DOMAIN-KEYWORD", "DOMAIN-WILDCARD", "DOMAIN-REGEX":
			if flow.Host == "" {
				add("host")
			}
		case "PROCESS-NAME", "PROCESS-NAME-WILDCARD", "PROCESS-NAME-REGEX":
			if flow.ProcessName == "" {
				add("processName")
			}
		case "PROCESS-PATH", "PROCESS-PATH-WILDCARD", "PROCESS-PATH-REGEX":
			if flow.ProcessPath == "" {
				add("processPath")
			}
		case "IP-CIDR", "IP-CIDR6", "IP-SUFFIX", "GEOIP":
			if flow.DestinationIP == "" {
				add("destinationIp")
			}
		case "NETWORK":
			if flow.Network == "" {
				add("network")
			}
		case "AND", "OR", "NOT", "MATCH":
		default:
			add("unsupported_rule_context")
		}
	}
	for _, token := range localSimulationGeoTokens.FindAllStringSubmatch(line, -1) {
		if !strings.EqualFold(strings.TrimSpace(token[1]), "LAN") {
			add("geoData")
		}
	}
	if hasRegex {
		value := strings.NewReplacer("/Contents/.*$", "/Contents/", "(?:/|$)", "/", "(?i)", "", "(?:", "(").Replace(line)
		escaped := false
		for _, char := range value {
			if escaped {
				escaped = false
				if char >= '0' && char <= '9' {
					add("bounded_regex_evaluation")
				}
				continue
			}
			if char == '\\' {
				escaped = true
				continue
			}
			if strings.ContainsRune("*+?{|", char) {
				add("bounded_regex_evaluation")
			}
		}
	}
	return needs
}

func traceLocalSimulationFlow(e *localPolicyEngine, lines []string, flow LocalPolicySimulationFlow, index int) (LocalPolicySimulationFlowResult, error) {
	result := LocalPolicySimulationFlowResult{FlowIndex: index, Status: "unmatched", Reason: "no_matching_rule", Needs: []string{}, Trace: []LocalPolicySimulationTrace{}}
	metadata := &C.Metadata{Host: flow.Host, Process: flow.ProcessName, ProcessPath: flow.ProcessPath, NetWork: C.TCP}
	if flow.Network == "udp" {
		metadata.NetWork = C.UDP
	}
	if flow.DestinationIP != "" {
		metadata.DstIP = netip.MustParseAddr(flow.DestinationIP)
	}
	appendTrace := func(value LocalPolicySimulationTrace) {
		if len(result.Trace) < 16 {
			result.Trace = append(result.Trace, value)
		} else {
			result.TraceTruncated = true
		}
	}
	for ruleIndex, line := range lines {
		tp, payload, target, params := RC.ParseRulePayload(line, true)
		trace := LocalPolicySimulationTrace{RuleIndex: ruleIndex, Type: tp, Target: target, Outcome: "not_matched"}
		needs := localSimulationNeeds(line, flow)
		if len(needs) > 0 {
			trace.Outcome, trace.Reason, trace.Needs = "unknown", "missing_or_unsupported_facts", needs
			for _, need := range needs {
				if !localContains(result.Needs, need) {
					result.Needs = append(result.Needs, need)
				}
			}
			result.Status, result.Reason = "unknown", "earlier_rule_needs_facts"
			appendTrace(trace)
			continue
		}
		rule, err := rules.ParseRule(tp, payload, target, params, nil)
		if err != nil {
			return result, errors.New("invalid compiled simulation rule")
		}
		matched, target := rule.Match(metadata, C.RuleMatchHelper{})
		if !matched {
			appendTrace(trace)
			continue
		}
		trace.Target = target
		if target == "PASS" || target == "PASS-RULE" {
			trace.Outcome, trace.Reason = "skipped", "pass"
			appendTrace(trace)
			continue
		}
		policyID := ""
		for id, runtime := range e.policies {
			if runtime.definition.GroupName == target {
				policyID = id
				break
			}
		}
		selectedID, reason := "", "rule_matched"
		if policyID != "" {
			managed := &localManagedAdapter{engine: e, policyID: policyID}
			if managed.Type() == C.Pass {
				trace.Outcome, trace.Reason = "skipped", e.policies[policyID].reason
				appendTrace(trace)
				continue
			}
			_, selectedID, err = e.selectProxyForRequest(policyID, metadata, true)
			reason = e.policies[policyID].reason
			if err != nil {
				reason = err.Error()
			}
			if selectedID != "" {
				ctx := context.WithValue(context.Background(), localPolicyAdmissionKey{}, e.policies[policyID].definition.Guard.UnknownBehavior)
				if admission := (&localSourceAdapter{engine: e, node: e.nodes[selectedID]}).admission(ctx); admission != nil {
					reason = admission.Error()
				}
			}
		} else if target != "DIRECT" && target != "REJECT" && target != "REJECT-DROP" {
			found := false
			for id, node := range e.nodes {
				if node.ProxyName == target {
					found, selectedID = true, id
					if admission := (&localSourceAdapter{engine: e, node: node}).admission(context.Background()); admission != nil {
						reason = admission.Error()
					}
					break
				}
			}
			if !found {
				trace.Outcome, trace.Reason, trace.Needs = "unknown", "target_not_in_simulation", []string{"targetContext"}
				result.Status, result.Reason = "unknown", "target_not_in_simulation"
				if !localContains(result.Needs, "targetContext") {
					result.Needs = append(result.Needs, "targetContext")
				}
				appendTrace(trace)
				continue
			}
		}
		trace.Outcome, trace.Reason = "matched", reason
		appendTrace(trace)
		if result.Status != "unknown" {
			result.Status = "matched"
		}
		result.Target, result.PolicyID, result.SelectedNodeID = target, policyID, selectedID
		if result.Status == "matched" {
			result.Reason = reason
		}
		return result, nil
	}
	return result, nil
}
