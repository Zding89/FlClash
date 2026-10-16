import { Agent } from '@earendil-works/pi-agent-core';
import { randomUUID } from 'node:crypto';
import { validId } from './protocol.mjs';
import { systemPrompt, workflowTool } from './workflows.mjs';
import { modelResultValue } from './model_results.mjs';
import { resolveSettings, providerStream, requestTransport, modelListRequest, fetchModels } from './providers.mjs';
export const MAX_CONTEXT_BYTES = 192 * 1024;
const emptyUsage = () => ({ input: 0, output: 0, cacheRead: 0, cacheWrite: 0, totalTokens: 0, cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 } });
const object = value => value !== null && typeof value === 'object' && !Array.isArray(value);
const bytes = value => Buffer.byteLength(JSON.stringify(value));
const safeCode = value => typeof value === 'string' && /^[A-Za-z][A-Za-z0-9_]{0,95}$/.test(value) ? value : 'commandFailed';
const toolContent = value => ({ content: [{ type: 'text', text: JSON.stringify(value) }], details: value });
function textParts(content) {
  if (!Array.isArray(content) || content.length > 128) throw new Error('invalidContext');
  return content.map(part => {
    if (!object(part) || part.type !== 'text' || typeof part.text !== 'string' || part.text.length > 262144) throw new Error('invalidContext');
    return { type: 'text', text: part.text };
  });
}
function canonicalMessage(message, model, output = false) {
  if (!object(message)) throw new Error('invalidContext');
  const timestamp = Number.isSafeInteger(message.timestamp) && message.timestamp >= 0 ? message.timestamp : Date.now();
  if (message.role === 'user') {
    const content = typeof message.content === 'string' ? message.content : textParts(message.content);
    if (typeof content === 'string' && content.length > 262144) throw new Error('invalidContext');
    return { role: 'user', content, timestamp };
  }
  if (message.role === 'assistant') {
    const source = typeof message.content === 'string' ? [{ type: 'text', text: message.content }] : message.content;
    if (!Array.isArray(source) || source.length > 128) throw new Error('invalidContext');
    const content = source.filter(part => output ? ['text', 'toolCall'].includes(part.type) : true).map(part => {
      if (part.type === 'text') return textParts([part])[0];
      if (part.type !== 'toolCall' || typeof part.id !== 'string' || !part.id || part.id.length > 200 || !validId(part.name) || !object(part.arguments)) throw new Error('invalidContext');
      return { type: 'toolCall', id: part.id, name: part.name, arguments: part.arguments };
    });
    for (const key of ['api', 'provider', 'model']) if (message[key] !== undefined && (typeof message[key] !== 'string' || message[key].length > 256)) throw new Error('invalidContext');
    return { role: 'assistant', content, api: message.api ?? model.api, provider: message.provider ?? model.provider, model: message.model ?? model.id, usage: emptyUsage(), stopReason: content.some(part => part.type === 'toolCall') ? 'toolUse' : 'stop', timestamp };
  }
  if (message.role === 'toolResult' && typeof message.toolCallId === 'string' && message.toolCallId.length > 0 && message.toolCallId.length <= 200 && validId(message.toolName) && typeof message.isError === 'boolean') {
    return { role: 'toolResult', toolCallId: message.toolCallId, toolName: message.toolName, content: textParts(message.content), isError: message.isError, timestamp };
  }
  throw new Error('invalidContext');
}
function pairedContext(messages) {
  const pending = new Map();
  for (const message of messages) {
    if (message.role === 'toolResult') {
      if (pending.get(message.toolCallId) !== message.toolName) throw new Error('invalidContext');
      pending.delete(message.toolCallId);
    } else {
      if (pending.size) throw new Error('invalidContext');
      if (message.role === 'assistant') for (const part of message.content) if (part.type === 'toolCall') {
        if (pending.has(part.id)) throw new Error('invalidContext');
        pending.set(part.id, part.name);
      }
    }
  }
  if (pending.size) throw new Error('invalidContext');
  return messages;
}
function inputContext(data, model) {
  const source = data.context ?? data.messages ?? [];
  if (!Array.isArray(source) || source.length > 100 || bytes(source) > MAX_CONTEXT_BYTES) throw new Error('invalidContext');
  return pairedContext(source.map(message => canonicalMessage(message, model)));
}
function redactKey(value, key) {
  if (typeof value === 'string') return key ? value.split(key).join('[REDACTED]') : value;
  if (Array.isArray(value)) return value.map(item => redactKey(item, key));
  if (object(value)) return Object.fromEntries(Object.entries(value).map(([name, item]) => [redactKey(name, key), redactKey(item, key)]));
  return value;
}
function contextSummary(message, force = false) {
  if (message.role !== 'toolResult') return message;
  let projected = false;
  message = { ...message, content: message.content.map(part => {
    try {
      const value = JSON.parse(part.text);
      const result = modelResultValue(message.toolName, value);
      projected ||= result !== value;
      return { type: 'text', text: JSON.stringify(result) };
    } catch { return part; }
  }) };
  if (projected) return message;
  if (!force && bytes(message.content) <= 8192) return message;
  if (!force && /(?:_query|_list|_read|_schema)$/.test(message.toolName)) return message;
  if (!force && ['application_catalog', 'policies_catalog', 'builtin_workflow_read'].includes(message.toolName) && bytes(message.content) <= 65536) return message;
  const content = message.content.map(part => {
    try {
      const value = JSON.parse(part.text);
      const select = item => {
        if (!object(item)) return undefined;
        const summary = { contextTruncated: true };
        for (const key of ['id', 'draftId', 'operationId', 'status', 'code', 'errorCode', 'replayed', 'version', 'documentVersion', 'total', 'nextCursor']) if (['string', 'number', 'boolean'].includes(typeof item[key])) summary[key] = typeof item[key] === 'string' ? item[key].slice(0, 256) : item[key];
        for (const key of ['businessSummary', 'validation', 'contract', 'patchSchema', 'completion']) if (item[key] !== undefined && bytes(item[key]) <= 65536) summary[key] = item[key];
        if (Array.isArray(item.commands)) summary.commands = item.commands.map(command => object(command) ? { name: command.name, description: typeof command.description === 'string' ? command.description.slice(0, 512) : undefined } : command).slice(0, 128);
        summary.rereadTool = message.toolName;
        for (const key of ['proposal', 'result']) if (object(item[key])) summary[key] = select(item[key]);
        return summary;
      };
      return { type: 'text', text: JSON.stringify(select(value) ?? { contextTruncated: true }) };
    } catch { return { type: 'text', text: `${part.text.slice(0, 1024)}\n[contextTruncated]` }; }
  });
  return { ...message, content };
}
function exportContext(messages, model, key) {
  const results = new Map(messages.filter(message => message.role === 'toolResult').map(message => [message.toolCallId, message]));
  const sourceMessages = messages.filter(message => ['user', 'assistant', 'toolResult'].includes(message.role));
  let canonical = sourceMessages.map(message => canonicalMessage(contextSummary(message), model, true));
  canonical = canonical.map(message => message.role !== 'assistant' ? message : { ...message, content: message.content.filter(part => part.type !== 'toolCall' || results.get(part.id)?.toolName === part.name) });
  const calls = new Set(canonical.flatMap(message => message.role === 'assistant' ? message.content.filter(part => part.type === 'toolCall').map(part => part.id) : []));
  canonical = canonical.filter(message => message.role !== 'toolResult' || calls.has(message.toolCallId));
  canonical = canonical.filter(message => message.role !== 'assistant' || message.content.length > 0);
  const groups = [];
  for (const message of canonical) {
    if (message.role === 'user' || !groups.length) groups.push([]);
    groups.at(-1).push(message);
  }
  const kept = [];
  for (const group of groups.reverse()) {
    if (group.length + kept.length > 100 || bytes([...group, ...kept]) > MAX_CONTEXT_BYTES) break;
    kept.unshift(...group);
  }
  const snapshots = new Map();
  for (const message of canonical) {
    if (message.role !== 'toolResult' || message.isError) continue;
    if (['policies_catalog', 'application_catalog'].includes(message.toolName)) snapshots.set(message.toolName, message);
    if (['policies_draft_read', 'policies_propose', 'policy_draft_read', 'policy_draft_edit'].includes(message.toolName)) {
      try { if (draftProof(JSON.parse(message.content[0]?.text))) snapshots.set('latestDraft', message); } catch {}
    }
  }
  const pinSnapshots = () => {
    const retainedCalls = new Set(kept.filter(message => message.role === 'toolResult').map(message => message.toolCallId));
    const pinned = [];
    for (const message of [...snapshots.values()].reverse()) {
      if (retainedCalls.has(message.toolCallId)) continue;
      const source = canonical.find(candidate => candidate.role === 'assistant' && candidate.content.some(part => part.type === 'toolCall' && part.id === message.toolCallId));
      if (!source) continue;
      const pair = [{ ...source, content: source.content.filter(part => part.type === 'toolCall' && part.id === message.toolCallId) }, contextSummary(message, true)];
      if (bytes([...pair, ...pinned]) > 65536 || pair.length + pinned.length >= 100) continue;
      pinned.unshift(...pair);
    }
    return pinned;
  };
  let pinned = pinSnapshots();
  if (pinned.length) {
    while (kept.length && (kept.length + pinned.length > 100 || bytes([...pinned, ...kept]) > MAX_CONTEXT_BYTES)) {
      const nextUser = kept.findIndex((message, index) => index > 0 && message.role === 'user');
      if (nextUser < 0) break;
      kept.splice(0, nextUser);
      pinned = pinSnapshots();
    }
    const firstUser = kept.findIndex(message => message.role === 'user');
    if (firstUser >= 0 && kept.length + pinned.length <= 100 && bytes([...pinned, ...kept]) <= MAX_CONTEXT_BYTES) kept.splice(firstUser + 1, 0, ...pinned);
  }
  if (kept.length === 0 && canonical.some(message => message.role === 'toolResult')) throw new Error('contextLimit');
  const result = pairedContext(redactKey(kept, key));
  return { messages: result, truncated: result.length < canonical.length || canonical.some(message => message.role === 'toolResult' && message.content.some(part => part.text.includes('contextTruncated'))) };
}
function resultStatus(value) {
  return typeof value.status === 'string' ? value.status : object(value.change) ? resultStatus(value.change) : object(value.operation) ? resultStatus(value.operation) : object(value.result) ? resultStatus(value.result) : undefined;
}
function hasDraft(value) {
  return object(value.proposal) && value.proposal.id !== undefined || ['draft', 'draft_ready'].includes(resultStatus(value)) && (value.id !== undefined || value.draftId !== undefined) || Array.isArray(value.proposals) && value.proposals.some(item => object(item) && hasDraft(item)) || object(value.result) && hasDraft(value.result);
}
function mutationResult(result) {
  if (['mutation', 'read'].includes(result.value.taskEffect)) return result.value.taskEffect === 'mutation';
  if (result.name === 'application_invoke') return result.isError || object(result.value.proposal) || typeof result.value.operationId === 'string' || object(result.value.result) && (object(result.value.result.proposal) || typeof result.value.result.operationId === 'string');
  return (result.name === 'policy_draft_edit' || /(?:_propose|_commit|_undo|_clear|_update|_set_enabled|_set_disabled|_select)$/.test(result.name)) && (result.isError || hasDraft(result.value) || resultStatus(result.value) !== undefined);
}
function currentStateMatch(value) {
  if (typeof value.currentStateMatches === 'boolean') return value.currentStateMatches;
  for (const key of ['change', 'operation', 'result']) if (object(value[key])) {
    const match = currentStateMatch(value[key]);
    if (match !== undefined) return match;
  }
}
function completionReceipt(value) {
  if (object(value.completion)) return value.completion;
  for (const key of ['change', 'operation', 'result']) if (object(value[key])) {
    const receipt = completionReceipt(value[key]);
    if (receipt) return receipt;
  }
}
function effectiveCompletion(receipt) {
  const activation = receipt?.activation;
  return receipt?.version === 1 && receipt.persisted === true && receipt.currentStateMatches === true && object(activation) && activation.required === true && activation.loaded === true && activation.running === true && typeof activation.targetId === 'string' && activation.targetId.length > 0 && activation.targetId === activation.loadedTargetId && Number.isSafeInteger(activation.documentRevision) && activation.documentRevision === activation.loadedDocumentRevision;
}
function savedCompletion(receipt) {
  return receipt?.version === 1 && receipt.persisted === true && receipt.currentStateMatches === true;
}
function completionSummary(receipt) {
  if (effectiveCompletion(receipt)) return '配置已保存，已核对当前运行的本地规则目标和版本一致。实际流量命中情况尚未验证。';
  if (receipt?.scope === 'local_policy') return ['integration_disabled', 'network_stopped'].includes(receipt.activation?.reason) ? '本地规则已保存，目前未用于当前网络；未切换网络或自动开启接管。' : '本地规则已保存，尚未确认当前网络使用的是此版本。';
  return '设置已保存，当前保存内容已核对一致。';
}
function replayedResult(value) {
  return value.replayed === true || ['change', 'operation', 'result'].some(key => object(value[key]) && replayedResult(value[key]));
}
function confirmed(value) {
  return ['completed', 'applied', 'saved', 'restored', 'rolled_back'].includes(resultStatus(value));
}
function resourceId(value, kind) {
  if (kind === 'proposal') {
    if (object(value.proposal) && value.proposal.id !== undefined) return String(value.proposal.id);
    if (['draft', 'draft_ready'].includes(resultStatus(value)) && (value.draftId !== undefined || value.id !== undefined)) return String(value.draftId ?? value.id);
  } else if (value.operationId !== undefined || value.id !== undefined) return String(value.operationId ?? value.id);
  return object(value.change) ? String(value.change.id) : object(value.operation) ? resourceId(value.operation, kind) : object(value.result) ? resourceId(value.result, kind) : undefined;
}
function draftProof(value) {
  if (!object(value)) return undefined;
  if (object(value.validation)) return value;
  return object(value.result) ? draftProof(value.result) : undefined;
}
function finishTool(run) {
  return {
    name: 'task_finish', label: 'task_finish', description: '根据SDK自动绑定的最新真实结果结束任务。草稿可审阅用draft_ready；已实际完成用completed。可选proposalId/operationId填写工具返回的资源ID，无需填写内部工具调用ID。needs_input/failed需具体reason，summary为最终中文答复，只总结一次。completed的completionGoal在要求保存时为saved、要求当前生效时为effective，effective必须有同目标同版本的当前运行证明。',
    parameters: { type: 'object', properties: { status: { type: 'string', enum: ['draft_ready', 'completed', 'needs_input', 'failed', 'chat'] }, summary: { type: 'string', minLength: 1, maxLength: 4096 }, completionGoal: { type: 'string', enum: ['saved', 'effective'] }, proposalId: { type: 'string', minLength: 1, maxLength: 200 }, operationId: { type: 'string', minLength: 1, maxLength: 200 }, evidenceToolCallIds: { type: 'array', items: { type: 'string', maxLength: 200 }, maxItems: 32 }, reason: { type: 'string', maxLength: 4096 } }, required: ['status', 'summary'], additionalProperties: false },
    replay: 'never', executionMode: 'sequential',
    execute: async (_, args) => {
      if (run.finished) return { ...toolContent({ code: 'taskAlreadyFinished' }), isError: true };
      const entries = [...run.results.entries()];
      const lastMutation = entries.findLastIndex(([, result]) => mutationResult(result));
      const lastLocalWrite = entries.findLastIndex(([, result]) => ['policies_propose', 'policy_draft_edit'].includes(result.name));
      const localDraft = args.status === 'draft_ready' && entries.some(([, result]) => ['policies_propose', 'policies_draft_read', 'policy_draft_edit', 'policy_draft_read'].includes(result.name));
      const latestDraftId = lastLocalWrite >= 0 ? resourceId(entries[lastLocalWrite][1].value, 'proposal') : undefined;
      const matchesResource = result => (args.proposalId === undefined || resourceId(result.value, 'proposal') === args.proposalId) && (args.operationId === undefined || resourceId(result.value, 'operation') === args.operationId);
      const lastWrite = entries[lastMutation]?.[1];
      const targetIds = new Set((lastWrite ? [resourceId(lastWrite.value, 'operation'), resourceId(lastWrite.value, 'proposal'), lastWrite.arguments?.id, lastWrite.arguments?.params?.operationId] : [args.operationId, args.proposalId]).filter(value => value !== undefined).map(String));
      const sameOperation = (result, index) => index === lastMutation && confirmed(result.value) || ['application_operation', 'changes_status', 'application_invoke'].includes(result.name) && targetIds.has(String(resourceId(result.value, 'operation'))) && (resultStatus(result.value) !== 'applied' || currentStateMatch(result.value) === true);
      const usable = (result, index) => index >= lastMutation && !result.isError && matchesResource(result) && !entries.some(([, later], laterIndex) => laterIndex > index && currentStateMatch(later.value) === false && targetIds.has(String(resourceId(later.value, 'operation')))) && (args.status === 'draft_ready' ? hasDraft(result.value) && (!localDraft || ['policies_draft_read', 'policy_draft_read'].includes(result.name) && index > lastLocalWrite && draftProof(result.value)?.validation.valid === true && (latestDraftId === undefined || resourceId(result.value, 'proposal') === latestDraftId)) : confirmed(result.value) && sameOperation(result, index) && currentStateMatch(result.value) !== false && (resultStatus(result.value) !== 'applied' || !replayedResult(result.value) || currentStateMatch(result.value) === true));
      const legacyUsable = usable;
      const completionUsable = (result, index) => {
        if (!legacyUsable(result, index)) return false;
        const receipt = completionReceipt(result.value);
        if (!receipt) return args.completionGoal !== 'effective';
        if (!['saved', 'effective'].includes(args.completionGoal) || !savedCompletion(receipt)) return false;
        if (args.completionGoal === 'effective' && !effectiveCompletion(receipt)) return false;
        if (index === lastMutation) return false;
        return !entries.some(([, later], laterIndex) => laterIndex > index && targetIds.has(String(resourceId(later.value, 'operation'))) && completionReceipt(later.value));
      };
      const suppliedIds = args.evidenceToolCallIds ?? [];
      const selected = suppliedIds.length > 0 ? suppliedIds.map(id => entries.findIndex(([candidate]) => candidate === id)) : ['draft_ready', 'completed'].includes(args.status) ? [entries.findLastIndex(([, result], index) => args.status === 'completed' ? completionUsable(result, index) : usable(result, index))] : [];
      const evidence = selected.map(index => entries[index]?.[1]);
      let valid = selected.every(index => index >= 0);
      if (args.status === 'chat') valid &&= lastMutation < 0;
      if (args.status === 'draft_ready') valid &&= selected.some(index => index >= 0 && usable(entries[index][1], index));
      if (args.status === 'completed') valid &&= selected.some(index => index >= 0 && completionUsable(entries[index][1], index)) && evidence.every(result => !result.isError && !['accepted', 'queued', 'running', 'pending', 'pending_confirmation', 'requires_user_action', 'failed', 'conflict', 'cancelled', 'unsupported'].includes(resultStatus(result.value)));
      if (['needs_input', 'failed'].includes(args.status)) valid &&= typeof args.reason === 'string' && args.reason.trim().length > 0;
      if (!valid) return { ...toolContent({ code: 'completionEvidenceRequired', status: args.status, ...(localDraft ? { required: 'policies_draft_read_latest_validated' } : args.status === 'completed' && lastWrite && completionReceipt(lastWrite.value) ? { required: 'fresh_same_operation_completion_with_explicit_goal', completionGoals: ['saved', 'effective'] } : {}) }), isError: true };
      const proofIndex = localDraft ? selected.findLast(index => usable(entries[index][1], index)) : undefined;
      const proof = proofIndex === undefined ? undefined : draftProof(entries[proofIndex][1].value);
      const reply = proof?.businessSummary?.reply;
      const completedProof = args.status === 'completed' ? selected.findLast(index => completionUsable(entries[index][1], index)) : undefined;
      const completion = completedProof === undefined ? undefined : completionReceipt(entries[completedProof][1].value);
      const summary = completion ? completionSummary(completion) : args.status === 'completed' && evidence.some(result => resultStatus(result.value) === 'applied') ? '操作记录已确认；当前网络是否使用该配置尚未验证。' : typeof reply === 'string' && reply.trim() ? reply : args.summary;
      run.finished = { ...args, summary, evidenceToolCallIds: selected.map(index => entries[index][0]) };
      return { ...toolContent(modelResultValue('task_finish', { status: args.status, summary, ...(args.reason ? { reason: args.reason } : {}) })), terminate: true };
    },
  };
}
export function providerErrorCode(message) {
  const text = String(message ?? '').slice(0, 4096);
  if (/\b402\b|insufficient.*(?:quota|balance|credit)|quota.*(?:exceeded|exhausted)/i.test(text)) return 'quotaExceeded';
  if (/\b401\b|\b403\b|unauthorized|authentication|invalid.*(?:api.?key|credential)/i.test(text)) return 'authenticationFailed';
  if (/\b429\b|rate.?limit/i.test(text)) return 'rateLimited';
  if (/timeout|timed.?out/i.test(text)) return 'requestTimeout';
  if (/ECONN|ENOTFOUND|connection|network|fetch failed/i.test(text)) return 'networkUnavailable';
  return 'providerRequestFailed';
}
export class AgentHost {
  constructor(send, streamFn = providerStream, networkFactory = requestTransport, clock = { now: () => performance.now(), setTimeout, clearTimeout }) { this.clock = clock; this.networkFactory = networkFactory; this.send = send; this.streamFn = streamFn; this.run = null; this.session = null; this.generation = 0; this.closed = false; }
  emit(run, type, data = {}) {
    if (this.closed || this.run !== run) return;
    this.send({ version: 1, sessionId: run.sessionId, generation: run.generation, requestId: run.requestId, type, data });
  }
  receive(frame) {
    if (this.closed) return;
    if (frame.type === 'listModels') { void this.listModels(frame); return; }
    if (frame.type === 'prompt') { void this.prompt(frame); return; }
    const run = this.run;
    if (!run || frame.sessionId !== run.sessionId || frame.generation !== run.generation) return;
    if (frame.type === 'cancel' && frame.requestId === run.requestId) { this.cancel(); return; }
    if (frame.type === 'close' && frame.requestId === run.requestId) { this.close(); return; }
    if (frame.type === 'approvalWait' && frame.requestId === run.requestId && typeof frame.data?.pending === 'boolean') {
      if (frame.data.pending && run.pending.size > 0) this.pauseDeadline(run);
      else if (!frame.data.pending) this.resumeDeadline(run);
      return;
    }
    if (frame.type === 'toolResult') {
      const pending = run.pending.get(frame.requestId);
      if (!pending || frame.data?.toolCallId !== pending.toolCallId || typeof frame.data?.isError !== 'boolean' || typeof frame.data?.value !== 'object' || frame.data.value === null || Array.isArray(frame.data.value)) return;
      run.toolResultBytes += Buffer.byteLength(JSON.stringify(frame.data.value));
      if (run.toolResultBytes > 4 * 1024 * 1024) { this.emit(run, 'error', { code: 'contextLimit' }); this.cancel(); return; }
      run.pending.delete(frame.requestId);
      pending.resolve(frame.data);
      if (!run.pending.size && run.approvalPending) this.resumeDeadline(run);
    }
  }
  async listModels(frame) {
    if (this.closed || this.run || (this.session !== null && frame.sessionId !== this.session) || frame.generation <= this.generation) return;
    this.session = frame.sessionId; this.generation = frame.generation;
    const run = { sessionId: frame.sessionId, generation: frame.generation, requestId: frame.requestId, cancelled: false, pending: new Map(), abort: new AbortController() };
    this.run = run;
    let network;
    let timer;
    let failed = false;
    try {
      const request = modelListRequest(frame.data?.settings, frame.data?.key);
      frame.data.key = '';
      network = this.networkFactory(request.proxyUrl);
      timer = setTimeout(() => { run.timedOut = true; run.abort.abort(); }, request.timeoutSeconds * 1000);
      const models = await fetchModels(request, network, run.abort.signal);
      if (!run.cancelled) this.emit(run, 'models', { models });
    } catch (error) {
      failed = true;
      const code = run.cancelled ? 'cancelled' : run.timedOut ? 'requestTimeout' : ['modelsUnsupported', 'modelListLimit', 'invalidModelList', 'keyMissing'].includes(error.message) ? error.message : providerErrorCode(error.message);
      if (!run.cancelled) this.emit(run, 'error', { code });
    } finally {
      clearTimeout(timer);
      if (frame.data) frame.data.key = '';
      try { await network?.close(); } catch {}
      this.emit(run, 'done', { cancelled: run.cancelled, failed });
      if (this.run === run) this.run = null;
    }
  }
  async prompt(frame) {
    if (this.closed || this.run || (this.session !== null && frame.sessionId !== this.session) || frame.generation <= this.generation) return;
    let settings;
    let history;
    try {
      settings = resolveSettings(frame.data?.settings);
      if (typeof frame.data?.key !== 'string' || frame.data.key.length < 1 || frame.data.key.length > 16384 || typeof frame.data?.user !== 'string' || !frame.data.user.trim() || frame.data.user.length > 262144 || !Array.isArray(frame.data.tools) || frame.data.tools.length > 128) throw new Error('invalidPrompt');
      const names = new Set();
      for (const tool of frame.data.tools) {
        if (!validId(tool.name) || ['builtin_workflow_read', 'task_finish', 'tools_catalog'].includes(tool.name) || names.has(tool.name) || typeof tool.description !== 'string' || tool.description.length > 4096 || tool.parameters?.type !== 'object') throw new Error('invalidTool');
        names.add(tool.name);
      }
      if (frame.data.recoveryRequired !== undefined && typeof frame.data.recoveryRequired !== 'boolean') throw new Error('invalidPrompt');
      history = inputContext(frame.data, settings.model);
    } catch { this.send({ version: 1, sessionId: frame.sessionId, generation: frame.generation, requestId: frame.requestId, type: 'error', data: { code: 'invalidPrompt' } }); return; }
    this.session = frame.sessionId; this.generation = frame.generation;
    const run = { sessionId: frame.sessionId, generation: frame.generation, requestId: frame.requestId, pending: new Map(), cancelled: false, turns: 0, outputBytes: 0, toolResultBytes: 0, key: frame.data.key, results: new Map(), corrections: 0, history, deadlineRemaining: settings.timeoutSeconds * 1000 * 3 };
    frame.data.key = '';
    this.run = run;
    const tools = frame.data.tools.map(tool => ({ ...tool, label: tool.name, replay: 'never', executionMode: 'sequential', execute: async (toolCallId, args, signal) => {
      if (run.finished) return { ...toolContent({ code: 'taskAlreadyFinished' }), isError: true };
      if (run.cancelled || signal?.aborted || this.run !== run) throw new Error('cancelled');
      if (run.pending.size >= 32) throw new Error('toolQueueLimit');
      const requestId = randomUUID();
      const result = await new Promise((resolve, reject) => {
        const abort = () => { run.pending.delete(requestId); reject(new Error('cancelled')); };
        signal?.addEventListener('abort', abort, { once: true });
        run.pending.set(requestId, { toolCallId, resolve: value => { signal?.removeEventListener('abort', abort); resolve(value); }, reject: () => { signal?.removeEventListener('abort', abort); reject(new Error('cancelled')); } });
        this.emit(run, 'toolRequest', { requestId, toolCallId, name: tool.name, arguments: args });
      });
      const value = result.isError ? { ...result.value, code: safeCode(result.value.code ?? result.value.errorCode) } : result.value;
      run.results.set(toolCallId, { name: tool.name, arguments: args, value, isError: result.isError });
      return { ...toolContent(modelResultValue(tool.name, value)), isError: result.isError };
    } }));
    const builtinTools = [workflowTool(topic => { run.workflow = topic; }), finishTool(run)];
    const businessNames = new Set(['workspace_overview', 'sources_query', 'nodes_query', 'node_sets_query', 'rules_query', 'policy_draft_edit', 'policy_draft_read', 'policy_preview', 'policy_edit_schema', 'changes_commit', 'changes_status', 'application_catalog', 'application_invoke', 'application_operation']);
    const layered = tools.some(tool => tool.name === 'workspace_overview');
    const active = new Map(tools.filter(tool => !layered || businessNames.has(tool.name)).map(tool => [tool.name, tool]));
    let agent;
    const catalogTool = {
      name: 'tools_catalog', label: 'tools_catalog',
      description: 'Discover application tools. With no names, read a compact directory. With names, load up to four exact schemas and enable those tools for this task. Never invent a capability.',
      parameters: { type: 'object', properties: { names: { type: 'array', items: { type: 'string', maxLength: 96 }, maxItems: 4 }, offset: { type: 'integer', minimum: 0 }, limit: { type: 'integer', minimum: 1, maximum: 20 } }, additionalProperties: false },
      replay: 'safe', executionMode: 'sequential',
      execute: async (_, args) => {
        if (args.names !== undefined) {
          if (!Array.isArray(args.names) || args.names.length > 4 || args.names.some(name => !tools.some(tool => tool.name === name))) return { ...toolContent({ code: 'toolUnavailable' }), isError: true };
          const selected = tools.filter(tool => args.names.includes(tool.name));
          const definitions = selected.map(({ name, description, parameters }) => ({ name, description, parameters }));
          if (bytes(definitions) > 65536) return { ...toolContent({ code: 'toolSchemaTooLarge' }), isError: true };
          selected.forEach(tool => active.set(tool.name, tool));
          agent.state.tools = [...active.values(), ...builtinTools, catalogTool];
          return toolContent({ tools: definitions, enabled: selected.map(tool => tool.name) });
        }
        const offset = Number.isSafeInteger(args.offset) && args.offset >= 0 ? args.offset : 0;
        const limit = Number.isSafeInteger(args.limit) ? Math.max(1, Math.min(args.limit, 20)) : 20;
        return toolContent({ tools: tools.slice(offset, offset + limit).map(tool => ({ name: tool.name, description: tool.description.slice(0, 120), enabled: active.has(tool.name) })), total: tools.length, ...(offset + limit < tools.length ? { nextOffset: offset + limit } : {}) });
      },
    };
    const network = this.networkFactory(settings.proxyUrl);
    agent = new Agent({
      initialState: { systemPrompt: `${systemPrompt}${frame.data.recoveryRequired === true ? '\n可信恢复要求：上一轮中断或上下文不完整。继续前先查询实际状态、已有草稿和 operation 状态；此前写入可能已执行，不能自动重放写入。证据不足时说明限制或请求必要输入。' : ''} 当前北京时间：${new Intl.DateTimeFormat('zh-CN', { timeZone: 'Asia/Shanghai', dateStyle: 'short', timeStyle: 'medium', hour12: false }).format(new Date())}；当前 Unix 毫秒：${Date.now()}。`, messages: history, model: settings.model, tools: [...active.values(), ...builtinTools, catalogTool], thinkingLevel: 'off' },
      getApiKey: () => run.key,
      toolExecution: 'sequential',
      streamFn: (model, context, options) => this.streamFn(model, context, { ...options, apiKey: run.key, timeoutMs: settings.timeoutSeconds * 1000, maxTokens: settings.maxTokens, maxRetries: 2, maxRetryDelayMs: 10000, cacheRetention: 'none', env: {}, fetch: network.fetch }),
      prepareRequest: async ({ context }) => {
        if (++run.turns > 20) { this.emit(run, 'error', { code: 'turnLimit' }); throw new Error('turnLimit'); }
        const compact = exportContext(context.messages, settings.model, run.key);
        run.contextTruncated ||= compact.truncated;
        return { context: { ...context, tools: [...active.values(), ...builtinTools, catalogTool], messages: [...context.messages.filter(message => message.role === 'system'), ...compact.messages] } };
      },
      finishTurn: async ({ message }) => {
        if (run.finished) return { action: 'end' };
        if (run.turns >= 20 && message.stopReason === 'toolUse') { run.limited = true; return { action: 'end' }; }
        const effects = [...run.results.values()].some(mutationResult);
        if (message.stopReason === 'stop' && effects && run.corrections < 2) {
          run.corrections++;
          run.correctionNeeded = true;
          return { action: 'continue' };
        }
      },
      prepareNextTurnWithContext: async ({ context }) => {
        if (!run.correctionNeeded) return { context: { ...context, tools: [...active.values(), ...builtinTools, catalogTool] } };
        run.correctionNeeded = false;
        return { context: { ...context, tools: [...active.values(), ...builtinTools, catalogTool], messages: [...context.messages, { role: 'system', content: '本轮已尝试修改，文字答复或问句不能代替完成状态。请根据当前实际工具结果完成仍未完成的工作，或调用 task_finish 明确 draft_ready/completed/needs_input/failed。本地草稿先 policy_draft_read（兼容入口 policies_draft_read）重读最新版本并核对 businessSummary 和 validation，再 draft_ready；仍需必要输入时用 needs_input，说明已有草稿及具体缺失信息。不得重放写入、把待确认当成功或为结束编造证据，也不为结束擅自提交。', timestamp: Date.now() }] } };
      },
    });
    run.agent = agent;
    let providerFailed = false;
    agent.subscribe(event => {
      if (run.cancelled) return;
      if (event.type === 'message_update' && typeof event.assistantMessageEvent.delta === 'string') {
        const delta = event.assistantMessageEvent.delta;
        run.outputBytes += Buffer.byteLength(delta);
        if (run.outputBytes > 4 * 1024 * 1024) { this.emit(run, 'error', { code: 'outputLimit' }); this.cancel(); return; }
      }
      if (event.type === 'message_end' && event.message.role === 'assistant' && ['stop', 'toolUse'].includes(event.message.stopReason)) {
        const content = event.message.content;
        const text = content.filter(part => part.type === 'text').map(part => part.text).join('');
        if (content.some(part => part.type === 'toolCall')) {
          run.finalCandidate = undefined;
          if (text.trim() && !content.some(part => part.type === 'toolCall' && part.name === 'task_finish')) this.emit(run, 'text', { text, messageId: randomUUID(), phase: 'progress' });
        } else if (text.trim()) run.finalCandidate = text;
      }
      if (event.type === 'turn_start') this.emit(run, 'status', { status: 'thinking', turn: run.turns + 1 });
      if (event.type === 'message_end' && event.message.role === 'assistant' && event.message.stopReason === 'error') { providerFailed = true; this.emit(run, 'error', { code: providerErrorCode(event.message.errorMessage) }); }
    });
    this.resumeDeadline(run);
    let failed = false;
    try {
      await agent.prompt({ role: 'user', content: frame.data.user, timestamp: Date.now() });
      if (run.limited) this.emit(run, 'error', { code: 'turnLimit' });
      failed = providerFailed || Boolean(run.limited);
      if (!run.cancelled && !run.finished && [...run.results.values()].some(mutationResult)) {
        failed = true;
        this.emit(run, 'error', { code: 'completionEvidenceRequired' });
      }
      if (!run.cancelled && !failed) {
        const text = run.finished?.summary ?? run.finalCandidate;
        if (text) this.emit(run, 'text', { text, messageId: randomUUID(), phase: 'final' });
      }
    } catch { failed = true; this.emit(run, 'error', { code: run.cancelled ? 'cancelled' : 'agentFailed' }); }
    finally {
      this.clock.clearTimeout(run.deadlineTimer);
      try { const context = exportContext(agent.state.messages, settings.model, run.key); this.emit(run, 'context', { ...context, truncated: context.truncated || Boolean(run.contextTruncated) }); } catch { failed = true; this.emit(run, 'error', { code: 'contextLimit' }); }
      run.key = ''; run.pending.forEach(p => p.reject()); run.pending.clear();
      try { await network.close(); } catch { failed = true; this.emit(run, 'error', { code: 'networkUnavailable' }); }
      this.emit(run, 'done', { cancelled: run.cancelled, failed, ...(run.finished ? { taskStatus: run.finished.status } : {}) });
      if (this.run === run) this.run = null;
    }
  }
  pauseDeadline(run) {
    if (run.approvalPending || run.deadlineRemaining === undefined) return;
    this.clock.clearTimeout(run.deadlineTimer);
    run.deadlineRemaining = Math.max(0, run.deadlineRemaining - (this.clock.now() - run.deadlineStarted));
    run.approvalPending = true;
  }
  resumeDeadline(run) {
    if (run.deadlineRemaining === undefined) return;
    if (run.deadlineTimer && !run.approvalPending) return;
    run.approvalPending = false;
    run.deadlineStarted = this.clock.now();
    run.deadlineTimer = this.clock.setTimeout(() => { this.emit(run, 'error', { code: 'timeout' }); this.cancel(); }, run.deadlineRemaining);
  }
  cancel() { const run = this.run; if (!run) return; run.cancelled = true; run.agent?.abort(); run.abort?.abort(); run.pending.forEach(p => p.reject()); run.pending.clear(); }
  close() { this.cancel(); this.closed = true; }
}
