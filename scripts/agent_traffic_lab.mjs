import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import dgram from 'node:dgram';
import fs from 'node:fs';
import http from 'node:http';
import net from 'node:net';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { promisify } from 'node:util';

const tags = {
  'mz-us-tcp': { airport: 'mz', port: 'http' },
  'mz-us-udp': { airport: 'mz', port: 'mz' },
  'mz-hk': { airport: 'mz', port: 'mz' },
  'other-us-01': { airport: 'other', port: 'other' },
  'other-us-05': { airport: 'other', port: 'other' },
  'other-hk': { airport: 'other', port: 'other' },
};

class SocketReader {
  constructor(socket) {
    this.socket = socket;
    this.buffer = Buffer.alloc(0);
    this.waiter = null;
    this.closed = false;
    this.onData = (chunk) => {
      this.buffer = Buffer.concat([this.buffer, chunk]);
      this.waiter?.();
    };
    this.onClose = () => { this.closed = true; this.waiter?.(); };
    socket.on('data', this.onData);
    socket.on('close', this.onClose);
    socket.on('end', this.onClose);
  }
  async read(count) {
    while (this.buffer.length < count) {
      if (this.closed) throw new Error('connection closed');
      await new Promise((resolve) => { this.waiter = resolve; });
      this.waiter = null;
    }
    const result = this.buffer.subarray(0, count);
    this.buffer = this.buffer.subarray(count);
    return result;
  }
  async header() {
    for (;;) {
      const index = this.buffer.indexOf('\r\n\r\n');
      if (index >= 0) return this.read(index + 4);
      if (this.buffer.length > 65536 || this.closed) throw new Error('invalid header');
      await new Promise((resolve) => { this.waiter = resolve; });
      this.waiter = null;
    }
  }
  release() {
    this.socket.pause();
    this.socket.off('data', this.onData);
    this.socket.off('close', this.onClose);
    this.socket.off('end', this.onClose);
    if (this.buffer.length) this.socket.unshift(this.buffer);
    this.buffer = Buffer.alloc(0);
  }
}

function encodeAddress(host, port) {
  let address;
  if (net.isIP(host) === 4) {
    address = Buffer.from([1, ...host.split('.').map(Number)]);
  } else if (net.isIP(host) === 6) {
    let normalized = host;
    if (normalized.includes('.')) {
      const boundary = normalized.lastIndexOf(':');
      const octets = normalized.slice(boundary + 1).split('.').map(Number);
      normalized = `${normalized.slice(0, boundary + 1)}${((octets[0] << 8) | octets[1]).toString(16)}:${((octets[2] << 8) | octets[3]).toString(16)}`;
    }
    const halves = normalized.split('::');
    const left = halves[0] ? halves[0].split(':') : [];
    const right = halves[1] ? halves[1].split(':') : [];
    const groups = halves.length === 1 ? left : [...left, ...Array(8 - left.length - right.length).fill('0'), ...right];
    address = Buffer.alloc(17);
    address[0] = 4;
    groups.forEach((group, index) => address.writeUInt16BE(Number.parseInt(group, 16), 1 + index * 2));
  } else {
    const name = Buffer.from(host);
    if (name.length > 255) throw new Error('host too long');
    address = Buffer.concat([Buffer.from([3, name.length]), name]);
  }
  const suffix = Buffer.alloc(2);
  suffix.writeUInt16BE(port);
  return Buffer.concat([address, suffix]);
}

function decodeAddress(data, offset) {
  const type = data[offset++];
  let host;
  if (type === 1) {
    if (data.length < offset + 6) throw new Error('short IPv4 address');
    host = [...data.subarray(offset, offset + 4)].join('.');
    offset += 4;
  } else if (type === 3) {
    const length = data[offset++];
    if (!length || data.length < offset + length + 2) throw new Error('short host');
    host = data.subarray(offset, offset + length).toString();
    offset += length;
  } else if (type === 4) {
    if (data.length < offset + 18) throw new Error('short IPv6 address');
    host = Array.from({ length: 8 }, (_, i) => data.readUInt16BE(offset + 2 * i).toString(16)).join(':');
    offset += 16;
  } else throw new Error('unsupported address');
  return { host, port: data.readUInt16BE(offset), next: offset + 2 };
}

