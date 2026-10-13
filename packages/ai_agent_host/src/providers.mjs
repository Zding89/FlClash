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
export function resolveSettings(settings) {
  if (!settings || typeof settings.model !== 'string' || !settings.model.trim() || settings.model.length > 200) throw new Error('invalidSettings');
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
