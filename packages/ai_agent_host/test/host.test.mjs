import test from 'node:test';
import assert from 'node:assert/strict';
import { Writable } from 'node:stream';
import { AgentHost, providerErrorCode } from '../src/host.mjs';
import { JsonLineReader, JsonLineWriter, MAX_FRAME_BYTES } from '../src/protocol.mjs';
import { AssistantMessageEventStream } from '@earendil-works/pi-ai';
import { resolveSettings } from '../src/providers.mjs';
const usage = { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, totalTokens: 0, cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 } };
function fakeStream(outputs) {
  return (model, context, options) => {
    assert.equal(options.apiKey, 'test-secret');
    assert.equal(options.maxRetries, 2);
    assert.equal(options.timeoutMs, 5000);
    assert.ok(!JSON.stringify(context).includes('test-secret'));
    const stream = new AssistantMessageEventStream();
    const content = outputs.shift() ?? [{ type: 'text', text: 'done' }];
    const message = { role: 'assistant', content, api: model.api, provider: model.provider, model: model.id, usage, stopReason: content.some(c => c.type === 'toolCall') ? 'toolUse' : 'stop', timestamp: Date.now() };
    queueMicrotask(() => {
      stream.push({ type: 'start', partial: message });
      for (const part of content) if (part.type === 'text') stream.push({ type: 'text_delta', contentIndex: 0, delta: part.text, partial: message });
      stream.push({ type: 'done', reason: message.stopReason, message });
      stream.end(message);
    });
    return stream;
  };
}
function frame(type = 'prompt', generation = 1, requestId = 'prompt-1') {
  return { version: 1, sessionId: 'session-1', generation, requestId, type, data: { settings: { provider: 'deepseek', model: 'test-model', timeoutSeconds: 5 }, key: 'test-secret', user: 'hello', messages: [], tools: [{ name: 'read_config', description: 'Read configuration', parameters: { type: 'object', properties: {}, additionalProperties: false } }] } };
}
const waitFor = async predicate => { for (let i = 0; i < 1000; i++) { if (predicate()) return; await new Promise(r => setTimeout(r, 1)); } throw new Error('test timeout'); };
test('real Pi Agent streams text with a transient key', async () => {
  const events = [];
  const host = new AgentHost(event => events.push(event), fakeStream([[{ type: 'text', text: 'hello' }]]));
  const input = frame(); host.receive(input);
  await waitFor(() => events.some(e => e.type === 'done'));
  assert.equal(input.data.key, '');
  assert.equal(events.find(e => e.type === 'text').data.text, 'hello');
  assert.equal(host.run, null);
  assert.ok(!JSON.stringify(events).includes('test-secret'));
});
test('tool results must match session, generation and call identity', async () => {
  const events = [];
  const host = new AgentHost(event => events.push(event), fakeStream([[{ type: 'toolCall', id: 'call-1', name: 'read_config', arguments: {} }], [{ type: 'text', text: 'applied' }]]));
  host.receive(frame());
  await waitFor(() => events.some(e => e.type === 'toolRequest'));
  const request = events.find(e => e.type === 'toolRequest').data;
  const response = { ...frame('toolResult', 1, request.requestId), data: { toolCallId: 'call-1', isError: false, value: { safe: true } } };
  host.receive({ ...response, sessionId: 'old-session' });
  host.receive({ ...response, generation: 2 });
  host.receive({ ...response, data: { ...response.data, toolCallId: 'wrong' } });
  assert.equal(host.run.pending.size, 1);
  host.receive(response);
  await waitFor(() => events.some(e => e.type === 'done'));
  assert.equal(events.find(e => e.type === 'text').data.text, 'applied');
});
test('cancellation aborts pending tools, late replies never resume', async () => {
  const events = [];
  const host = new AgentHost(event => events.push(event), fakeStream([[{ type: 'toolCall', id: 'call-1', name: 'read_config', arguments: {} }]]));
  host.receive(frame());
  await waitFor(() => events.some(e => e.type === 'toolRequest'));
  host.receive(frame('cancel'));
  await waitFor(() => events.some(e => e.type === 'done'));
  assert.equal(events.at(-1).data.cancelled, true);
  assert.ok(!events.some(e => e.type === 'text'));
  host.receive(frame('prompt', 1));
  assert.equal(host.run, null);
});
test('20 model turns terminate even if tools request continuation', async () => {
  const events = [];
  const outputs = Array.from({ length: 25 }, (_, i) => [{ type: 'toolCall', id: `call-${i}`, name: 'read_config', arguments: {} }]);
  let host;
  host = new AgentHost(event => {
    events.push(event);
    if (event.type === 'toolRequest') queueMicrotask(() => host.receive({ ...frame('toolResult', 1, event.data.requestId), data: { toolCallId: event.data.toolCallId, isError: false, value: {} } }));
  }, fakeStream(outputs));
  host.receive(frame());
  await waitFor(() => events.some(e => e.type === 'done'));
  assert.equal(events.filter(e => e.type === 'toolRequest').length, 20);
  assert.ok(events.some(e => e.data.code === 'turnLimit'));
});
test('frames reject oversized lines and malformed identities', () => {
  let errors = 0; const values = [];
  const reader = new JsonLineReader(value => values.push(value), () => errors++);
  const line = Buffer.from(JSON.stringify(frame()) + '\n');
  reader.push(line.subarray(0, 15)); reader.push(line.subarray(15));
  assert.equal(values.length, 1);
  reader.push(Buffer.alloc(MAX_FRAME_BYTES + 1, 65));
  assert.equal(errors, 1);
});
test('blocked output queues remain bounded', () => {
  let errors = 0;
  const stream = new Writable({ highWaterMark: 1, write() {} });
  const writer = new JsonLineWriter(stream, () => errors++);
  for (let i = 0; i < 8; i++) writer.send({ value: 'a'.repeat(700000) });
  assert.equal(errors, 1);
  assert.equal(writer.bytes, 0);
});
test('provider endpoint distinction and custom HTTPS validation', () => {
  const coding = resolveSettings({ provider: 'glm-coding-cn', model: 'glm-5' });
  const ordinary = resolveSettings({ provider: 'glm-cn', model: 'glm-5' });
  assert.notEqual(coding.model.baseUrl, ordinary.model.baseUrl);
  assert.equal(resolveSettings({ provider: 'kimi-coding', model: 'kimi-for-coding' }).model.api, 'anthropic-messages');
  assert.throws(() => resolveSettings({ provider: 'custom', model: 'test', baseUrl: 'http://remote.example/v1' }));
  assert.throws(() => resolveSettings({ provider: 'custom', model: 'test', baseUrl: 'https://user:key@example.org' }));
  assert.throws(() => resolveSettings({ provider: 'deepseek', model: 'test', baseUrl: 'http://127.0.0.1:40291' }));
});