async function readAddress(reader) {
  const type = await reader.read(1);
  let rest;
  if (type[0] === 3) {
    const length = await reader.read(1);
    rest = Buffer.concat([length, await reader.read(length[0] + 2)]);
  } else if (type[0] === 1 || type[0] === 4) rest = await reader.read(type[0] === 1 ? 6 : 18);
  else throw new Error('unsupported address');
  return decodeAddress(Buffer.concat([type, rest]), 0);
}

async function bind(server, port) {
  await new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(port, '127.0.0.1', resolve);
  });
  return server.address().port;
}

function json(response, status, data) {
  const body = JSON.stringify(data);
  response.writeHead(status, { 'content-type': 'application/json', 'content-length': Buffer.byteLength(body), connection: 'close' });
  response.end(body);
}

async function startLab(ports, logFile) {
  fs.mkdirSync(path.dirname(logFile), { recursive: true });
  if (fs.lstatSync(path.dirname(logFile)).isSymbolicLink() || fs.existsSync(logFile) && fs.lstatSync(logFile).isSymbolicLink()) throw new Error('unsafe log path');
  const enabled = { mz: true, other: true };
  const nodeEnabled = Object.fromEntries(Object.keys(tags).map((tag) => [tag, true]));
  const isEnabled = (tag) => enabled[tags[tag].airport] && nodeEnabled[tag];
  const sockets = new Set();
  const relays = new Set();
  const servers = [];
  const upstreams = new Map();
  const record = (event) => fs.appendFileSync(logFile, `${JSON.stringify({ at: new Date().toLocaleString('sv-SE', { timeZone: 'Asia/Shanghai' }), synthetic: true, ...event })}\n`);
  const track = (socket) => {
    sockets.add(socket);
    socket.on('error', () => {});
    socket.once('close', () => sockets.delete(socket));
    socket.setTimeout(15000, () => socket.destroy());
    return socket;
  };
  const validTag = (tag, kind) => tags[tag]?.port === kind;
  const target = http.createServer(async (request, response) => {
    const url = new URL(request.url, 'http://127.0.0.1');
    if (url.pathname === '/control') {
      const airport = url.searchParams.get('airport');
      const node = url.searchParams.get('node');
      const value = url.searchParams.get('enabled');
      if (node !== null) {
        if (!Object.hasOwn(tags, node) || !['true', 'false'].includes(value)) return json(response, 400, { error: 'invalid node control' });
        nodeEnabled[node] = value === 'true';
        record({ kind: 'control', node, enabled: nodeEnabled[node] });
        return json(response, 200, { enabled, nodeEnabled });
      }
      const key = ['mz', '71001', '迷之屋'].includes(airport) ? 'mz' : ['other', '71002', '其他机场'].includes(airport) ? 'other' : null;
      if (!key || !['true', 'false'].includes(value)) return json(response, 400, { error: 'invalid control' });
      enabled[key] = value === 'true';
      record({ kind: 'control', airport: key, enabled: enabled[key] });
      return json(response, 200, { enabled });
    }
    const identity = upstreams.get(request.socket.remotePort) ?? { exitlabel: request.headers['x-lab-exit'] ?? 'direct-loopback', requestedhost: request.headers['x-lab-host'] ?? request.headers.host, port: Number(request.headers['x-lab-port'] ?? target.address().port) };
    let payload = Buffer.alloc(0);
    for await (const chunk of request) {
      payload = Buffer.concat([payload, chunk]);
      if (payload.length > 65536) return json(response, 413, { error: 'payload too large' });
    }
    record({ kind: 'http', ...identity, method: request.method, path: request.url, payload: payload.toString().slice(0, 4096) || request.url });
    if (url.pathname === '/health') { response.writeHead(204); response.end(); return; }
    const holdMs = Number(url.searchParams.get('holdMs') ?? 0);
    if (Number.isSafeInteger(holdMs) && holdMs > 0 && holdMs <= 6000) await new Promise(resolve => setTimeout(resolve, holdMs));
    json(response, 200, { synthetic: true, ...identity, path: request.url, payload: payload.toString() });
  });
  target.on('connection', track);
  servers.push(target);
  const targetPort = await bind(target, ports.target);
  const connectTarget = async (socket, identity) => {
    if (identity.port !== targetPort) throw new Error('only local target port is allowed');
    const upstream = track(net.connect(targetPort, '127.0.0.1'));
    await new Promise((resolve, reject) => { upstream.once('connect', resolve); upstream.once('error', reject); });
    const key = upstream.localPort;
    upstreams.set(key, identity);
    upstream.once('close', () => { upstreams.delete(key); socket.destroy(); });
    socket.once('close', () => upstream.destroy());
    record({ kind: 'connect', ...identity });
    return upstream;
  };
  const httpProxy = http.createServer((request, response) => {
    const tag = parseBasic(request.headers['proxy-authorization']);
    if (!validTag(tag, 'http')) return json(response, 407, { error: 'synthetic fixture authentication required' });
    let destination;
    try { destination = new URL(request.url); } catch { return json(response, 400, { error: 'absolute URL required' }); }
    const port = Number(destination.port || 80);
    if (destination.protocol !== 'http:' || port !== targetPort) return json(response, 403, { error: 'only local HTTP target is allowed' });
    if (!isEnabled(tag)) {
      record({ kind: 'blocked', exitlabel: tag, requestedhost: destination.hostname, port, payload: request.url });
      return json(response, 503, { error: 'airport paused' });
    }
    const headers = { ...request.headers, host: destination.host, 'x-lab-exit': tag, 'x-lab-host': destination.hostname, 'x-lab-port': String(port), connection: 'close' };
    delete headers['proxy-authorization'];
    const upstream = http.request({ hostname: '127.0.0.1', port: targetPort, path: `${destination.pathname}${destination.search}`, method: request.method, headers, agent: false }, (reply) => { response.writeHead(reply.statusCode, reply.headers); reply.pipe(response); });
    upstream.on('error', () => { if (!response.headersSent) json(response, 502, { error: 'local target unavailable' }); else response.destroy(); });
    request.on('aborted', () => upstream.destroy());
    request.pipe(upstream);
  });
  httpProxy.on('connection', track);
  httpProxy.on('connect', async (request, socket, head) => {
    try {
      const tag = parseBasic(request.headers['proxy-authorization']);
      if (!validTag(tag, 'http')) { socket.end('HTTP/1.1 407 Unauthorized\r\nConnection: close\r\n\r\n'); return; }
      const destination = new URL(`http://${request.url}`);
      if (!isEnabled(tag)) {
        record({ kind: 'blocked', exitlabel: tag, requestedhost: destination.hostname, port: Number(destination.port || 80), payload: '' });
        socket.end('HTTP/1.1 503 Unavailable\r\nConnection: close\r\n\r\n');
        return;
      }
      const upstream = await connectTarget(socket, { exitlabel: tag, requestedhost: destination.hostname, port: Number(destination.port || 80) });
      socket.write('HTTP/1.1 200 Connection Established\r\n\r\n');
      if (head.length) upstream.write(head);
      socket.pipe(upstream).pipe(socket);
    } catch { socket.end('HTTP/1.1 502 Bad Gateway\r\nConnection: close\r\n\r\n'); }
  });
  servers.push(httpProxy);
  const httpPort = await bind(httpProxy, ports.http);
  const socksPorts = {};
  for (const kind of ['mz', 'other']) {
    const server = net.createServer(async (socket) => {
      track(socket);
      const reader = new SocketReader(socket);
      try {
        const hello = await reader.read(2);
        const methods = await reader.read(hello[1]);
        if (hello[0] !== 5 || !methods.includes(2)) { socket.end(Buffer.from([5, 255])); return; }
        socket.write(Buffer.from([5, 2]));
        const auth = await reader.read(2);
        const tag = (await reader.read(auth[1])).toString();
        const length = await reader.read(1);
        const password = (await reader.read(length[0])).toString();
        if (auth[0] !== 1 || !validTag(tag, kind) || password !== 'acceptance-only') { socket.end(Buffer.from([1, 1])); return; }
        socket.write(Buffer.from([1, 0]));
        const header = await reader.read(3);
        const destination = await readAddress(reader);
        if (header[0] !== 5 || header[2] !== 0) { socket.destroy(); return; }
        if (!isEnabled(tag)) {
          record({ kind: 'blocked', exitlabel: tag, requestedhost: destination.host, port: destination.port, payload: '' });
          socket.end(Buffer.from([5, 2, 0, 1, 127, 0, 0, 1, 0, 0]));
          return;
        }
        if (header[1] === 1) {
          const upstream = await connectTarget(socket, { exitlabel: tag, requestedhost: destination.host, port: destination.port });
          socket.write(Buffer.from([5, 0, 0, 1, 127, 0, 0, 1, 0, 0]));
          reader.release();
          socket.pipe(upstream).pipe(socket);
        } else if (header[1] === 3) {
          socket.setTimeout(0);
          const relay = dgram.createSocket('udp4');
          relays.add(relay);
          relay.on('error', () => {});
          await new Promise((resolve) => relay.bind(0, '127.0.0.1', resolve));
          socket.once('close', () => { relays.delete(relay); try { relay.close(); } catch {} });
          const reply = Buffer.from([5, 0, 0, 1, 127, 0, 0, 1, 0, 0]);
          reply.writeUInt16BE(relay.address().port, 8);
          socket.write(reply);
          relay.on('message', (data, remote) => {
            try {
              if (remote.address !== '127.0.0.1' || data[0] !== 0 || data[1] !== 0 || data[2] !== 0) return;
              const targetAddress = decodeAddress(data, 3);
              const payload = data.subarray(targetAddress.next);
              if (!isEnabled(tag)) {
                record({ kind: 'blocked', exitlabel: tag, requestedhost: targetAddress.host, port: targetAddress.port, payload: payload.toString().slice(0, 4096) });
                return;
              }
              record({ kind: 'udp', exitlabel: tag, requestedhost: targetAddress.host, port: targetAddress.port, payload: payload.toString().slice(0, 4096) });
              const body = Buffer.concat([Buffer.from(`${tag}:`), payload]);
              relay.send(Buffer.concat([Buffer.from([0, 0, 0]), encodeAddress(targetAddress.host, targetAddress.port), body]), remote.port, remote.address);
            } catch {}
          });
        } else socket.end(Buffer.from([5, 7, 0, 1, 127, 0, 0, 1, 0, 0]));
      } catch { socket.destroy(); }
    });
    servers.push(server);
    socksPorts[kind] = await bind(server, ports[kind]);
  }
  return {
    ports: { target: targetPort, http: httpPort, ...socksPorts },
    async close() {
      for (const socket of sockets) socket.destroy();
      for (const relay of relays) { try { relay.close(); } catch {} }
      await Promise.all(servers.map((server) => new Promise((resolve) => server.close(resolve))));
    },
  };
}

