import test from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { AgentHost } from '../src/host.mjs';
import { requestTransport, resolveSettings, modelListRequest, fetchModels } from '../src/providers.mjs';
const listen = server => new Promise((resolve, reject) => { server.once('error', reject); server.listen(40291, '127.0.0.1', resolve); });
const close = server => new Promise(resolve => { server.closeAllConnections(); server.close(resolve); });
const waitFor = async predicate => { for (let i = 0; i < 3000; i++) { if (predicate()) return; await new Promise(r => setTimeout(r, 1)); } throw new Error('test timeout'); };
test('real Pi OpenAI-compatible adapter streams and executes a correlated tool', async () => {
  const requests = [];
  const server = createServer(async (req, res) => {
    let body = ''; for await (const chunk of req) body += chunk;
    requests.push({ headers: req.headers, body: JSON.parse(body) });
    const first = requests.length === 1;
    res.writeHead(200, { 'content-type': 'text/event-stream' });
    const content = first ? { role: 'assistant', tool_calls: [{ index: 0, id: 'call-1', type: 'function', function: { name: 'read_config', arguments: '{}' } }] } : { role: 'assistant', content: 'actual-sdk-ok' };
    res.write('data: ' + JSON.stringify({ id: 'mock', object: 'chat.completion.chunk', created: 1, model: 'test', choices: [{ index: 0, delta: content, finish_reason: null }] }) + '\n\n');
    res.write('data: ' + JSON.stringify({ id: 'mock', choices: [{ index: 0, delta: {}, finish_reason: first ? 'tool_calls' : 'stop' }] }) + '\n\n');
    res.end('data: [DONE]\n\n');
  });
  await listen(server);
  let host;
  const events = [];
  host = new AgentHost(event => {
    events.push(event);
    if (event.type === 'toolRequest') queueMicrotask(() => host.receive({ version: 1, sessionId: 'network', generation: 1, requestId: event.data.requestId, type: 'toolResult', data: { toolCallId: event.data.toolCallId, isError: false, value: { version: 7 } } }));
  });
  try {
    host.receive({ version: 1, sessionId: 'network', generation: 1, requestId: 'prompt', type: 'prompt', data: { settings: { provider: 'custom', model: 'test', baseUrl: 'http://127.0.0.1:40291/v1', timeoutSeconds: 5 }, key: 'test-secret', user: 'inspect config', messages: [], tools: [{ name: 'read_config', description: 'Read config', parameters: { type: 'object', properties: {}, additionalProperties: false } }] } });
    await waitFor(() => events.some(e => e.type === 'done'));
    assert.ok(!events.some(e => e.type === 'error'), JSON.stringify(events));
    assert.equal(events.find(e => e.type === 'text').data.text, 'actual-sdk-ok');
    assert.equal(requests.length, 2);
    assert.ok(requests.every(req => req.headers.authorization === 'Bearer test-secret'));
    assert.ok(requests.every(req => !JSON.stringify(req.body).includes('test-secret')));
    assert.ok(requests[1].body.messages.some(message => message.role === 'tool' && message.content.includes('7')));
  } finally { host.close(); await close(server); }
});
test('request scoped proxy routes through loopback and validates its boundary', async () => {
  let target;
  const server = createServer((req, res) => { target = req.url; res.end('proxy-ok'); });
  await listen(server);
  const network = requestTransport('http://127.0.0.1:40291');
  try {
    const response = await network.fetch('http://127.0.0.1:40292/test', { signal: AbortSignal.timeout(2000) });
    assert.equal(await response.text(), 'proxy-ok');
    assert.equal(target, 'http://127.0.0.1:40292/test');
    assert.throws(() => resolveSettings({ provider: 'deepseek', model: 'test', proxyUrl: 'http://remote.example:1234' }));
    assert.throws(() => resolveSettings({ provider: 'deepseek', model: 'test', proxyUrl: 'http://secret@127.0.0.1:1234' }));
  } finally { await network.close(); await close(server); }
});

