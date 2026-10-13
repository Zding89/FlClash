package main

import (
	"crypto/rand"
	"encoding/hex"
	"errors"
	"time"
)

type LocalPolicyCheckInput struct {
	Revision    int64  `json:"revision"`
	NodeSetID   string `json:"nodeSetId"`
	OperationID string `json:"operationId"`
	Cancel      bool   `json:"cancel"`
}
type localPolicyCheck struct {
	ID        string `json:"operationId"`
	Status    string `json:"status"`
	NodeSetID string `json:"nodeSetId"`
	StartedAt int64  `json:"startedAt"`
	Completed int    `json:"completed"`
	Total     int    `json:"total"`
	expected  map[string]uint64
}

func (e *localPolicyEngine) manualCheckNeeded(r *localPolicyRuntime, id string) bool {
	for _, job := range e.checks {
		if job.Status == "pending" && job.NodeSetID == r.setID {
			h := r.health[id]
			if h != nil && h.checkSequence < job.expected[id] {
				return true
			}
		}
	}
	return false
}
func (e *localPolicyEngine) checkNodes(input LocalPolicyCheckInput) (localPolicyCheck, error) {
	e.mu.Lock()
	defer e.mu.Unlock()
	if e.stopped || input.Revision != e.config.Revision {
		return localPolicyCheck{}, errors.New("local_policy_revision_conflict")
	}
	if input.OperationID != "" {
		job := e.checks[input.OperationID]
		if job == nil {
			return localPolicyCheck{}, errors.New("local_policy_check_missing")
		}
		e.updateCheckLocked(job)
		if input.Cancel && job.Status == "pending" {
			job.Status = "cancelled"
		}
		return *job, nil
	}
	r := e.sets[input.NodeSetID]
	if r == nil {
		return localPolicyCheck{}, errors.New("local_policy_set_inactive")
	}
	pending := 0
	for _, job := range e.checks {
		e.updateCheckLocked(job)
		if job.Status == "pending" {
			pending++
		}
	}
	if pending >= 16 {
		return localPolicyCheck{}, errors.New("local_policy_check_queue_full")
	}
	if e.checks == nil {
		e.checks = map[string]*localPolicyCheck{}
	}
	for len(e.checks) >= 64 {
		old := ""
		var at int64
		for id, job := range e.checks {
			if job.Status != "pending" && (old == "" || job.StartedAt < at) {
				old = id
				at = job.StartedAt
			}
		}
		if old == "" {
			return localPolicyCheck{}, errors.New("local_policy_check_queue_full")
		}
		delete(e.checks, old)
	}
	now := e.now()
	var identity [16]byte
	if _, err := rand.Read(identity[:]); err != nil {
		return localPolicyCheck{}, err
	}
	id := hex.EncodeToString(identity[:])
	job := &localPolicyCheck{ID: id, Status: "pending", NodeSetID: input.NodeSetID, StartedAt: now.UnixMilli(), Total: len(r.health), expected: map[string]uint64{}}
	e.checks[id] = job
	for nodeID, h := range r.health {
		job.expected[nodeID] = h.checkSequence + 1
		if !h.pending {
			h.nextProbe = time.Time{}
		}
	}
	if job.Total == 0 {
		job.Status = "completed"
	}
	return *job, nil
}
func (e *localPolicyEngine) updateCheckLocked(job *localPolicyCheck) {
	if job.Status != "pending" {
		return
	}
	r := e.sets[job.NodeSetID]
	if r == nil {
		job.Status = "cancelled"
		return
	}
	completed := 0
	for id, h := range r.health {
		if h.checkSequence >= job.expected[id] || e.sourceReasonLocked(id, r.definition, e.now()) != "" {
			completed++
		}
	}
	job.Completed = completed
	if completed == job.Total {
		job.Status = "completed"
	}
}
func handleLocalPolicyCheck(input LocalPolicyCheckInput) (localPolicyCheck, error) {
	e := activeLocalPolicy.Load()
	if e == nil {
		return localPolicyCheck{}, errors.New("local_policy_inactive")
	}
	return e.checkNodes(input)
}
