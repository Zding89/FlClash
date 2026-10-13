import vm from 'node:vm';

const inputLimit = 10 * 1024 * 1024;
const outputLimit = 8 * 1024 * 1024;
let size = 0;
const chunks = [];
try {
  for await (const chunk of process.stdin) {
    size += chunk.length;
    if (size > inputLimit) throw new Error('script_input_limit');
    chunks.push(chunk);
  }
  const request = JSON.parse(Buffer.concat(chunks).toString('utf8'));
  if (request === null || typeof request !== 'object' || Array.isArray(request) ||
      Object.keys(request).some((key) => !['script', 'config', 'timeoutMillis'].includes(key)) ||
      typeof request.script !== 'string' || Buffer.byteLength(request.script, 'utf8') > 512 * 1024 ||
      request.config === null || typeof request.config !== 'object' || Array.isArray(request.config) ||
      !Number.isInteger(request.timeoutMillis) || request.timeoutMillis < 1 || request.timeoutMillis > 2000) {
    throw new Error('script_input_limit');
  }
  const context = vm.createContext(Object.create(null), {
    codeGeneration: { strings: false, wasm: false },
    microtaskMode: 'afterEvaluate',
  });
  const source = `
    Object.defineProperties(globalThis, {
      ArrayBuffer: {value: undefined, writable: false, configurable: false},
      SharedArrayBuffer: {value: undefined, writable: false, configurable: false},
      WebAssembly: {value: undefined, writable: false, configurable: false},
      Uint8Array: {value: undefined, writable: false, configurable: false},
      Uint8ClampedArray: {value: undefined, writable: false, configurable: false},
      Uint16Array: {value: undefined, writable: false, configurable: false},
      Uint32Array: {value: undefined, writable: false, configurable: false},
      Int8Array: {value: undefined, writable: false, configurable: false},
      Int16Array: {value: undefined, writable: false, configurable: false},
      Int32Array: {value: undefined, writable: false, configurable: false},
      Float32Array: {value: undefined, writable: false, configurable: false},
      Float64Array: {value: undefined, writable: false, configurable: false},
      BigInt64Array: {value: undefined, writable: false, configurable: false},
      BigUint64Array: {value: undefined, writable: false, configurable: false},
      DataView: {value: undefined, writable: false, configurable: false},
      Promise: {value: undefined, writable: false, configurable: false},
      WeakRef: {value: undefined, writable: false, configurable: false},
      FinalizationRegistry: {value: undefined, writable: false, configurable: false},
      console: {value: undefined, writable: false, configurable: false}
    });
    (function () {
      ${request.script}
      const result = main(${JSON.stringify(request.config)});
      if (result === null || typeof result !== 'object' || Array.isArray(result) || typeof result.then === 'function') throw new Error('script_result_not_object');
      return JSON.stringify(result);
    })()
  `;
  const script = new vm.Script(source, { filename: 'profile-overwrite.js' });
  const result = script.runInContext(context, { timeout: request.timeoutMillis, breakOnSigint: true });
  if (typeof result !== 'string' || Buffer.byteLength(result, 'utf8') > outputLimit) throw new Error('script_output_limit');
  const value = JSON.parse(result);
  if (value === null || typeof value !== 'object' || Array.isArray(value)) throw new Error('script_result_not_object');
  process.stdout.write(JSON.stringify({ value }));
} catch (error) {
  const code = error?.code === 'ERR_SCRIPT_EXECUTION_TIMEOUT' ? 'script_timeout'
    : ['script_input_limit', 'script_output_limit', 'script_result_not_object'].includes(error?.message) ? error.message
    : 'script_evaluation_failed';
  process.stdout.write(JSON.stringify({ code }));
  process.exitCode = 1;
}
