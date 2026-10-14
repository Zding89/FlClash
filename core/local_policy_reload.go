package main

import (
	"crypto/sha256"
	"encoding/json"
	"reflect"
	"time"

	"gopkg.in/yaml.v3"
)

func (e *localPolicyEngine) identifyNodes(data []byte) {
	var raw struct {
		Proxies []map[string]any `yaml:"proxies"`
	}
	if yaml.Unmarshal(data, &raw) != nil {
		return
	}
	identities := map[string][32]byte{}
	for _, proxy := range raw.Proxies {
		name, ok := proxy["name"].(string)
		if !ok {
			continue
		}
		encoded, err := json.Marshal(proxy)
		if err == nil {
			identities[name] = sha256.Sum256(encoded)
		}
	}
	e.nodeIdentities = map[string][32]byte{}
	for id, node := range e.nodes {
		if identity, ok := identities[node.ProxyName]; ok {
			e.nodeIdentities[id] = identity
		}
	}
}

func (e *localPolicyEngine) inheritRuntime(old *localPolicyEngine) {
	if old == nil || e.config.TargetID != old.config.TargetID {
		return
	}
	old.mu.Lock()
	defer old.mu.Unlock()
	if !old.stopped {
		return
	}
	now := e.now()
	if !old.lastTick.IsZero() && now.Sub(old.lastTick) > 5*time.Second {
		return
	}
	e.lastTick = old.lastTick
	for _, r := range e.checkRuntimes() {
		previous := old.policies[r.definition.ID]
		if r.setID != "" {
			previous = old.sets[r.setID]
		}
		if previous == nil || !reflect.DeepEqual(r.definition.Guard, previous.definition.Guard) {
			continue
		}
		for id, health := range r.health {
			prior := previous.health[id]
			identity, known := e.nodeIdentities[id]
			priorIdentity, previouslyKnown := old.nodeIdentities[id]
			if prior == nil || !known || !previouslyKnown || identity != priorIdentity || !reflect.DeepEqual(e.nodes[id], old.nodes[id]) || localHealthKeyFor(r, id) != localHealthKeyFor(previous, id) {
				continue
			}
			if prior.lastProbe.IsZero() || now.Before(prior.lastProbe) || r.definition.Probe.ValiditySeconds > 0 && now.Sub(prior.lastProbe) >= time.Duration(r.definition.Probe.ValiditySeconds)*time.Second {
				continue
			}
			if e.sourceReasonLocked(id, r.definition, now) != "" || old.sourceReasonLocked(id, previous.definition, now) != "" {
				continue
			}
			*health = *prior
			health.pending = false
			if prior.latencyMillis != nil {
				latency := *prior.latencyMillis
				health.latencyMillis = &latency
			}
		}
	}
	for id, r := range e.sets {
		if prior := old.sets[id]; prior != nil && e.sameSet(old, id) && e.nodeReasonLocked(r, prior.selected, now) == "" {
			inheritLocalSelection(r, prior)
			if e.nodeReasonLocked(r, r.optimizationNode, now) != "" {
				r.optimizationNode = ""
				r.optimizationSince = time.Time{}
			}
		}
	}
	for id, r := range e.policies {
		prior := old.policies[id]
		if prior == nil || !sameLocalDefinition(r.definition, prior.definition) || !localPolicyScheduleActive(r.definition.Schedule, now) {
			continue
		}
		compatible := true
		for _, choice := range r.definition.Choices {
			if choice.Type == "nodeSet" && !e.sameSet(old, choice.ID) {
				compatible = false
			}
		}
		if !compatible || prior.selected == "" || e.policyNodeReasonLocked(r, prior.selected, now) != "" {
			continue
		}
		inheritLocalSelection(r, prior)
		if len(r.definition.Choices) > 0 && (r.selectedChoice < 0 || r.selectedChoice >= len(r.definition.Choices) || e.choiceNodeReasonLocked(r, r.selectedChoice, r.selected, now) != "") {
			r.selected = ""
			continue
		}
		if r.recoveryNode != "" && (r.recoveryChoice < 0 || r.recoveryChoice >= len(r.definition.Choices) || e.choiceNodeReasonLocked(r, r.recoveryChoice, r.recoveryNode, now) != "") {
			r.recoveryNode = ""
			r.recoverySince = time.Time{}
		}
		for index, selection := range prior.choiceSelections {
			if index < 0 || index >= len(r.definition.Choices) {
				continue
			}
			set := e.sets[selection.setID]
			if set == nil || e.choiceNodeReasonLocked(r, index, selection.selected, now) != "" {
				continue
			}
			cloned := &localPolicyRuntime{setID: selection.setID, definition: set.definition, health: set.health}
			inheritLocalSelection(cloned, selection)
			if e.choiceNodeReasonLocked(r, index, cloned.optimizationNode, now) != "" {
				cloned.optimizationNode = ""
				cloned.optimizationSince = time.Time{}
			}
			if r.choiceSelections == nil {
				r.choiceSelections = map[int]*localPolicyRuntime{}
			}
			r.choiceSelections[index] = cloned
		}
	}
}

func (e *localPolicyEngine) sameSet(old *localPolicyEngine, id string) bool {
	current, exists := e.setDefinitions[id]
	previous, existed := old.setDefinitions[id]
	current.Label, previous.Label = "", ""
	return exists && existed && reflect.DeepEqual(current, previous)
}

func sameLocalDefinition(current, previous LocalPolicyDefinition) bool {
	current.Label, previous.Label = "", ""
	return reflect.DeepEqual(current, previous)
}

func inheritLocalSelection(current, previous *localPolicyRuntime) {
	current.balanceCursor = previous.balanceCursor
	current.selected = previous.selected
	current.selectedChoice = previous.selectedChoice
	current.reason = previous.reason
	current.switched = previous.switched
	current.updated = previous.updated
	current.optimizationNode = previous.optimizationNode
	current.optimizationSince = previous.optimizationSince
	current.recoveryNode = previous.recoveryNode
	current.recoveryChoice = previous.recoveryChoice
	current.recoverySince = previous.recoverySince
	current.history = append([]LocalPolicyHistory(nil), previous.history...)
}
