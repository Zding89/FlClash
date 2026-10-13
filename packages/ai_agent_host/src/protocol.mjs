export const MAX_FRAME_BYTES = 1024 * 1024;
export const MAX_QUEUE_BYTES = 4 * MAX_FRAME_BYTES;
const identifier = /^[A-Za-z0-9_-]{1,96}$/;
export function validId(value) { return typeof value === 'string' && identifier.test(value) && !value.includes('\n'); }
export function envelope(value) {
  if (!value || value.version !== 1 || !validId(value.sessionId) || !validId(value.requestId) || !Number.isSafeInteger(value.generation) || value.generation < 1 || !['prompt', 'cancel', 'toolResult', 'close'].includes(value.type)) throw new Error('invalidEnvelope');
  return value;
}
export class JsonLineReader {
  constructor(onFrame, onError) { this.pending = Buffer.alloc(0); this.onFrame = onFrame; this.onError = onError; this.failed = false; }
  push(chunk) {
    if (this.failed) return;
    this.pending = Buffer.concat([this.pending, Buffer.from(chunk)]);
    while (true) {
      const end = this.pending.indexOf(10);
      if (end < 0) break;
      if (end > MAX_FRAME_BYTES) return this.fail();
      const line = this.pending.subarray(0, end); this.pending = this.pending.subarray(end + 1);
      try { this.onFrame(envelope(JSON.parse(new TextDecoder('utf-8', { fatal: true }).decode(line)))); } catch { return this.fail(); }
    }
    if (this.pending.length > MAX_FRAME_BYTES) this.fail();
  }
  fail() { this.failed = true; this.pending = Buffer.alloc(0); this.onError(new Error('invalidFrame')); }
}
export class JsonLineWriter {
  constructor(stream, onError) { this.stream = stream; this.onError = onError; this.queue = []; this.bytes = 0; this.blocked = false; this.failed = false; stream.on('drain', () => { this.blocked = false; this.flush(); }); stream.on('error', () => this.fail()); }
  send(value) {
    if (this.failed) return;
    const frame = Buffer.from(JSON.stringify(value) + '\n');
    if (frame.length > MAX_FRAME_BYTES || this.bytes + frame.length > MAX_QUEUE_BYTES) return this.fail();
    this.queue.push(frame); this.bytes += frame.length; this.flush();
  }
  flush() { while (!this.blocked && this.queue.length && !this.failed) { const frame = this.queue.shift(); this.bytes -= frame.length; this.blocked = !this.stream.write(frame); } }
  fail() { if (this.failed) return; this.failed = true; this.queue = []; this.bytes = 0; this.onError(new Error('outputOverflow')); }
}