function parseBasic(header) {
  if (!header?.startsWith('Basic ')) return null;
  const [tag, password] = Buffer.from(header.slice(6), 'base64').toString().split(':');
  return password === 'acceptance-only' ? tag : null;
}

async function requestHTTP(port, url, tag) {
  return new Promise((resolve, reject) => {
    const request = http.get({ host: '127.0.0.1', port, path: url, headers: tag ? { 'proxy-authorization': `Basic ${Buffer.from(`${tag}:acceptance-only`).toString('base64')}` } : {} }, (response) => {
      const parts = [];
      response.on('data', (data) => parts.push(data));
      response.on('end', () => resolve({ status: response.statusCode, body: Buffer.concat(parts).toString() }));
    });
    request.on('error', reject);
    request.setTimeout(3000, () => request.destroy(new Error('HTTP timeout')));
  });
}

async function socksClient(port, tag, command, destinationPort) {
  const socket = net.connect(port, '127.0.0.1');
  socket.on('error', () => {});
  socket.setTimeout(3000, () => socket.destroy());
  const reader = new SocketReader(socket);
  socket.write(Buffer.from([5, 1, 2]));
  assert.deepEqual(await reader.read(2), Buffer.from([5, 2]));
  const username = Buffer.from(tag);
  const password = Buffer.from('acceptance-only');
  socket.write(Buffer.concat([Buffer.from([1, username.length]), username, Buffer.from([password.length]), password]));
  assert.deepEqual(await reader.read(2), Buffer.from([1, 0]));
  socket.write(Buffer.concat([Buffer.from([5, command, 0]), encodeAddress('api.openai.com', destinationPort)]));
  const reply = await reader.read(3);
  const address = await readAddress(reader);
  return { socket, reader, status: reply[1], address };
}

