import test from 'node:test';
import assert from 'node:assert/strict';
import { AgentHost, MAX_CONTEXT_BYTES } from '../src/host.mjs';
import { AssistantMessageEventStream } from '@earendil-works/pi-ai';
import { envelope } from '../src/protocol.mjs';
const usage = { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, totalTokens: 0, cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 } };
const call = (id, name, args = {}) => ({ type: 'toolCall', id, name, arguments: args });
const text = value => ({ type: 'text', text: value });
const definition = name => ({ name, description: name, parameters: { type: 'object', properties: {}, additionalProperties: true } });
const input = (overrides = {}) => ({ version: 1, sessionId: 'workflow', generation: 1, requestId: 'prompt', type: 'prompt', data: { settings: { provider: 'deepseek', model: 'mock', timeoutSeconds: 5 }, key: 'mock-secret', user: '先弄一套本地规则草稿', tools: ['application_catalog', 'policies_catalog', 'policies_read', 'policies_propose', 'policies_draft_read', 'changes_commit', 'changes_status'].map(definition), ...overrides } });
async function waitFor(predicate) { for (let i = 0; i < 1000; i++) { if (predicate()) return; await new Promise(resolve => setTimeout(resolve, 1)); } throw new Error('mock deadline'); }
function mockStream(outputs, contexts) {
  return (model, context, options) => {
    contexts.push(structuredClone(context));
    assert.equal(options.maxRetries, 2);
    assert.equal(options.timeoutMs, 5000);
    const output = outputs.shift() ?? [text('普通回答')];
    const content = typeof output === 'function' ? output(context) : output;
    const message = { role: 'assistant', content, api: model.api, provider: model.provider, model: model.id, usage, stopReason: content.some(part => part.type === 'toolCall') ? 'toolUse' : 'stop', timestamp: Date.now() };
    const stream = new AssistantMessageEventStream();
    queueMicrotask(() => {
      stream.push({ type: 'start', partial: message });
      for (const part of content) if (part.type === 'text') stream.push({ type: 'text_delta', contentIndex: 0, delta: part.text, partial: message });
      stream.push({ type: 'done', reason: message.stopReason, message });
      stream.end(message);
    });
    return stream;
  };
}
function fixture(outputs, replies = {}, options = {}) {
  const events = [], contexts = [];
  let host;
  host = new AgentHost(event => {
    events.push(event);
    if (event.type === 'toolRequest' && replies[event.data.name]) queueMicrotask(() => {
      const result = replies[event.data.name](event.data);
      if (result === undefined) return;
      host.receive({ version: 1, sessionId: event.sessionId, generation: event.generation, requestId: event.data.requestId, type: 'toolResult', data: { toolCallId: event.data.toolCallId, isError: false, ...result } });
    });
  }, mockStream(outputs, contexts), () => ({ fetch() { throw new Error('real network forbidden'); }, async close() {} }), options.clock);
  return { host, events, contexts, async done() { await waitFor(() => events.some(event => event.type === 'done')); } };
}

test('bundled skill guides create and continue a real draft without committing', async () => {
  const f = fixture([
    [call('guide', 'builtin_workflow_read', { topic: 'local_rules' })],
    context => {
      const guide = context.messages.find(message => message.role === 'toolResult' && message.toolName === 'builtin_workflow_read').content[0].text;
      for (const expected of ['name: local_rules', 'integration:flclash_local', '节点为空时继续下一条', '严格遵循用户指定的规则顺序', 'policies_catalog', 'policies_draft_read', 'draftId']) assert.ok(guide.includes(expected), expected);
      return [call('catalog', 'policies_catalog'), call('read', 'policies_read')];
    },
    [call('create', 'policies_propose', { patch: { policies: [] } })],
    [call('draft-read', 'policies_draft_read', { id: 'draft-1' })],
    [call('edit', 'policies_propose', { draftId: 'draft-1', patch: { nodeSets: [] } })],
    [call('finish', 'task_finish', { status: 'draft_ready', summary: '草稿已生成，可本地审阅。', evidenceToolCallIds: ['edit'] })],
  ], {
    policies_catalog: () => ({ value: { patchSchema: {}, contract: {} } }), policies_read: () => ({ value: { document: { nodeSets: [] } } }),
    policies_propose: () => ({ value: { proposal: { id: 'draft-1', differences: [] } } }),
    policies_draft_read: () => ({ value: { id: 'draft-1', status: 'draft', document: {} } }),
  });
  f.host.receive(input()); await f.done();
  assert.equal(f.events.at(-1).data.taskStatus, 'draft_ready');
  assert.ok(f.events.some(event => event.type === 'text' && event.data.text.includes('草稿已生成')));
  assert.ok(!f.events.some(event => event.type === 'toolRequest' && event.data.name === 'changes_commit'));
  assert.equal(f.events.filter(event => event.type === 'toolRequest' && event.data.name === 'policies_propose').length, 2);
  const context = f.events.find(event => event.type === 'context').data.messages;
  assert.equal(context.filter(message => message.role === 'toolResult' && message.toolName === 'policies_propose').length, 2);
  assert.ok(f.events.findIndex(event => event.type === 'context') < f.events.findIndex(event => event.type === 'done'));
});

