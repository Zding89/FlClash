import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { appendFile, mkdir } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';
import { randomUUID } from 'node:crypto';

const root = '/private/tmp/flclash-agent-acceptance';
const model = 'flclash-agent-acceptance';
const names = [
  'workspace_overview', 'sources_query', 'nodes_query', 'policy_edit_schema',
  'policy_draft_edit', 'policy_preview', 'policy_draft_read', 'rules_query',
  'node_sets_query', 'changes_commit', 'changes_status', 'tools_catalog', 'task_finish',
];
const text = content => typeof content === 'string' ? content :
  Array.isArray(content) ? content.map(part => part.text ?? '').join('\n') : '';
const parse = value => { try { return JSON.parse(text(value)); } catch { return {}; } };
const unwrap = value => value?.result && typeof value.result === 'object' && !Array.isArray(value.result)
  ? { ...value, ...value.result } : value;
const draftId = value => value?.proposal?.id ?? value?.draftId ?? (value?.status === 'draft' ? value?.id : undefined);

function transcript(body) {
  const messages = body.messages ?? [];
  const lastUser = messages.findLastIndex(message => message.role === 'user');
  const calls = new Map();
  const results = [];
  for (let index = 0; index < messages.length; index++) {
    const message = messages[index];
    for (const call of message.tool_calls ?? []) {
      calls.set(call.id, { name: call.function.name, arguments: parse(call.function.arguments) });
    }
    if (message.role === 'tool') {
      const call = calls.get(message.tool_call_id);
      if (call) results.push({ ...call, index, value: unwrap(parse(message.content)) });
    }
  }
  return {
    user: text(messages[lastUser]?.content), results,
    current: results.filter(result => result.index > lastUser),
    previous: results.filter(result => result.index < lastUser),
    available: new Set((body.tools ?? []).map(tool => tool.function?.name ?? tool.name)),
  };
}

