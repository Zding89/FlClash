import { fetch as proxyFetch, ProxyAgent } from 'undici';
import { streamSimple as completions } from '@earendil-works/pi-ai/api/openai-completions';
import { streamSimple as responses } from '@earendil-works/pi-ai/api/openai-responses';
import { streamSimple as anthropic } from '@earendil-works/pi-ai/api/anthropic-messages';
export const presets = Object.freeze({
  'glm-cn': ['https://open.bigmodel.cn/api/paas/v4', 'openai-completions'],
  'glm-coding-cn': ['https://open.bigmodel.cn/api/coding/paas/v4', 'openai-completions'],
  'glm-global': ['https://api.z.ai/api/paas/v4', 'openai-completions'],
  'glm-coding-global': ['https://api.z.ai/api/coding/paas/v4', 'openai-completions'],
  'kimi-cn': ['https://api.moonshot.cn/v1', 'openai-completions'],
  'kimi-global': ['https://api.moonshot.ai/v1', 'openai-completions'],
  'kimi-coding': ['https://api.kimi.com/coding', 'anthropic-messages'],
  deepseek: ['https://api.deepseek.com', 'openai-completions'],
  openai: ['https://api.openai.com/v1', 'openai-responses'],
  anthropic: ['https://api.anthropic.com', 'anthropic-messages'],
  xai: ['https://api.x.ai/v1', 'openai-completions'],
});
export function resolveSettings(settings, { requireModel = true } = {}) {
  if (!settings || (requireModel && (typeof settings.model !== 'string' || !settings.model.trim() || settings.model.length > 200))) throw new Error('invalidSettings');
  const preset = presets[settings.provider];
  if (!preset && settings.provider !== 'custom') throw new Error('invalidProvider');
  const baseUrl = settings.baseUrl || preset?.[0];
  const api = preset?.[1] || settings.api || 'openai-completions';
  if (!['openai-completions', 'openai-responses', 'anthropic-messages'].includes(api)) throw new Error('invalidApi');
  const url = new URL(baseUrl);
  if (!['https:', 'http:'].includes(url.protocol) || url.username || url.password || url.search || url.hash || (url.protocol === 'http:' && (settings.provider !== 'custom' || !['localhost', '127.0.0.1', '[::1]'].includes(url.hostname)))) throw new Error('invalidEndpoint');
  const timeoutSeconds = settings.timeoutSeconds ?? 90;
  const maxTokens = settings.maxTokens ?? 4096;
  if (!Number.isInteger(timeoutSeconds) || timeoutSeconds < 5 || timeoutSeconds > 300 || !Number.isInteger(maxTokens) || maxTokens < 64 || maxTokens > 32768) throw new Error('invalidLimits');
  let proxyUrl;
  if (settings.proxyUrl != null) {
    const proxy = new URL(settings.proxyUrl);
    if (!['http:', 'https:'].includes(proxy.protocol) || !['localhost', '127.0.0.1', '[::1]'].includes(proxy.hostname) || proxy.username || proxy.password || proxy.search || proxy.hash || proxy.pathname !== '/') throw new Error('invalidProxy');
    proxyUrl = proxy.href;
  }
  const model = { id: settings.model, name: settings.model, provider: settings.provider, api, baseUrl, reasoning: false, input: ['text'], cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 }, contextWindow: 131072, maxTokens };
  return { model, timeoutSeconds, maxTokens, proxyUrl };
}
export function providerStream(model, context, options) {
  return ({ 'openai-completions': completions, 'openai-responses': responses, 'anthropic-messages': anthropic })[model.api](model, context, options);
}

export function requestTransport(proxyUrl) {
  if (!proxyUrl) return { fetch: (url, init) => globalThis.fetch(url, { ...init, redirect: 'error' }), close: async () => {} };
  const agent = new ProxyAgent(proxyUrl);
  return { fetch: (url, init) => proxyFetch(url, { ...init, dispatcher: agent, redirect: 'error' }), close: () => agent.destroy() };
}

export function modelListRequest(settings, key) {
  const resolved = resolveSettings(settings, { requireModel: false });
  if (settings.provider.startsWith('glm-')) throw new Error('modelsUnsupported');
  if (typeof key !== 'string' || !key || key.length > 16384 || /[\r\n]/.test(key)) throw new Error('keyMissing');
  const url = new URL(resolved.model.baseUrl);
  const anthropicApi = resolved.model.api === 'anthropic-messages' && settings.provider !== 'kimi-coding';
  const path = url.pathname.replace(/\/$/, '');
  url.pathname = path + (anthropicApi || settings.provider === 'kimi-coding' ? (path.endsWith('/v1') ? '/models' : '/v1/models') : '/models');
  const headers = anthropicApi
    ? { 'x-api-key': key, 'anthropic-version': '2023-06-01', accept: 'application/json' }
    : { authorization: `Bearer ${key}`, accept: 'application/json' };
  if (anthropicApi) url.searchParams.set('limit', '100');
  return { url, headers, anthropicApi, ...resolved };
}

export async function fetchModels(request, network, signal) {
  const models = new Map();
  let bytes = 0;
  const cursors = new Set();
  for (let page = 0; page < 20; page++) {
    signal.throwIfAborted();
    const response = await network.fetch(request.url, { method: 'GET', headers: request.headers, signal });
    if (!response.ok) {
      await response.body?.cancel();
      throw new Error(response.status === 404 || response.status === 405 ? 'modelsUnsupported' : `HTTP ${response.status}`);
    }
    const chunks = [];
    for await (const chunk of response.body ?? []) {
      bytes += chunk.byteLength;
      if (bytes > 512 * 1024) { await response.body?.cancel().catch(() => {}); throw new Error('modelListLimit'); }
      chunks.push(Buffer.from(chunk));
    }
    signal.throwIfAborted();
    const data = JSON.parse(Buffer.concat(chunks).toString('utf8'));
    if (!data || !Array.isArray(data.data)) throw new Error('invalidModelList');
    for (const model of data.data) {
      if (!model || typeof model.id !== 'string' || !model.id.trim() || model.id.length > 200 || /[\x00-\x1f\x7f]/.test(model.id)) throw new Error('invalidModelList');
      const name = model.display_name ?? model.name ?? model.id;
      if (typeof name !== 'string' || name.length > 200 || /[\x00-\x1f\x7f]/.test(name)) throw new Error('invalidModelList');
      models.set(model.id, { id: model.id, name });
      if (models.size > 1000) throw new Error('modelListLimit');
    }
    if (!request.anthropicApi || data.has_more !== true) return [...models.values()];
    if (typeof data.last_id !== 'string' || !data.last_id || data.last_id.length > 200 || cursors.has(data.last_id)) throw new Error('invalidModelList');
    cursors.add(data.last_id);
    request.url.searchParams.set('after_id', data.last_id);
  }
  throw new Error('modelListLimit');
}
