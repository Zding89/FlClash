import test from 'node:test';
import assert from 'node:assert/strict';
import { modelResultValue } from '../src/model_results.mjs';

test('small draft receipts keep exact references and omit local presentation data by default', () => {
  const original = {
    proposal: { id: '900719925474099311', summary: '仅调整倍率', differences: [{ path: 'nodeSets', before: ['old'], after: ['new'] }], highRisk: false },
    document: { nodeSets: [{ id: 'pool', maxMultiplier: 0.1 }] }, contract: { fields: ['internal'] },
    version: 'new-version', supersedesId: '900719925474099310', taskEffect: 'mutation',
    validation: { valid: true, issues: [], warnings: [] },
    businessSummary: { ruleCount: 4, nodeSetCount: 2, rules: [{ id: 'rule' }], nodeSets: [{ id: 'pool' }], reply: '完整本地摘要' },
    createdResources: [{ id: '900719925474099312', actionIndex: 0, kind: 'createNodeSet' }], assignedIds: { newPool: '900719925474099312' },
  };
  assert.ok(Buffer.byteLength(JSON.stringify(original)) < 6144);
  const result = modelResultValue('policy_draft_edit', original);
  assert.equal(result.proposal.id, original.proposal.id);
  assert.equal(result.proposal.differenceCount, 1);
  assert.equal(result.proposal.summary, undefined);
  assert.equal(result.proposal.differences, undefined);
  assert.equal(result.document, undefined);
  assert.equal(result.contract, undefined);
  assert.deepEqual(result.businessSummary, { ruleCount: 4, nodeSetCount: 2, detailsAvailable: true });
  assert.deepEqual(result.assignedIds, original.assignedIds);
  assert.deepEqual(result.createdResources, original.createdResources);
  assert.equal(result.supersedesId, original.supersedesId);
  assert.equal(result.resourceReferences.draftId, original.proposal.id);
  assert.equal(result.validation.valid, true);
  assert.equal(result.contextTruncated, undefined);
  assert.equal(original.businessSummary.reply, '完整本地摘要');
  assert.deepEqual(modelResultValue('policy_draft_edit', result), result);
});

test('nested application receipts retain pending, cancellation, repair and completion semantics', () => {
  for (const status of ['pending_confirmation', 'requires_user_action', 'cancelled', 'failed', 'applied']) {
    const completion = { version: 1, persisted: true, currentStateMatches: false, scope: 'configuration', outcome: 'saved' };
    const original = { status, operationId: 'operation-1', taskEffect: 'mutation', errorCode: status === 'failed' ? 'configuration_conflict' : null, result: { operation: { id: 'operation-1', status, currentStateMatches: false, completion, result: { proposal: { id: 'draft-next', differences: [{ before: 'private local config', after: 'updated local config' }] }, document: { local: true } } } } };
    const result = modelResultValue('application_invoke', original);
    assert.equal(result.status, status);
    assert.equal(result.operationId, 'operation-1');
    assert.equal(result.result.operation.status, status);
    assert.equal(result.result.operation.currentStateMatches, false);
    assert.deepEqual(result.result.operation.completion, completion);
    assert.equal(result.result.operation.result.proposal.id, 'draft-next');
    assert.equal(result.result.operation.result.proposal.differences, undefined);
    assert.equal(result.result.operation.result.document, undefined);
  }
  const error = { code: 'tool_invalid_arguments', taskEffect: 'mutation', writeApplied: false, schemaTool: 'policy_edit_schema', issues: [{ actionIndex: 1, kind: 'rule', field: 'fields.probe', reason: 'Invalid timeout', expectedPath: 'fields.probe.timeoutSeconds', schemaArguments: { kind: 'rule' } }], issuesComplete: true, recovery: { writeApplied: false, instruction: 'Read the draft before retrying.' } };
  const projected = modelResultValue('policy_draft_edit', error);
  assert.deepEqual(projected.issues, error.issues);
  assert.equal(projected.writeApplied, false);
  assert.equal(projected.recovery.writeApplied, false);
  assert.equal(projected.schemaTool, 'policy_edit_schema');
});