export function nextAcceptanceStep(body) {
  const state = transcript(body);
  const { user, current, previous, available } = state;
  const latest = name => current.findLast(result => result.name === name);
  const invoke = (name, args = {}) => available.has(name)
    ? { name, arguments: args }
    : { name: 'tools_catalog', arguments: { names: [name] } };
  const finish = (status, summary, extra = {}) => invoke('task_finish', { status, summary, ...extra });
  if (/429|限流测试/i.test(user)) return { httpStatus: 429 };
  if (/503|服务故障测试/.test(user)) return { httpStatus: 503 };
  const failure = current.findLast(result => result.value?.code || result.value?.errorCode || result.value?.status === 'failed');
  if (failure && failure.name !== 'task_finish') {
    return finish('needs_input', '真实工具返回了阻碍，本轮未提交或重放写入。请根据界面提示处理后继续。', {
      reason: String(failure.value.errorCode ?? failure.value.code ?? 'tool_failed'),
    });
  }
  if (!latest('workspace_overview')) return invoke('workspace_overview');
  const priorDraft = previous.findLast(result => draftId(result.value));
  const priorId = priorDraft && draftId(priorDraft.value);
  if (priorId && !latest('policy_draft_read') && !latest('policy_draft_edit')) {
    return invoke('policy_draft_read', { id: priorId });
  }
  const apply = /应用|提交|批准|\bapply\b/i.test(user) && !/不要应用|不用应用|仅草稿|只.*草稿/.test(user);
  if (apply) {
    if (!priorId) return finish('needs_input', '没有可确认的当前草稿，请先生成方案。', { reason: 'no_current_draft' });
    if (!latest('changes_commit')) return invoke('changes_commit', { id: priorId });
    if (!latest('changes_status')) return invoke('changes_status', { id: priorId });
    const rawReceipt = latest('changes_status').value;
    const receipt = rawReceipt.change ?? rawReceipt;
    if (!['applied', 'completed', 'saved'].includes(receipt.status)) {
      return finish('needs_input', '本次操作尚未确认应用成功，请查看方案卡片的真实状态。', {
        reason: String(receipt.code ?? receipt.status ?? 'unconfirmed_operation'),
      });
    }
    return finish('completed', '本次方案已按真实操作回执保存并应用；未进行实际网站访问验证。', {
      proposalId: priorId, operationId: receipt.operationId ?? priorId,
    });
  }
  const recovering = /恢复|重开|查看|读取|状态|继续审阅|确认草稿|\brecover\b|\breopen\b|\bresume\b/i.test(user) && !/改名|重命名|修改|改用|换组|切换|调整|更新/.test(user);
  if (recovering && priorId) {
    const read = latest('policy_draft_read');
    const preview = latest('policy_preview');
    if (!preview) return invoke('policy_preview', { draftId: priorId, version: read.value.version });
    if (read.index < preview.index) return invoke('policy_draft_read', { id: priorId });
    return finish('draft_ready', '已重新查询同一草稿并恢复当前真实方案，未重放提交或复用旧审批。', { proposalId: priorId });
  }
  if (!latest('sources_query')) return invoke('sources_query', { limit: 20 });
  if (!latest('nodes_query')) return invoke('nodes_query', { fields: ['attributes'], limit: 20 });
  for (const kind of ['nodeSet', 'rule', 'settings']) {
    if (!current.some(result => result.name === 'policy_edit_schema' && result.arguments.kind === kind)) {
      return invoke('policy_edit_schema', { kind });
    }
  }
  const edit = latest('policy_draft_edit');
  if (!edit) {
    const overview = latest('workspace_overview').value;
    const sourceIds = (latest('sources_query').value.sources ?? []).map(source => source.id);
    if (sourceIds.length < 2) return finish('needs_input', '验收机场数据不足，请检查独立数据目录。', { reason: 'fixture_sources_missing' });
    const read = latest('policy_draft_read');
    if (priorId && read) {
      const summary = read.value.businessSummary ?? {};
      const rules = summary.rules ?? [];
      const sets = summary.nodeSets ?? [];
      if (!rules.length || !sets.length) {
        if (!latest('rules_query')) return invoke('rules_query', { draftId: priorId, limit: 20 });
        if (!latest('node_sets_query')) return invoke('node_sets_query', { draftId: priorId, limit: 20 });
      }
      const actualRules = rules.length ? rules : latest('rules_query').value.rules ?? [];
      const actualSets = sets.length ? sets : latest('node_sets_query').value.nodeSets ?? [];
      const rule = actualRules.find(rule => /AI|验收/.test(rule.label)) ?? actualRules[0];
      const primary = actualSets.find(set => /主选|优先/.test(set.label)) ?? actualSets[0];
      const hongKong = actualSets.find(set => /香港/.test(set.label)) ?? actualSets.at(-1);
      if (!rule?.id || !primary?.id || !hongKong?.id) return finish('needs_input', '无法定位真实草稿中的目标规则或节点组。', { reason: 'draft_reference_missing' });
      let actions;
      if (/换组|改用|切换|换成|香港|\bswitch\b|\bHK\b/i.test(user) && !/改名|重命名/.test(user)) {
        actions = [{ action: 'updateRule', id: rule.id, fields: { choices: [{ type: 'nodeSet', id: hongKong.id }] } }];
      } else {
        const label = user.match(/[“「"]([^”」"]{1,60})[”」"]/)?.[1] ?? user.match(/(?:改名为|重命名为|名称改为|名字改为)[：:\s]*([^，。；\n]{1,60})/)?.[1]?.trim() ?? 'AI 验收规则（续改）';
        const group = /节点组|分组/.test(user);
        actions = [{ action: group ? 'updateNodeSet' : 'updateRule', id: group ? primary.id : rule.id, fields: { label } }];
      }
      return invoke('policy_draft_edit', { draftId: priorId, version: read.value.version, actions });
    }
    const probe = { automatic: false, url: 'http://127.0.0.1:9/acceptance', method: 'GET', expectedStatus: '204' };
    const set = (clientKey, label, ids, regions) => ({
      action: 'createNodeSet', clientKey,
      fields: { label, sourceIds: ids, regions, probe, unknownMultiplier: 'allow', preferences: [{ type: 'multiplier', direction: 'ascending' }] },
    });
    const choices = (...ids) => ids.map(id => ({ type: 'nodeSet', id }));
    return invoke('policy_draft_edit', {
      version: overview.version,
      actions: [
        { action: 'updateSettings', fields: { moduleEnabled: true, policiesEnabled: true, integrationEnabled: true } },
        set('primary-us', '机场 A 美区主选', [sourceIds[0]], ['US']),
        set('backup-us', '其他机场低倍率美区', [sourceIds[1]], ['US']),
        set('hong-kong', '香港备用', sourceIds, ['HK']),
        { action: 'createRule', clientKey: 'ai-rule', fields: { label: 'AI 验收规则', scope: { type: 'domainSuffix', values: ['ai.example.test'] }, choices: choices('primary-us', 'backup-us'), probe } },
        { action: 'createRule', fields: { label: '验收 cn 后缀直连', scope: { type: 'domainSuffix', values: ['cn'] }, action: 'direct', probe } },
        { action: 'createRule', fields: { label: '其余流量香港', scope: { type: 'global' }, choices: choices('hong-kong'), probe } },
      ],
    });
  }
  const id = draftId(edit.value);
  if (!id) return finish('failed', '工具没有返回真实草稿引用，无法继续验收。', { reason: 'draft_reference_missing' });
  if (!latest('policy_preview')) return invoke('policy_preview', { draftId: id, version: edit.value.version });
  const finalRead = current.findLast(result => result.name === 'policy_draft_read' && result.index > edit.index);
  if (!finalRead) return invoke('policy_draft_read', { id });
  if (finalRead.value.validation?.valid !== true) return finish('needs_input', '真实草稿校验尚未通过，请查看方案卡片。', { reason: 'draft_validation_failed' });
  return finish('draft_ready', '当前草稿已从真实工具重新读取并通过校验，仅等待本地审阅；未提交或进行网站访问验证。', { proposalId: id });
}

function sse(response, step) {
  const id = `chatcmpl-acceptance-${randomUUID()}`;
  const chunk = (delta, finish_reason = null) => `data: ${JSON.stringify({
    id, object: 'chat.completion.chunk', created: Math.floor(Date.now() / 1000), model,
    choices: [{ index: 0, delta, finish_reason }],
  })}\n\n`;
  response.writeHead(200, { 'content-type': 'text/event-stream', 'cache-control': 'no-cache', connection: 'keep-alive' });
  response.write(chunk({ role: 'assistant', content: null }));
  response.write(chunk({ tool_calls: [{ index: 0, id: `call_${randomUUID()}`, type: 'function', function: { name: step.name, arguments: JSON.stringify(step.arguments) } }] }));
  response.write(chunk({}, 'tool_calls'));
  response.end('data: [DONE]\n\n');
}

export async function startAcceptanceModel() {
  await mkdir(root, { recursive: true });
  const server = createServer(async (request, response) => {
    if (request.method === 'GET' && request.url === '/health') {
      response.writeHead(200, { 'content-type': 'application/json' });
      response.end(JSON.stringify({ status: 'ready', model, controlled: true }));
      return;
    }
    if (request.method === 'GET' && request.url === '/v1/models') {
      response.writeHead(200, { 'content-type': 'application/json' });
      response.end(JSON.stringify({ object: 'list', data: [{ id: model, object: 'model', owned_by: 'local-acceptance' }] }));
      return;
    }
    if (request.method !== 'POST' || request.url !== '/v1/chat/completions') {
      response.writeHead(404).end(); return;
    }
    if (request.headers.authorization !== 'Bearer acceptance-fixture-key-not-a-real-secret') {
      response.writeHead(401, { 'content-type': 'application/json' });
      response.end(JSON.stringify({ error: { message: 'invalid fixture key' } })); return;
    }
    try {
      const chunks = []; let size = 0;
      for await (const chunk of request) {
        size += chunk.length;
        if (size > 2 * 1024 * 1024) throw new Error('request_too_large');
        chunks.push(chunk);
      }
      const body = JSON.parse(Buffer.concat(chunks).toString('utf8'));
      const step = nextAcceptanceStep(body);
      const state = transcript(body);
      await appendFile(`${root}/model-requests.jsonl`, `${JSON.stringify({
        at: new Intl.DateTimeFormat('sv-SE', { timeZone: 'Asia/Shanghai', dateStyle: 'short', timeStyle: 'medium', hour12: false }).format(new Date()),
        requestBytes: size, user: state.user, step, messages: body.messages, tools: (body.tools ?? []).map(tool => tool.function?.name),
      })}\n`);
      if (step.httpStatus) {
        response.writeHead(step.httpStatus, { 'content-type': 'application/json', 'retry-after': '0' });
        response.end(JSON.stringify({ error: { message: `controlled acceptance ${step.httpStatus}`, type: 'acceptance_error', code: String(step.httpStatus) } }));
      } else sse(response, step);
    } catch (error) {
      if (!response.headersSent) response.writeHead(400, { 'content-type': 'application/json' });
      response.end(JSON.stringify({ error: { message: String(error.message) } }));
    }
  });
  await new Promise((resolve, reject) => { server.once('error', reject); server.listen(49385, '127.0.0.1', resolve); });
  process.stdout.write('Controlled acceptance model: http://127.0.0.1:49385/v1\n');
  for (const signal of ['SIGINT', 'SIGTERM']) process.once(signal, () => server.close(() => process.exit(0)));
  return server;
}

async function selfTest() {
  const tools = names.map(name => ({ type: 'function', function: { name } }));
  assert.equal(nextAcceptanceStep({ messages: [{ role: 'user', content: '生成验收方案' }], tools }).name, 'workspace_overview');
  assert.equal(nextAcceptanceStep({ messages: [{ role: 'user', content: '模拟429' }], tools }).httpStatus, 429);
  assert.equal(nextAcceptanceStep({ messages: [{ role: 'user', content: '模拟503' }], tools }).httpStatus, 503);
  const messages = [{ role: 'user', content: '继续' }];
  const add = (name, argumentsValue, value) => {
    const id = `test-${messages.length}`;
    messages.push({ role: 'assistant', tool_calls: [{ id, type: 'function', function: { name, arguments: JSON.stringify(argumentsValue) } }] });
    messages.push({ role: 'tool', tool_call_id: id, content: JSON.stringify(value) });
  };
  add('workspace_overview', {}, { version: 'saved-version' });
  assert.equal(nextAcceptanceStep({ messages, tools }).name, 'sources_query');
  add('sources_query', {}, { sources: [{ id: 'source-a' }, { id: 'source-b' }] });
  add('nodes_query', {}, { nodes: [] });
  for (const kind of ['nodeSet', 'rule', 'settings']) add('policy_edit_schema', { kind }, {});
  const edit = nextAcceptanceStep({ messages, tools });
  assert.equal(edit.name, 'policy_draft_edit');
  assert.equal(edit.arguments.version, 'saved-version');
  assert.equal(edit.arguments.actions.filter(action => action.action === 'createNodeSet').length, 3);
  const hidden = nextAcceptanceStep({ messages, tools: tools.filter(tool => tool.function.name !== 'policy_draft_edit') });
  assert.deepEqual(hidden, { name: 'tools_catalog', arguments: { names: ['policy_draft_edit'] } });
  add('policy_draft_edit', edit.arguments, { proposal: { id: 'self-test-draft' }, version: 'draft-version' });
  const summary = {
    rules: [{ id: 'self-test-rule', label: 'AI 验收规则' }],
    nodeSets: [{ id: 'self-test-primary', label: '美区主选' }, { id: 'self-test-hk', label: '香港备用' }],
  };
  add('policy_draft_read', { id: 'self-test-draft' }, { id: 'self-test-draft', status: 'draft', version: 'draft-version', validation: { valid: true }, businessSummary: summary });
  messages.push({ role: 'user', content: '把规则改名为“验收续改”' });
  add('workspace_overview', {}, { version: 'saved-version' });
  assert.deepEqual(nextAcceptanceStep({ messages, tools }), { name: 'policy_draft_read', arguments: { id: 'self-test-draft' } });
  add('policy_draft_read', { id: 'self-test-draft' }, { id: 'self-test-draft', status: 'draft', version: 'draft-version', validation: { valid: true }, businessSummary: summary });
  add('sources_query', {}, { sources: [{ id: 'source-a' }, { id: 'source-b' }] });
  add('nodes_query', {}, { nodes: [] });
  for (const kind of ['nodeSet', 'rule', 'settings']) add('policy_edit_schema', { kind }, {});
  const rename = nextAcceptanceStep({ messages, tools });
  assert.equal(rename.arguments.draftId, 'self-test-draft');
  assert.equal(rename.arguments.version, 'draft-version');
  assert.deepEqual(rename.arguments.actions, [{ action: 'updateRule', id: 'self-test-rule', fields: { label: '验收续改' } }]);
  messages[messages.findLastIndex(message => message.role === 'user')].content = '恢复并查看当前草稿';
  assert.equal(nextAcceptanceStep({ messages, tools }).name, 'policy_preview');
  const { providerStream, resolveSettings } = await import('../packages/ai_agent_host/src/providers.mjs');
  const resolved = resolveSettings({ provider: 'custom', model, baseUrl: 'http://127.0.0.1:49385/v1', api: 'openai-completions' });
  const stream = providerStream(resolved.model, {
    messages: [
      { role: 'system', content: 'Controlled acceptance parser check', timestamp: 0, toolsAdded: [{ name: 'workspace_overview', description: 'Read overview', parameters: { type: 'object', properties: {} } }] },
      { role: 'user', content: '生成验收方案', timestamp: Date.now() },
    ],
  }, {
    apiKey: 'acceptance-fixture-key-not-a-real-secret', maxRetries: 0,
    fetch: async (_, init) => {
      const body = JSON.parse(init.body);
      const frames = [];
      sse({ writeHead() {}, write(value) { frames.push(value); }, end(value) { frames.push(value); } }, nextAcceptanceStep(body));
      return new Response(frames.join(''), { status: 200, headers: { 'content-type': 'text/event-stream' } });
    },
  });
  const parsed = await stream.result();
  assert.equal(parsed.stopReason, 'toolUse');
  assert.equal(parsed.content.find(part => part.type === 'toolCall')?.name, 'workspace_overview');
  process.stdout.write('Acceptance planner parsing checks passed.\n');
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  if (process.argv.includes('--self-test')) await selfTest();
  else await startAcceptanceModel();
}