test('model discovery refuses redirects before sending credentials to a new path', async () => {
  const requests = [];
  const server = createServer((req, res) => {
    requests.push(req.url);
    if (req.url === '/v1/models') { res.writeHead(302, { location: '/credential-target' }); res.end(); }
    else res.end(JSON.stringify({ data: [{ id: 'unexpected' }] }));
  });
  await listen(server);
  const network = requestTransport();
  try {
    const request = modelListRequest({ provider: 'custom', baseUrl: 'http://127.0.0.1:40291/v1' }, 'test-secret');
    await assert.rejects(fetchModels(request, network, AbortSignal.timeout(2000)));
    assert.deepEqual(requests, ['/v1/models']);
  } finally { await network.close(); await close(server); }
});

test('DeepSeek keeps three text-history turns and a tool call in non-thinking mode', async () => {
  const requests = [];
  const server = createServer(async (req, res) => {
    let body = ''; for await (const chunk of req) body += chunk;
    const payload = JSON.parse(body);
    requests.push(payload);
    const assistant = payload.messages.filter(m => m.role === 'assistant');
    if (payload.thinking?.type !== 'disabled' && assistant.some(m => typeof m.reasoning_content !== 'string')) {
      res.writeHead(400, { 'content-type': 'application/json' });
      res.end(JSON.stringify({ error: { message: 'reasoning_content must be passed back in thinking mode', type: 'invalid_request_error' } }));
      return;
    }
    const users = payload.messages.filter(m => m.role === 'user');
    const lastUserIndex = payload.messages.findLastIndex(m => m.role === 'user');
    const tool = users.length === 2 && !payload.messages.slice(lastUserIndex + 1).some(m => m.role === 'tool');
    const delta = tool
      ? { role: 'assistant', tool_calls: [{ index: 0, id: 'usage-call', type: 'function', function: { name: 'read_usage', arguments: '{}' } }] }
      : { role: 'assistant', content: 'answer-' + users.length };
    if (payload.thinking?.type !== 'disabled') delta.reasoning_content = 'synthetic-reasoning';
    res.writeHead(200, { 'content-type': 'text/event-stream' });
    res.write('data: ' + JSON.stringify({ id: 'mock', choices: [{ index: 0, delta, finish_reason: null }] }) + '\n\n');
    res.write('data: ' + JSON.stringify({ id: 'mock', choices: [{ index: 0, delta: {}, finish_reason: tool ? 'tool_calls' : 'stop' }] }) + '\n\n');
    res.end('data: [DONE]\n\n');
  });
  await listen(server);
  const events = [];
  const history = [];
  let host;
  host = new AgentHost(event => {
    events.push(event);
    if (event.type === 'toolRequest') queueMicrotask(() => host.receive({ ...event, requestId: event.data.requestId, type: 'toolResult', data: { toolCallId: event.data.toolCallId, isError: false, value: { bytes: 7 } } }));
  }, undefined, () => ({ fetch: (_url, init) => fetch('http://127.0.0.1:40291/v1/chat/completions', init), close: async () => {} }));
  try {
    for (let generation = 1; generation <= 3; generation++) {
      const user = 'question-' + generation;
      host.receive({ version: 1, sessionId: 'deepseek-turns', generation, requestId: 'prompt-' + generation, type: 'prompt', data: { settings: { provider: 'deepseek', model: 'deepseek-flash', timeoutSeconds: 5 }, key: 'synthetic-key', user, messages: [...history], tools: [{ name: 'read_usage', description: 'Read fixture usage', parameters: { type: 'object', properties: {}, additionalProperties: false } }] } });
      await waitFor(() => events.some(e => e.generation === generation && e.type === 'done'));
      const turn = events.filter(e => e.generation === generation);
      assert.ok(!turn.some(e => e.type === 'error'), JSON.stringify(turn));
      assert.ok(turn.some(e => e.type === 'text' && e.data.text === 'answer-' + generation));
      history.push({ role: 'user', content: user }, { role: 'assistant', content: 'answer-' + generation });
    }
    assert.equal(requests.length, 4);
    assert.ok(requests.every(r => r.thinking?.type === 'disabled'));
    assert.equal(events.filter(e => e.type === 'toolRequest').length, 1);
    assert.deepEqual(requests.at(-1).messages.filter(m => m.role === 'assistant').map(m => m.content), ['answer-1', 'answer-2']);
    assert.ok(!JSON.stringify(events).includes('synthetic-key'));
  } finally { host.close(); await close(server); }
});
