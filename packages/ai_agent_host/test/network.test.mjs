import test from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { AgentHost } from '../src/host.mjs';
import { requestTransport, resolveSettings } from '../src/providers.mjs';
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
