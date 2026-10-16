const object = value => value !== null && typeof value === 'object' && !Array.isArray(value);
const bytes = value => Buffer.byteLength(JSON.stringify(value));
const draftTools = new Set(['policy_draft_edit', 'policy_draft_read', 'policies_propose', 'policies_draft_read']);
const receiptTools = new Set(['application_operation', 'changes_status', 'task_finish']);
const mutationName = name => /(?:_propose|_commit|_undo|_clear|_update|_set_enabled|_set_disabled|_select)$/.test(name) || ['policy_draft_edit', 'backup_panel', 'profile_import_panel'].includes(name);
const scalarKeys = ['id', 'draftId', 'operationId', 'status', 'code', 'errorCode', 'version', 'documentVersion', 'supersedesId', 'taskEffect', 'replayed', 'currentStateMatches', 'highRisk', 'expiresAt', 'reversible', 'writeApplied', 'field', 'reason', 'schemaTool', 'issuesComplete', 'requestedRunning', 'running', 'digest', 'fingerprint', 'afterDigest', 'summaryAvailableLocally', 'proposalCount', 'failedCount', 'proposalsComplete', 'proposalsTool', 'fileGrantId', 'mode', 'fileName'];
const issueKeys = ['code', 'ruleId', 'previousRuleId', 'nodeSetId', 'field', 'actionIndex', 'kind', 'reason', 'expectedPath'];
const select = (value, keys) => Object.fromEntries(keys.filter(key => ['string', 'number', 'boolean'].includes(typeof value[key]) || value[key] === null).map(key => [key, ['reason', 'instruction'].includes(key) && typeof value[key] === 'string' ? value[key].slice(0, 512) : value[key]]));
const issues = (rows, limit) => Array.isArray(rows) ? rows.slice(0, limit).filter(object).map(row => ({ ...select(row, issueKeys), ...(object(row.schemaArguments) ? { schemaArguments: row.schemaArguments } : {}) })) : [];
const draftId = value => value.proposal?.id ?? value.draftId ?? value.id ?? (object(value.result) ? draftId(value.result) : undefined);
const references = (value, id) => ({ ...(id === undefined ? {} : { draftId: id }), ...(value.version === undefined ? {} : { version: value.version }), rulesTool: 'rules_query', nodeSetsTool: 'node_sets_query' });
function validationSummary(value, root, id, limit) {
  const issueCount = Number.isSafeInteger(value.issueCount) ? value.issueCount : Array.isArray(value.issues) ? value.issues.length : 0;
  const warningCount = Number.isSafeInteger(value.warningCount) ? value.warningCount : Array.isArray(value.warnings) ? value.warnings.length : 0;
  const result = { ...select(value, ['valid']), issueCount, warningCount, issues: issues(value.issues, limit), warnings: issues(value.warnings, limit) };
  result.complete = value.complete !== false && issueCount <= result.issues.length && warningCount <= result.warnings.length;
  if (id !== undefined) Object.assign(result, { detailsTool: 'policy_preview', detailsArguments: { draftId: id, ...(root.version === undefined ? {} : { version: root.version }), resultKind: 'validation' } });
  return result;
}
function receipt(value, root, id, limit, depth = 0) {
  if (!object(value) || depth > 6) return value === null ? null : undefined;
  const result = select(value, scalarKeys);
  if (typeof value.summary === 'string') result.summaryAvailableLocally = true;
  if (Array.isArray(value.differences)) result.differenceCount = value.differences.length;
  else if (Number.isSafeInteger(value.differenceCount)) result.differenceCount = value.differenceCount;
  if (object(value.completion)) {
    result.completion = select(value.completion, ['version', 'persisted', 'currentStateMatches', 'scope', 'outcome']);
    if (object(value.completion.activation)) result.completion.activation = select(value.completion.activation, ['required', 'targetId', 'documentRevision', 'loadedTargetId', 'loadedDocumentRevision', 'loaded', 'running', 'effective', 'reason']);
  }
  if (object(value.confirmation)) result.confirmation = select(value.confirmation, ['digest', 'version']);
  if (object(value.schemaArguments)) result.schemaArguments = value.schemaArguments;
  if (object(value.recovery)) result.recovery = { ...select(value.recovery, ['writeApplied', 'code', 'instruction']) };
  if (Array.isArray(value.issues)) {
    result.issues = issues(value.issues, limit === 0 ? 0 : 10);
    result.issueCount = value.issueCount ?? value.issues.length;
    result.issuesComplete = value.issuesComplete !== false && result.issues.length === value.issues.length;
  }
  if (object(value.validation)) result.validation = validationSummary(value.validation, root, id, limit);
  if (object(value.businessSummary)) result.businessSummary = { ...select(value.businessSummary, ['version', 'targetId', 'ruleCount', 'nodeSetCount']), detailsAvailable: true };
  if (Array.isArray(value.proposals)) {
    const ids = value.proposals.map(item => object(item) ? draftId(item) ?? item.operationId : undefined).filter(id => typeof id === 'string');
    result.proposalCount = value.proposals.length;
    result.proposalIds = limit > 0 ? ids : ids.slice(0, 50);
    result.proposalsComplete = result.proposalIds.length === value.proposals.length;
    result.proposalsTool = 'changes_status';
  } else if (Array.isArray(value.proposalIds)) {
    result.proposalIds = limit > 0 ? value.proposalIds : value.proposalIds.slice(0, 50);
    result.proposalsComplete = value.proposalsComplete !== false && result.proposalIds.length === value.proposalIds.length;
  }
  for (const key of ['proposal', 'change', 'operation', 'result']) {
    if (object(value[key]) || value[key] === null) result[key] = receipt(value[key], root, draftId(value[key] ?? {}) ?? id, limit, depth + 1);
  }
  if (object(value.assignedIds)) {
    result.assignedIdCount = Object.keys(value.assignedIds).length;
    if (limit > 0 && bytes(value.assignedIds) <= 1800) result.assignedIds = value.assignedIds;
    else result.assignedIdsComplete = false;
  } else if (Number.isSafeInteger(value.assignedIdCount)) Object.assign(result, select(value, ['assignedIdCount', 'assignedIdsComplete']));
  if (Array.isArray(value.createdResources)) {
    result.createdResourceCount = value.createdResources.length;
    if (limit > 0 && bytes(value.createdResources) <= 1800) result.createdResources = value.createdResources.map(row => select(row, ['id', 'actionIndex', 'kind']));
    else result.createdResourcesComplete = false;
  } else if (Number.isSafeInteger(value.createdResourceCount)) Object.assign(result, select(value, ['createdResourceCount', 'createdResourcesComplete']));
  result.detailsAvailable = true;
  if (id !== undefined) result.resourceReferences = references(root, id);
  return result;
}
export function modelResultValue(name, value) {
  if (!object(value)) return value;
  const containsReceipt = (item, depth = 0) => object(item) && depth <= 6 && (object(item.proposal) || Array.isArray(item.proposals) || object(item.completion) || typeof item.operationId === 'string' || ['result', 'operation', 'change'].some(key => containsReceipt(item[key], depth + 1)));
  const nestedReceipt = containsReceipt(value);
  if (!draftTools.has(name) && !receiptTools.has(name) && !mutationName(name) && value.taskEffect !== 'mutation' && !nestedReceipt) return value;
  const id = draftTools.has(name) ? draftId(value) : value.proposal?.id ?? value.result?.proposal?.id;
  let result = receipt(value, value, id, 2);
  if (bytes(result) > 6144) result = receipt(value, value, id, 0);
  if (bytes(value) > 6144 || value.contextTruncated === true) result.contextTruncated = true;
  return result;
}