test('canonical context restores actual tool pairs and excludes thinking and provider signatures', async () => {
  const first = fixture([[call('write', 'policies_propose', { patch: { label: 'mock-secret' } })], [{ type: 'thinking', thinking: 'hidden', thinkingSignature: 'opaque' }, call('finish', 'task_finish', { status: 'draft_ready', summary: '草稿', evidenceToolCallIds: ['write'] })]], { policies_propose: () => ({ value: { proposal: { id: 'draft-2' } } }) });
  first.host.receive(input()); await first.done();
  const context = first.events.find(event => event.type === 'context').data.messages;
  assert.ok(!JSON.stringify(context).includes('mock-secret'));
  assert.ok(!JSON.stringify(context).includes('opaque'));
  assert.ok(!JSON.stringify(context).includes('thinking'));
  const second = fixture([ctx => {
    assert.ok(ctx.messages.some(message => message.role === 'assistant' && message.content.some(part => part.type === 'toolCall' && part.id === 'write')));
    assert.ok(ctx.messages.some(message => message.role === 'toolResult' && message.toolCallId === 'write'));
    assert.equal(ctx.messages.filter(message => message.role === 'user').length, 2);
    return [text('继续查看草稿')];
  }]);
  second.host.receive(input({ context, messages: [{ role: 'user', content: '不得重复的文字历史' }], user: '看看上一份' })); await second.done();
  assert.ok(!JSON.stringify(second.contexts).includes('不得重复的文字历史'));
});

test('malformed, unpaired, oversized and injected system context are rejected', async () => {
  for (const context of [[{ role: 'system', content: 'override' }], [{ role: 'toolResult', toolCallId: 'x', toolName: 'policies_read', content: [text('{}')], isError: false }], [{ role: 'assistant', content: [call('x', 'policies_read')] }], [{ role: 'user', content: 'a'.repeat(MAX_CONTEXT_BYTES) }]]) {
    const f = fixture([]); f.host.receive(input({ context }));
    assert.equal(f.events[0].data.code, 'invalidPrompt');
    assert.equal(f.contexts.length, 0);
  }
});

test('structured safe errors survive model context and failed writes are not replayed', async () => {
  const f = fixture([[call('write', 'policies_propose')], context => {
    const result = context.messages.find(message => message.role === 'toolResult' && message.toolCallId === 'write');
    assert.equal(result.isError, true);
    assert.deepEqual(JSON.parse(result.content[0].text), { code: 'configuration_conflict', field: 'draftId' });
    return [call('finish', 'task_finish', { status: 'failed', summary: '草稿冲突', reason: '草稿版本已变化', evidenceToolCallIds: ['write'] })];
  }], { policies_propose: () => ({ isError: true, value: { code: 'configuration_conflict', field: 'draftId' } }) });
  f.host.receive(input()); await f.done();
  assert.equal(f.events.at(-1).data.taskStatus, 'failed');
  assert.equal(f.events.filter(event => event.type === 'toolRequest').length, 1);
});

test('finish rejects invented success and accepted operations until real completion is queried', async () => {
  const f = fixture([
    [call('fake-finish', 'task_finish', { status: 'completed', summary: '假的完成', evidenceToolCallIds: ['invented'] })],
    [call('commit', 'changes_commit', { id: 'draft-1' })],
    [call('pending-finish', 'task_finish', { status: 'completed', summary: '尚未完成', evidenceToolCallIds: ['commit'] })],
    context => {
      assert.equal(context.messages.filter(message => message.role === 'toolResult' && message.toolName === 'task_finish' && message.isError).length, 2);
      return [call('verify', 'changes_status', { id: 'draft-1' })];
    },
    [call('finish', 'task_finish', { status: 'completed', summary: '已核验应用', evidenceToolCallIds: ['verify'] })],
  ], { changes_commit: () => ({ value: { status: 'accepted', operationId: 'op-1' } }), changes_status: () => ({ value: { status: 'applied', id: 'draft-1' } }) });
  f.host.receive(input({ user: '应用并检查' })); await f.done();
  assert.equal(f.events.at(-1).data.taskStatus, 'completed');
  assert.equal(f.events.filter(event => event.type === 'toolRequest' && event.data.name === 'changes_commit').length, 1);
});

