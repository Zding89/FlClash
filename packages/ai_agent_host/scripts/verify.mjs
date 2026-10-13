import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { spawn } from 'node:child_process';
import { createInterface } from 'node:readline';
import path from 'node:path';
const resourceArg = process.argv[process.argv.indexOf('--resources') + 1];
if (!process.argv.includes('--resources') || !resourceArg) throw new Error('Use --resources /absolute/Resources');
const directory = path.join(path.resolve(resourceArg), 'ai');
const requests = [];
const events = [];
const server = createServer(async (req, res) => {
  let raw = ''; for await (const chunk of req) raw += chunk;
  requests.push({ headers: req.headers, body: JSON.parse(raw) });
  const first = requests.length === 1;
  res.writeHead(200, { 'content-type': 'text/event-stream' });
  const delta = first ? { role: 'assistant', tool_calls: [{ index: 0, id: 'call-1', type: 'function', function: { name: 'read_config', arguments: '{}' } }] } : { role: 'assistant', content: 'packaged-sdk-ok' };
  res.write('data: ' + JSON.stringify({ id: 'mock', object: 'chat.completion.chunk', model: 'test', created: 1, choices: [{ index: 0, delta, finish_reason: null }] }) + '\n\n');
  res.write('data: ' + JSON.stringify({ id: 'mock', choices: [{ index: 0, delta: {}, finish_reason: first ? 'tool_calls' : 'stop' }] }) + '\n\n');
  res.end('data: [DONE]\n\n');
});
await new Promise((resolve, reject) => { server.once('error', reject); server.listen(40291, '127.0.0.1', resolve); });
const child = spawn(path.join(directory, 'node'), [path.join(directory, 'host.mjs')], { stdio: ['pipe', 'pipe', 'pipe'], env: {} });
let diagnostics = '';
child.stderr.on('data', chunk => { diagnostics += chunk; });
const lines = createInterface({ input: child.stdout });
let timeout;
try {
  const done = new Promise((resolve, reject) => {
    child.once('error', reject);
    child.once('exit', code => reject(new Error(`Host exited ${code}`)));
    timeout = setTimeout(() => reject(new Error('Packaged host timeout')), 10000);
    lines.on('line', line => {
      const event = JSON.parse(line); events.push(event);
      if (event.type === 'toolRequest') child.stdin.write(JSON.stringify({ ...event, requestId: event.data.requestId, type: 'toolResult', data: { toolCallId: event.data.toolCallId, isError: false, value: { safe: true } } }) + '\n');
      if (event.type === 'done') resolve();
    });
  });
  child.stdin.write(JSON.stringify({ version: 1, sessionId: 'packaged', generation: 1, requestId: 'prompt', type: 'prompt', data: { settings: { provider: 'custom', model: 'test', baseUrl: 'http://127.0.0.1:40291/v1', timeoutSeconds: 5 }, key: 'test-secret', user: 'inspect config', tools: [{ name: 'read_config', description: 'Read config', parameters: { type: 'object', properties: {}, additionalProperties: false } }] } }) + '\n');
  await done;
  assert.ok(!events.some(e => e.type === 'error'), JSON.stringify(events));
  assert.equal(events.find(e => e.type === 'text').data.text, 'packaged-sdk-ok');
  assert.equal(requests.length, 2);
  assert.ok(requests.every(req => req.headers.authorization === 'Bearer test-secret' && !JSON.stringify(req.body).includes('test-secret')));
  assert.ok(!diagnostics.includes('test-secret'));
  process.stdout.write('Packaged Pi host streaming/tool protocol verified\n');
} finally {
  clearTimeout(timeout); lines.close(); child.stdin.end();
  child.kill('SIGTERM');
  await new Promise(resolve => { if (child.exitCode !== null) resolve(); else child.once('exit', resolve); });
  server.closeAllConnections(); await new Promise(resolve => server.close(resolve));
}
