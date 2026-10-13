package main

import (
	"errors"
	"fmt"
	"time"

	"github.com/metacubex/mihomo/adapter"
	"github.com/metacubex/mihomo/adapter/outbound"
	"github.com/metacubex/mihomo/config"
	C "github.com/metacubex/mihomo/constant"
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
	Snapshot LocalPolicySnapshot          `json:"snapshot"`
	Steps    []LocalPolicySimulationFrame `json:"steps"`
}

func simulateLocalPolicies(input LocalPolicySimulationInput) (LocalPolicySimulationResult, error) {
	result := LocalPolicySimulationResult{Steps: []LocalPolicySimulationFrame{}}
	if err := validateLocalPolicyConfig(&input.Config); err != nil {
		return result, err
	}
	if input.Now < 1 || input.Now > 9007199254740991 || len(input.Steps) > 32 || len(input.Health) > 5000 || len(input.AvailableNodeIDs) > 5000 || len(input.LocalUsage) > 20 {
		return result, errors.New("simulation capacity or time is invalid")
	}
	if !input.Config.Enabled {
		result.Snapshot = LocalPolicySnapshot{Revision: input.Config.Revision, Policies: []LocalPolicyStatus{}, Budgets: []LocalBudgetStatus{}}
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
	return result, nil
}