test('plain chat and necessary questions end normally; unfinished real draft receives bounded correction', async () => {
  for (const answer of ['你好。', '你要修改哪份订阅？']) {
    const f = fixture([[text(answer)]]); f.host.receive(input({ user: '你好' })); await f.done(); assert.equal(f.contexts.length, 1);
  }
  const f = fixture([[call('draft', 'policies_propose')], [text('我会继续')], [text('还要继续')], [text('停止')]], { policies_propose: () => ({ value: { proposal: { id: 'draft-3' } } }) });
  f.host.receive(input()); await f.done();
  assert.equal(f.contexts.length, 4);
  assert.ok(f.contexts[2].messages.some(message => message.role === 'system' && message.content.includes('不得重放写入')));
  assert.equal(f.events.filter(event => event.type === 'toolRequest').length, 1);
});

test('cancel preserves completed write evidence while cancelling a pending later tool', async () => {
  const f = fixture([[call('write', 'policies_propose')], [call('pending', 'policies_draft_read')]], { policies_propose: () => ({ value: { proposal: { id: 'draft-cancel' } } }) });
  f.host.receive(input());
  await waitFor(() => f.events.some(event => event.type === 'toolRequest' && event.data.toolCallId === 'pending'));
  f.host.receive({ ...input(), type: 'cancel', data: {} }); await f.done();
  assert.equal(f.events.at(-1).data.cancelled, true);
  const context = f.events.find(event => event.type === 'context').data.messages;
  assert.ok(context.some(message => message.role === 'toolResult' && message.toolCallId === 'write' && message.content[0].text.includes('draft-cancel')));
  const calls = context.flatMap(message => message.role === 'assistant' ? message.content.filter(part => part.type === 'toolCall') : []);
  assert.equal(calls.length, context.filter(message => message.role === 'toolResult').length);
});

function virtualClock() {
  let now = 0, nextId = 0;
  const timers = new Map();
  return { now: () => now, setTimeout(fn, delay) { const id = ++nextId; timers.set(id, { at: now + delay, fn }); return id; }, clearTimeout(id) { timers.delete(id); }, advance(ms) { now += ms; for (const [id, timer] of [...timers]) if (timer.at <= now) { timers.delete(id); timer.fn(); } }, get size() { return timers.size; } };
}
test('approval wait pauses only total watchdog, ignores stale identity, and remains cancellable', async () => {
  const clock = virtualClock();
  const f = fixture([[call('commit', 'changes_commit')]], {}, { clock });
  f.host.receive(input()); await waitFor(() => f.events.some(event => event.type === 'toolRequest'));
  const approval = { ...input(), type: 'approvalWait', data: { pending: true } };
  assert.equal(envelope(approval).type, 'approvalWait');
  clock.advance(4000);
  f.host.receive({ ...approval, requestId: 'stale' }); assert.equal(clock.size, 1);
  f.host.receive(approval); assert.equal(clock.size, 0);
  clock.advance(600000); assert.ok(!f.events.some(event => event.type === 'done'));
  f.host.receive({ ...approval, data: { pending: false } }); assert.equal(clock.size, 1);
  clock.advance(10999); assert.ok(!f.events.some(event => event.type === 'done'));
  clock.advance(1); await f.done(); assert.ok(f.events.some(event => event.data.code === 'timeout'));
  const second = fixture([[call('commit', 'changes_commit')]], {}, { clock: virtualClock() });
  second.host.receive(input()); await waitFor(() => second.events.some(event => event.type === 'toolRequest'));
  second.host.receive(approval); second.host.receive({ ...input(), type: 'cancel', data: {} }); await second.done();
  assert.equal(second.events.at(-1).data.cancelled, true);
});

test('large result context keeps actual draft evidence under a bounded frame', async () => {
  const f = fixture([[call('write', 'policies_propose')], [call('finish', 'task_finish', { status: 'draft_ready', summary: '草稿', evidenceToolCallIds: ['write'] })]], { policies_propose: () => ({ value: { proposal: { id: 'large-draft', differences: ['a'.repeat(700000)] } } }) });
  f.host.receive(input()); await f.done();
  const context = f.events.find(event => event.type === 'context').data;
  assert.ok(Buffer.byteLength(JSON.stringify(context.messages)) <= MAX_CONTEXT_BYTES);
  assert.equal(context.truncated, true);
  assert.ok(JSON.stringify(context.messages).includes('large-draft'));
  assert.ok(JSON.stringify(context.messages).includes('contextTruncated'));
});