test('query pages, resource fragments, schemas and read-only application results remain exact', () => {
  const page = { version: 'snapshot', nodes: Array.from({ length: 100 }, (_, i) => ({ id: `${900719925474099300n + BigInt(i)}`, label: `node-${i}`, sourceId: 'airport', multiplier: 0.1 })), total: 203, offset: 0, complete: false, nextCursor: 'exact-cursor' };
  for (const name of ['nodes_query', 'nodes_list', 'rules_query', 'node_sets_query', 'settings_read', 'policy_resource_read']) assert.strictEqual(modelResultValue(name, page), page);
  const schema = { schema: { properties: { probe: { type: 'object', properties: { timeoutSeconds: { type: 'integer' } } } } } };
  assert.strictEqual(modelResultValue('policy_edit_schema', schema), schema);
  const read = { status: 'completed', taskEffect: 'read', result: { rows: page.nodes, complete: false, nextCursor: 'next', summary: { download: 4096 } } };
  assert.strictEqual(modelResultValue('application_invoke', read), read);
});

test('typical local review data has a measurable JSON byte reduction', t => {
  const original = { proposal: { id: 'draft-measured', summary: '调整美国节点集倍率', differences: [{ path: 'policies.nodeSets', before: Array.from({ length: 12 }, (_, i) => ({ id: `pool-${i}`, label: `节点集${i}`, sourceIds: ['1', '2'], regions: ['US'], maxMultiplier: 1 })), after: Array.from({ length: 12 }, (_, i) => ({ id: `pool-${i}`, label: `节点集${i}`, sourceIds: ['1', '2'], regions: ['US'], maxMultiplier: i === 0 ? 0.1 : 1 })) }] }, taskEffect: 'mutation', version: 'version-measured', validation: { valid: true, issues: [], warnings: [] }, businessSummary: { ruleCount: 12, nodeSetCount: 12, reply: '本地完整方案摘要'.repeat(80), rules: Array.from({ length: 12 }, (_, i) => ({ id: `rule-${i}`, label: `规则${i}`, match: '匹配条件', candidateNodeSets: [`pool-${i}`] })) } };
  const before = Buffer.byteLength(JSON.stringify(original));
  const after = Buffer.byteLength(JSON.stringify(modelResultValue('policies_propose', original)));
  t.diagnostic(`JSON bytes: ${before} -> ${after}`);
  assert.ok(after < before / 3, `${before} -> ${after}`);
});


test('file grants preserve exact reusable handles without local paths', () => {
  const original = { taskEffect: 'mutation', status: 'completed', operationId: 'file-operation', result: { fileGrantId: '900719925474099331', mode: 'write', fileName: 'backup.bin', expiresAt: 123456789, path: '/private/local/backup.bin' } };
  const projected = modelResultValue('application_invoke', original);
  assert.equal(projected.result.fileGrantId, original.result.fileGrantId);
  assert.equal(projected.result.mode, 'write');
  assert.equal(projected.result.fileName, 'backup.bin');
  assert.equal(projected.result.expiresAt, 123456789);
  assert.equal(projected.result.path, undefined);
  assert.deepEqual(modelResultValue('application_operation', projected), projected);
});

test('batch refresh receipts retain every exact draft reference in a bounded idempotent projection', () => {
  const ids = Array.from({ length: 100 }, (_, i) => `${900719925474099300n + BigInt(i)}`);
  const original = { status: 'proposal_ready', taskEffect: 'mutation', operationId: 'batch-operation', result: { status: 'proposal_ready', failedCount: 0, proposals: ids.map(id => ({ status: 'pending_confirmation', operationId: id, result: { proposal: { id, differences: [{ path: 'protectedContent', before: 'private', after: 'private updated' }] } } })) } };
  const projected = modelResultValue('application_invoke', original);
  assert.deepEqual(projected.result.proposalIds, ids);
  assert.equal(projected.result.proposalCount, 100);
  assert.equal(projected.result.proposalsComplete, true);
  assert.equal(projected.result.failedCount, 0);
  assert.ok(Buffer.byteLength(JSON.stringify(projected)) <= 6144);
  assert.deepEqual(modelResultValue('application_operation', projected), projected);
  assert.equal(JSON.stringify(projected).includes('private'), false);
  const mixed = modelResultValue('application_invoke', { ...original, result: { ...original.result, failedCount: 1, proposals: [...original.result.proposals.slice(1), { profileId: 'source-1', status: 'failed', errorCode: 'resource_download_failed' }] } });
  assert.equal(mixed.result.failedCount, 1);
  assert.equal(mixed.result.proposalIds.length, 99);
  assert.equal(mixed.result.proposalsComplete, false);
});
