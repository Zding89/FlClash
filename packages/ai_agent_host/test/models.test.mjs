import test from 'node:test';
import assert from 'node:assert/strict';
import { AgentHost } from '../src/host.mjs';
import { fetchModels, modelListRequest } from '../src/providers.mjs';
const frame = (settings = {}) => ({ version: 1, sessionId: 'models-session', generation: 1, requestId: 'models-request', type: 'listModels', data: { settings: { provider: 'deepseek', model: '', timeoutSeconds: 5, ...settings }, key: 'test-key' } });
const settle = async predicate => {
  for (let i = 0; i < 100; i++) { if (predicate()) return; await new Promise(resolve => setTimeout(resolve, 1)); }
  throw new Error('test timeout');
};
test('discovery uses documented routes and credentials without a chosen model', () => {
  const expected = {
    deepseek: 'https://api.deepseek.com/models',
    openai: 'https://api.openai.com/v1/models',
    anthropic: 'https://api.anthropic.com/v1/models?limit=100',
    'kimi-cn': 'https://api.moonshot.cn/v1/models',
    'kimi-global': 'https://api.moonshot.ai/v1/models',
    'kimi-coding': 'https://api.kimi.com/coding/v1/models',
    xai: 'https://api.x.ai/v1/models',
  };
  for (const [provider, url] of Object.entries(expected)) {
    const request = modelListRequest({ provider, model: '' }, 'test-key');
    assert.equal(request.url.href, url);
    assert.equal(request.headers[provider === 'anthropic' ? 'x-api-key' : 'authorization'], provider === 'anthropic' ? 'test-key' : 'Bearer test-key');
  }
  for (const provider of ['glm-cn', 'glm-coding-cn', 'glm-global', 'glm-coding-global']) assert.throws(() => modelListRequest({ provider }, 'test-key'), /modelsUnsupported/);
  assert.equal(modelListRequest({ provider: 'custom', api: 'anthropic-messages', baseUrl: 'https://example.com/v1/' }, 'key').url.pathname, '/v1/models');
  assert.throws(() => modelListRequest({ provider: 'custom', baseUrl: 'https://key@example.com' }, 'key'), /invalidEndpoint/);
});
test('discovery returns actual models and never invokes a paid stream', async () => {
  const events = [];
  let requests = 0;
  let closed = false;
  const host = new AgentHost(event => events.push(event), () => { throw new Error('paid stream called'); }, () => ({
    fetch: async (url, init) => { requests++; assert.equal(url.pathname, '/models'); assert.equal(init.method, 'GET'); return new Response(JSON.stringify({ data: [{ id: 'actual-model' }] })); },
    close: async () => { closed = true; },
  }));
  const request = frame();
  host.receive(request);
  await settle(() => events.some(event => event.type === 'done'));
  assert.equal(request.data.key, '');
  assert.equal(requests, 1);
  assert.equal(closed, true);
  assert.deepEqual(events.find(event => event.type === 'models').data.models, [{ id: 'actual-model', name: 'actual-model' }]);
  host.close();
});
test('anthropic pagination stays at the configured origin and is bounded', async () => {
  const paths = [];
  const request = modelListRequest({ provider: 'anthropic' }, 'key');
  const network = { fetch: async url => {
    paths.push(url.href);
    return new Response(JSON.stringify(paths.length === 1 ? { data: [{ id: 'first', display_name: 'First' }], has_more: true, last_id: 'first' } : { data: [{ id: 'second' }], has_more: false }));
  } };
  assert.equal((await fetchModels(request, network, new AbortController().signal)).length, 2);
  assert.equal(new URL(paths[1]).searchParams.get('after_id'), 'first');
  const repeated = { fetch: async () => new Response(JSON.stringify({ data: [{ id: 'first' }], has_more: true, last_id: 'first' })) };
  await assert.rejects(fetchModels(modelListRequest({ provider: 'anthropic' }, 'key'), repeated, new AbortController().signal), /invalidModelList/);
  await assert.rejects(fetchModels(request, { fetch: async () => new Response('x'.repeat(512 * 1024 + 1)) }, new AbortController().signal), /modelListLimit/);
});
test('cancellation aborts discovery and suppresses a late response', async () => {
  const events = [];
  let release;
  let signal;
  const host = new AgentHost(event => events.push(event), undefined, () => ({ fetch: (url, init) => { signal = init.signal; return new Promise(resolve => { release = resolve; }); }, close: async () => {} }));
  host.receive(frame());
  host.receive({ ...frame(), type: 'cancel', data: {} });
  assert.equal(signal.aborted, true);
  release(new Response(JSON.stringify({ data: [{ id: 'late-model' }] })));
  await settle(() => events.some(event => event.type === 'done'));
  assert.ok(!events.some(event => event.type === 'models'));
  assert.equal(events.at(-1).data.cancelled, true);
  host.close();
});
test('unsupported, authentication and malformed replies stay separate', async () => {
  for (const [response, expected] of [[new Response('', { status: 404 }), 'modelsUnsupported'], [new Response('secret server content', { status: 401 }), 'authenticationFailed'], [new Response('{"data":[{"id":"bad\\nname"}]}'), 'invalidModelList']]) {
    const events = [];
    const host = new AgentHost(event => events.push(event), undefined, () => ({ fetch: async () => response, close: async () => {} }));
    host.receive(frame());
    await settle(() => events.some(event => event.type === 'done'));
    assert.equal(events.find(event => event.type === 'error').data.code, expected);
    assert.ok(!JSON.stringify(events).includes('secret server content'));
    host.close();
  }
});

test('discovery deadline aborts a response and cannot report models afterward', async t => {
  t.mock.timers.enable({ apis: ['setTimeout'] });
  const events = [];
  let release;
  let signal;
  const host = new AgentHost(event => events.push(event), undefined, () => ({ fetch: (url, init) => { signal = init.signal; return new Promise(resolve => { release = resolve; }); }, close: async () => {} }));
  host.receive(frame());
  t.mock.timers.tick(5000);
  assert.equal(signal.aborted, true);
  release(new Response(JSON.stringify({ data: [{ id: 'late-model' }] })));
  for (let i = 0; i < 20; i++) await Promise.resolve();
  assert.equal(events.find(event => event.type === 'error').data.code, 'requestTimeout');
  assert.ok(!events.some(event => event.type === 'models'));
  host.close();
});