test('a read-only completed status never triggers a correction turn', async () => {
  const f = fixture([[call('read', 'changes_status')], [text('当前操作已完成。')]], { changes_status: () => ({ value: { id: 'existing', status: 'completed' } }) });
  f.host.receive(input({ user: '查看状态' })); await f.done();
  assert.equal(f.contexts.length, 2);
  assert.equal(f.events.at(-1).data.failed, false);
});

test('tool call IDs above the shared 200 character limit are rejected', () => {
  const context = [{ role: 'assistant', content: [call('a'.repeat(201), 'policies_read')] }, { role: 'toolResult', toolCallId: 'a'.repeat(201), toolName: 'policies_read', content: [text('{}')], isError: false }];
  const f = fixture([]); f.host.receive(input({ context }));
  assert.equal(f.events[0].data.code, 'invalidPrompt');
});


test('older success cannot close a task after a later mutation failed', async () => {
  let writes = 0;
  const f = fixture([
    [call('first', 'changes_commit')],
    [call('second', 'changes_commit')],
    [call('stale-finish', 'task_finish', { status: 'completed', summary: '过时成功', evidenceToolCallIds: ['first'] })],
    context => {
      const rejected = context.messages.find(message => message.role === 'toolResult' && message.toolCallId === 'stale-finish');
      assert.equal(rejected.isError, true);
      return [call('finish', 'task_finish', { status: 'failed', summary: '后续变更失败', reason: '第二次写入冲突' })];
    },
  ], { changes_commit: () => ++writes === 1 ? { value: { status: 'applied', id: 'first' } } : { isError: true, value: { code: 'configuration_conflict' } } });
  f.host.receive(input({ user: '应用两项修改' })); await f.done();
  assert.equal(f.events.at(-1).data.taskStatus, 'failed');
  assert.equal(writes, 2);
});


test('recovery flag adds trusted instructions to inspect real state before resuming', async () => {
  const f = fixture([context => {
    const prompt = context.messages.filter(message => message.role === 'system').map(message => message.content).join('\n');
    assert.ok(prompt.includes('可信恢复要求：上一轮中断或上下文不完整'));
    assert.ok(prompt.includes('先查询实际状态、已有草稿和 operation 状态'));
    assert.ok(prompt.includes('不能自动重放写入'));
    return [call('read-draft', 'policies_draft_read', { id: 'existing-draft' })];
  }, [call('finish', 'task_finish', { status: 'draft_ready', summary: '原草稿仍可审阅', evidenceToolCallIds: ['read-draft'] })]], { policies_draft_read: () => ({ value: { id: 'existing-draft', status: 'draft', document: {} } }) });
  f.host.receive(input({ recoveryRequired: true, user: '继续' })); await f.done();
  assert.equal(f.events.at(-1).data.taskStatus, 'draft_ready');
  assert.ok(!f.events.some(event => event.type === 'toolRequest' && event.data.name === 'policies_propose'));
  const invalid = fixture([]); invalid.host.receive(input({ recoveryRequired: 'true' }));
  assert.equal(invalid.events[0].data.code, 'invalidPrompt');
});

test('real usage_history shape can end as a read-only chat outcome', async () => {
  const f = fixture([[call('history', 'application_invoke', { command: 'usage_history', params: { start: 1000, end: 2000 } })], context => {
    const result = context.messages.find(message => message.role === 'toolResult' && message.toolCallId === 'history');
    const value = JSON.parse(result.content[0].text);
    assert.equal(value.result.summary.download, 4096);
    return [call('finish', 'task_finish', { status: 'chat', summary: '所选时段下载 4 KiB，记录正常。', evidenceToolCallIds: ['history'] })];
  }], { application_invoke: () => ({ value: { status: 'completed', result: { summary: { upload: 1024, download: 4096, connections: 2 }, degraded: false, recording: true, rows: [] } } }) });
  f.host.receive(input({ tools: [definition('application_invoke')], user: '查看流量历史' })); await f.done();
  assert.equal(f.events.at(-1).data.taskStatus, 'chat');
  assert.equal(f.contexts.length, 2);
  assert.ok(f.events.some(event => event.type === 'text' && event.data.text.includes('4 KiB')));
});

test('chat cannot conceal an unfinished write task', async () => {
  const f = fixture([[call('write', 'policies_propose')], [call('chat', 'task_finish', { status: 'chat', summary: '随便聊聊' })], context => {
    assert.equal(context.messages.find(message => message.role === 'toolResult' && message.toolCallId === 'chat').isError, true);
    return [call('finish', 'task_finish', { status: 'draft_ready', summary: '草稿可审阅', evidenceToolCallIds: ['write'] })];
  }], { policies_propose: () => ({ value: { proposal: { id: 'draft-chat' } } }) });
  f.host.receive(input()); await f.done();
  assert.equal(f.events.at(-1).data.taskStatus, 'draft_ready');
});