async function selfTest() {
  assert.equal(encodeAddress('198.51.100.20', 1234)[0], 1);
  assert.equal(encodeAddress('2001:db8::42', 1234)[0], 4);
  assert.equal(decodeAddress(encodeAddress('2001:db8::42', 1234), 0).host, '2001:db8:0:0:0:0:0:42');
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'flclash-traffic-lab-'));
  let lab;
  try {
    lab = await startLab({ target: 0, http: 0, mz: 0, other: 0 }, path.join(temporary, 'traffic.jsonl'));
    const targetURL = `http://api.openai.com:${lab.ports.target}/marker?nonce=selftest-http`;
    const forwarded = await requestHTTP(lab.ports.http, targetURL, 'mz-us-tcp');
    assert.equal(JSON.parse(forwarded.body).exitlabel, 'mz-us-tcp');
    assert.equal((await requestHTTP(lab.ports.http, `http://health.fixture:${lab.ports.target}/health`, 'mz-us-tcp')).status, 204);
    const connect = net.connect(lab.ports.http, '127.0.0.1');
    connect.setTimeout(3000, () => connect.destroy());
    connect.on('error', () => {});
    const connectReader = new SocketReader(connect);
    connect.write(`CONNECT api.openai.com:${lab.ports.target} HTTP/1.1\r\nHost: api.openai.com\r\nProxy-Authorization: Basic ${Buffer.from('mz-us-tcp:acceptance-only').toString('base64')}\r\n\r\n`);
    assert.match((await connectReader.header()).toString(), /200 Connection Established/);
    connect.write('GET /marker?nonce=selftest-connect HTTP/1.1\r\nHost: api.openai.com\r\nConnection: close\r\n\r\n');
    await connectReader.header();
    while (!connectReader.closed) await new Promise((resolve) => { connectReader.waiter = resolve; });
    assert.equal(JSON.parse(connectReader.buffer.toString()).exitlabel, 'mz-us-tcp');
    connect.destroy();
    for (const tag of ['mz-us-udp', 'mz-hk', 'other-us-01', 'other-us-05', 'other-hk']) {
      const kind = tags[tag].airport;
      const tcp = await socksClient(lab.ports[kind], tag, 1, lab.ports.target);
      assert.equal(tcp.status, 0);
      tcp.socket.write('GET /marker?nonce=selftest-socks HTTP/1.1\r\nHost: api.openai.com\r\nConnection: close\r\n\r\n');
      await tcp.reader.header();
      while (!tcp.reader.closed) await new Promise((resolve) => { tcp.reader.waiter = resolve; });
      assert.equal(JSON.parse(tcp.reader.buffer.toString()).exitlabel, tag);
      tcp.socket.destroy();
      const association = await socksClient(lab.ports[kind], tag, 3, lab.ports.target);
      assert.equal(association.status, 0);
      const udp = dgram.createSocket('udp4');
      try {
        const received = new Promise((resolve, reject) => {
          const timeout = setTimeout(() => reject(new Error('UDP timeout')), 3000);
          udp.once('message', (data) => { clearTimeout(timeout); resolve(data); });
          udp.once('error', reject);
        });
        udp.send(Buffer.concat([Buffer.from([0, 0, 0]), encodeAddress('api.openai.com', lab.ports.target), Buffer.from('selftest-udp')]), association.address.port, '127.0.0.1');
        const data = await received;
        assert.equal(data.subarray(decodeAddress(data, 3).next).toString(), `${tag}:selftest-udp`);
      } finally { udp.close(); association.socket.destroy(); }
    }
    assert.equal((await requestHTTP(lab.ports.target, '/control?airport=mz&enabled=false')).status, 200);
    assert.equal((await requestHTTP(lab.ports.http, targetURL, 'mz-us-tcp')).status, 503);
    const denied = await socksClient(lab.ports.mz, 'mz-us-udp', 1, lab.ports.target);
    assert.equal(denied.status, 2);
    denied.socket.destroy();
    await requestHTTP(lab.ports.target, '/control?airport=mz&enabled=true');
    assert.equal((await requestHTTP(lab.ports.http, targetURL, 'mz-us-tcp')).status, 200);
    assert.equal((await requestHTTP(lab.ports.target, '/control?node=other-us-01&enabled=false')).status, 200);
    const deniedNode = await socksClient(lab.ports.other, 'other-us-01', 1, lab.ports.target);
    assert.equal(deniedNode.status, 2);
    deniedNode.socket.destroy();
    const allowedNode = await socksClient(lab.ports.other, 'other-us-05', 1, lab.ports.target);
    assert.equal(allowedNode.status, 0);
    allowedNode.socket.destroy();
    await requestHTTP(lab.ports.target, '/control?node=other-us-01&enabled=true');
    const probe = await promisify(execFile)('python3', [path.join(path.dirname(fileURLToPath(import.meta.url)), 'agent_traffic_probe.py'), '--proxy-port', String(lab.ports.other), '--username', 'other-us-05', '--port', String(lab.ports.target), '--nonce', 'selftest-python']);
    assert.equal(JSON.parse(probe.stdout).exitlabel, 'other-us-05');
    const rows = fs.readFileSync(path.join(temporary, 'traffic.jsonl'), 'utf8').trim().split('\n').map(JSON.parse);
    assert.equal(new Set(rows.filter((row) => row.kind === 'http' || row.kind === 'udp').map((row) => row.exitlabel)).size, 6);
    assert.equal(rows.some((row) => JSON.stringify(row).includes('acceptance-only')), false);
    process.stdout.write(`${JSON.stringify({ selftest: 'passed', labels: 6, checks: ['HTTP forwarding', 'CONNECT', 'SOCKS5 TCP', 'SOCKS5 UDP', 'IPv4/IPv6 UDP source types', 'health 204', 'airport pause', 'node pause', 'resume', 'Python UDP probe', 'credential-free log'], network: 'loopback-only' })}\n`);
  } finally {
    await lab?.close();
    fs.rmSync(temporary, { recursive: true, force: true });
  }
}

async function main() {
  if (process.argv.includes('--self-test')) return selfTest();
  if (process.argv.length > 2 && process.argv[2] !== 'serve') throw new Error('usage: node scripts/agent_traffic_lab.mjs serve|--self-test');
  const ephemeral = process.argv.includes('--ephemeral');
  const temporary = ephemeral ? fs.mkdtempSync(path.join(os.tmpdir(), 'flclash-traffic-lab-')) : null;
  const logFile = ephemeral ? path.join(temporary, 'traffic.jsonl') : '/private/tmp/flclash-agent-full-flow/traffic.jsonl';
  const lab = await startLab(ephemeral ? { http: 0, mz: 0, other: 0, target: 0 } : { http: 49387, mz: 49388, other: 49389, target: 49390 }, logFile);
  process.stdout.write(`${JSON.stringify({ ready: true, pid: process.pid, synthetic: true, ports: lab.ports, log: logFile })}\n`);
  const stop = async () => { await lab.close(); if (temporary) fs.rmSync(temporary, { recursive: true, force: true }); process.exit(0); };
  process.once('SIGINT', stop);
  process.once('SIGTERM', stop);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main().catch((error) => { process.stderr.write(`${error.message}\n`); process.exit(1); });