test('provider failures expose safe categories without server content', () => {
  assert.equal(providerErrorCode('401 invalid api key secret-echo'), 'authenticationFailed');
  assert.equal(providerErrorCode('429 rate_limit_exceeded'), 'rateLimited');
  assert.equal(providerErrorCode('insufficient_quota secret-echo'), 'quotaExceeded');
  assert.equal(providerErrorCode('request timed out'), 'requestTimeout');
  assert.equal(providerErrorCode('fetch failed'), 'networkUnavailable');
  assert.equal(providerErrorCode('server returned secret-echo'), 'providerRequestFailed');
});

test('large repeated tool results hit a bounded context budget', async () => {
  const events = [];
  const outputs = Array.from({ length: 10 }, (_, i) => [{ type: 'toolCall', id: `call-${i}`, name: 'read_config', arguments: {} }]);
  let host;
  host = new AgentHost(event => {
    events.push(event);
    if (event.type === 'toolRequest') queueMicrotask(() => host.receive({ ...frame('toolResult', 1, event.data.requestId), data: { toolCallId: event.data.toolCallId, isError: false, value: { text: 'a'.repeat(700000) } } }));
  }, fakeStream(outputs));
  host.receive(frame());
  await waitFor(() => events.some(e => e.type === 'done'));
  assert.ok(events.some(e => e.data.code === 'contextLimit'));
  assert.ok(events.filter(e => e.type === 'toolRequest').length < 10);
});
