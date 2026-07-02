const $ = (id) => document.getElementById(id);

const PRESETS = {
  python: {
    topic: 'Python 入门：从零到做出第一个自动化脚本',
    brief: '面向没有编程基础的学习者，讲清变量、循环、函数、列表、字典和第一个文件整理脚本。',
    audience: '零基础学习者 / 培训学员',
    theme: 'education_light',
    mode: 'balanced',
    template_type: 'educational_course'
  },
  review: {
    topic: '个人年度复盘：从结果、反思到下一年计划',
    brief: '串联年度主线、三件成果、三个坑、认知变化和明年行动计划。',
    audience: '个人成长分享 / 团队复盘',
    theme: 'minimal_white',
    mode: 'balanced',
    template_type: 'annual_review'
  },
  coffee: {
    topic: '如何选择适合自己的咖啡豆',
    brief: '从烘焙度、产地、处理法、风味轮和购买决策框架出发，帮助新手买到适合自己的咖啡豆。',
    audience: '咖啡新手 / 生活方式用户',
    theme: 'coffee_warm',
    mode: 'beauty',
    template_type: 'decision_guide'
  },
  rust: {
    topic: 'Rust 重构订单系统：给 CEO 的投资回报论证',
    brief: '从业务损失、性能瓶颈、并发稳定性、重写成本、ROI、迁移风险和立项路径说服管理层。',
    audience: 'CEO / CTO / 业务负责人',
    theme: 'executive_dark',
    mode: 'beauty',
    template_type: 'executive_proposal'
  },
  kyoto: {
    topic: '京都两日游路线：从清水寺到岚山',
    brief: '用两天时间线组织京都旅行体验，包含路线节奏、交通建议、预算、拍照点和避坑提醒。',
    audience: '自由行游客 / 旅行分享',
    theme: 'travel_editorial',
    mode: 'beauty',
    template_type: 'travel_guide'
  }
};

const TEMPLATE_RULES = {
  educational_course: '学习目标、概念地图、核心概念、例子、练习、小项目、常见错误、总结',
  executive_proposal: '结论先行、业务问题、影响、方案、收益、风险、迁移计划、决策请求',
  decision_guide: '决策问题、评价维度、选项、对比矩阵、推荐路径、避坑、总结',
  travel_guide: '行程总览、Day1、Day2、交通、预算、拍照点、避坑、清单',
  annual_review: '年度主线、成果、坑、转折、反思、下一年计划、总结',
  proposal: '背景、目标、问题、方案、流程、价值、风险、下一步'
};

const BANNED_TERMS = [
  '形成清晰判断','具体执行建议','本页聚焦','听众看完','为什么重要','为什么现在要关注',
  '保留一个可复盘','把复杂内容变成清晰','解释XXX关系','解释XXX','继续判断',
  '视觉化表达','核心观点先行','结构化叙事','Prompt说明','code','rocket','warning','database','BK','CHT','TGT','CF'
];

const MODES = ['beauty', 'balanced'];
let lastPromptMetrics = null;
let lastSpec = null;
let lastMetrics = null;

document.addEventListener('DOMContentLoaded', () => {
  $('topicPreset').addEventListener('change', applyPreset);
  $('promptButton').addEventListener('click', generatePrompt);
  $('generateButton').addEventListener('click', generateDeck);
  $('batchButton').addEventListener('click', generateAllDemos);
  applyPreset();
});

function applyPreset(){
  const key = $('topicPreset').value;
  if(key === 'custom'){
    $('topicInput').value = '';
    $('briefInput').value = '';
    $('audienceInput').value = '';
    $('themeName').value = 'auto';
    $('qualityMode').value = 'beauty';
    $('promptInput').value = '';
    $('generateButton').disabled = true;
    lastPromptMetrics = null;
    showMuted('等待输入', '请填写主题、简介和目标受众。');
    return;
  }
  const item = PRESETS[key];
  $('topicInput').value = item.topic;
  $('briefInput').value = item.brief;
  $('audienceInput').value = item.audience;
  $('themeName').value = item.theme;
  $('qualityMode').value = item.mode;
  $('promptInput').value = '';
  $('generateButton').disabled = true;
  lastPromptMetrics = null;
  showMuted('等待生成', '先生成 Prompt，确认后再生成 PPT。');
}

function collectInput(){
  const preset = PRESETS[$('topicPreset').value];
  return {
    topic: $('topicInput').value.trim(),
    brief: $('briefInput').value.trim(),
    audience: $('audienceInput').value.trim(),
    mode: $('qualityMode').value,
    theme: $('themeName').value,
    template_type: preset ? preset.template_type : inferTemplate($('topicInput').value + ' ' + $('briefInput').value)
  };
}

function inferTemplate(text){
  const t = String(text || '').toLowerCase();
  if(/入门|教程|学习|培训|python|course|training/.test(t)) return 'educational_course';
  if(/复盘|总结|年度|月度|review/.test(t)) return 'annual_review';
  if(/旅行|路线|城市|两日|travel|kyoto/.test(t)) return 'travel_guide';
  if(/ceo|老板|立项|roi|说服|投资|proposal|rust/.test(t)) return 'executive_proposal';
  if(/选择|挑选|购买|决策|decision|咖啡/.test(t)) return 'decision_guide';
  return 'proposal';
}

async function generatePrompt(){
  const input = collectInput();
  if(!input.topic){ showError('请先填写主题。'); return; }
  setBusy('promptButton', '正在生成...');
  $('generateButton').disabled = true;
  showMuted('正在生成 Prompt', '正在调用 OpenAI 规划意图、知识扩展、故事线和视觉策略。');
  try {
    const json = await requestPrompt(input);
    $('promptInput').value = formatPromptText(json.presentation_prompt || '');
    if(!$('promptInput').value.trim()) throw new Error('OpenAI 未返回可用 Prompt。');
    $('generateButton').disabled = false;
    lastPromptMetrics = buildMetrics(input, json, 'prompt_generated', performance.now() - json._started, 0, '', 0);
    lastPromptMetrics.db_log = await recordMetrics(input, lastPromptMetrics, 'prompt_generated', '');
    showSuccess('Prompt 已生成', formatPromptSummary(lastPromptMetrics));
  } catch(error) {
    $('promptInput').value = '';
    $('generateButton').disabled = true;
    lastPromptMetrics = null;
    showError(`OpenAI Prompt 生成失败，已停止：${error.message || error}`);
  } finally {
    resetButton('promptButton', '生成 Prompt');
  }
}

async function generateDeck(){
  const input = collectInput();
  const prompt = $('promptInput').value.trim();
  if(!input.topic || !prompt){ showError('请先生成或填写 Prompt。'); return; }
  setBusy('generateButton', '任务已提交...');
  showMuted('正在创建任务', '正在写入任务队列，随后由 worker 异步生成 PPT。');
  try {
    const job = await createJob(input, prompt);
    showMuted('任务已入队', `Job #${job.jobId} 已创建，worker 正在后台生成。`);
    triggerWorker(job.jobId);
    const done = await pollJob(job.jobId);
    lastMetrics = done.metrics || null;
    showSuccess('PPT 已生成并开始下载', formatJobSummary(done));
    if(done.downloadUrl) window.location.href = done.downloadUrl;
  } catch(error) {
    showError(error.message || String(error));
  } finally {
    resetButton('generateButton', '生成 PPT');
  }
}

async function generateAllDemos(){
  setBusy('batchButton', '批量入队中...');
  $('generateButton').disabled = true;
  const rows = [];
  try {
    const keys = Object.keys(PRESETS);
    for(const key of keys){
      for(const mode of MODES){
        const base = PRESETS[key];
        const input = {...base, mode};
        const job = await createJob(input, '');
        triggerWorker(job.jobId);
        rows.push({topic: input.topic, mode, file: `Job #${job.jobId}`, slides: 0, tokens: 0, cost: 0, status: 'queued'});
        showSuccess('批量生成中', formatBatchRows(rows));
      }
    }
    showSuccess('10 个 Demo 已入队', 'worker 会逐个处理 queued 任务。页面可继续使用，稍后刷新或查看数据库状态。');
  } catch(error) {
    showError(`批量入队已停止：${error.message || error}\n\n已入队：\n${formatBatchRows(rows)}`);
  } finally {
    resetButton('batchButton', '生成全部 Demo');
    $('generateButton').disabled = !$('promptInput').value.trim();
  }
}

async function createJob(input, prompt){
  const json = await postJson('api/createJob.cfm', {
    ...input,
    presentation_prompt: prompt || '',
    template_rules: TEMPLATE_RULES[input.template_type] || TEMPLATE_RULES.proposal
  });
  if(!json.success) throw new Error(json.message || json.detail || '创建任务失败。');
  if(!json.jobId) throw new Error('创建任务未返回 jobId。');
  return json;
}

function triggerWorker(jobId){
  fetch(`api/worker_generate.cfm?jobId=${encodeURIComponent(jobId)}`, {method:'POST'}).catch(() => {});
}

async function pollJob(jobId){
  const started = Date.now();
  while(true){
    const status = await getJobStatus(jobId);
    const line = `Job #${jobId} · ${status.status} · ${status.progress || 0}% · ${status.currentStep || ''}`;
    showMuted('异步生成中', line);
    if(status.status === 'queued') triggerWorker(jobId);
    if(status.status === 'completed') return status;
    if(status.status === 'failed') throw new Error(status.errorMessage || '任务生成失败。');
    if(Date.now() - started > 20 * 60 * 1000) throw new Error('任务等待超时，请稍后刷新查看状态。');
    await sleep(2000);
  }
}

async function getJobStatus(jobId){
  const res = await fetch(`api/jobStatus.cfm?jobId=${encodeURIComponent(jobId)}`);
  const text = await res.text();
  let json;
  try { json = JSON.parse(text); } catch(error) { throw new Error(`状态接口返回不是 JSON：${text.slice(0, 200)}`); }
  if(!json.success) throw new Error(json.message || json.detail || '读取任务状态失败。');
  return json;
}

function sleep(ms){ return new Promise((resolve) => setTimeout(resolve, ms)); }

async function requestPrompt(input){
  const started = performance.now();
  const json = await postJson('api/prompt.cfm', {...input, template_rules: TEMPLATE_RULES[input.template_type] || TEMPLATE_RULES.proposal});
  json._started = started;
  if(!json.success) throw new Error(json.message || json.detail || 'Prompt 生成失败。');
  if(String(json.source || '').toLowerCase() !== 'openai') throw new Error('OpenAI Prompt 未成功生成。');
  return json;
}

function normalizeSpec(spec, input){
  if(!spec || !Array.isArray(spec.slides)) throw new Error('OpenAI Slide Spec 无效：缺少 slides。');
  const wanted = input.mode === 'beauty' ? 24 : 22;
  const minSlides = input.mode === 'beauty' ? 22 : 20;
  const sourceSlides = spec.slides.slice(0, wanted);
  if(sourceSlides.length < minSlides) throw new Error(`OpenAI Slide Spec 页数不足：${sourceSlides.length}。`);

  const seenTitles = new Set();
  const seenPoints = new Set();
  let lastLayouts = [];
  const slides = sourceSlides.map((slide, idx) => {
    assertNoBannedSlide(slide, idx + 1);
    let title = clean(slide.title) || `${clean(input.topic)}：第 ${idx + 1} 页`;
    if(seenTitles.has(title)) throw new Error(`OpenAI Slide Spec 标题重复：${title}`);
    seenTitles.add(title);
    let layoutType = normalizeLayout(slide.layoutType, idx);
    lastLayouts.push(layoutType);
    if(lastLayouts.length > 3) lastLayouts.shift();
    if(lastLayouts.length === 3 && lastLayouts.every((v) => v === layoutType)) throw new Error(`连续三页使用相同布局：${layoutType}`);

    const points = []
      .concat(slide.coreMessage ? [slide.coreMessage] : [])
      .concat(Array.isArray(slide.supportingPoints) ? slide.supportingPoints : [])
      .concat(Array.isArray(slide.points) ? slide.points : [])
      .concat(slide.caseExample ? [`案例：${slide.caseExample}`] : [])
      .concat(slide.actionAdvice ? [`行动建议：${slide.actionAdvice}`] : [])
      .map(clean)
      .filter(Boolean)
      .filter((p) => {
        if(seenPoints.has(p)) return false;
        seenPoints.add(p);
        return true;
      })
      .slice(0, 5);
    if(points.length < 2) throw new Error(`第 ${idx + 1} 页内容不足。`);
    return {
      slideNo: idx + 1,
      section: clean(slide.section) || sectionName(idx, wanted),
      layoutType,
      title,
      coreMessage: clean(slide.coreMessage || slide.subtitle || points[0]),
      supportingPoints: points,
      thinkAboutIt: clean(slide.thinkAboutIt || ''),
      visualType: clean(slide.visualType || 'cards'),
      visualIntent: clean(slide.visualIntent || ''),
      imagePlan: typeof slide.imagePlan === 'object' && slide.imagePlan ? slide.imagePlan : {image_role:'none', image_prompt:'', placement:''},
      chartSpec: typeof slide.chartSpec === 'object' && slide.chartSpec ? slide.chartSpec : null,
      chartSuggestion: typeof slide.chartSuggestion === 'object' && slide.chartSuggestion ? slide.chartSuggestion : {chartType:'none', reason:'', dataHint:''},
      speakerNote: clean(slide.speakerNote || '')
    };
  });
  return {...spec, deckTitle: clean(spec.deckTitle) || input.topic, subtitle: clean(spec.subtitle) || input.brief, audience: clean(spec.audience) || input.audience, templateType: clean(spec.templateType || input.template_type), themeHint: clean(spec.themeHint || input.theme), slides};
}

function assertNoBannedSlide(slide, slideNo){
  const pieces = [slide.title, slide.subtitle, slide.coreMessage, slide.thinkAboutIt, slide.speakerNote];
  if(Array.isArray(slide.supportingPoints)) pieces.push(...slide.supportingPoints);
  if(Array.isArray(slide.points)) pieces.push(...slide.points);
  const text = pieces.map((item) => String(item || '')).join('\n').toLowerCase();
  for(const term of BANNED_TERMS){
    if(text.includes(String(term).toLowerCase())) throw new Error(`第 ${slideNo} 页包含禁用词：${term}`);
  }
}

function normalizeLayout(layout, idx){
  const allowed = ['cover','agenda','section','section_divider','timeline','cards','data_cards','process','process_steps','comparison','matrix','framework_matrix','table','big_number','quote','summary','closing','roadmap','two_column'];
  const seq = ['cover','agenda','section_divider','cards','timeline','comparison','matrix','big_number','process_steps','quote','table','summary','closing'];
  const value = clean(layout);
  return allowed.includes(value) ? value : seq[idx % seq.length];
}

function sectionName(idx, total){
  const zones = ['开场','背景','主体','方法','行动','总结'];
  return zones[Math.min(zones.length - 1, Math.floor(idx / Math.ceil(total / zones.length)))];
}

async function postJson(url, payload){
  const res = await fetch(url, {method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify(payload)});
  const text = await res.text();
  try { return JSON.parse(text); } catch(error) { throw new Error(`接口返回不是 JSON：${text.slice(0, 260)}`); }
}

function buildMetrics(input, json, stageName, durationMs, slideCount, fileName, fileSize){
  return {
    provider: json.source || 'openai',
    model: json.model || '',
    prompt_tokens: Number(json.prompt_tokens || 0),
    completion_tokens: Number(json.completion_tokens || 0),
    total_tokens: Number(json.total_tokens || 0),
    estimated_cost: Number(json.estimated_cost || 0),
    duration_ms: Math.round(durationMs || 0),
    slide_count: Number(slideCount || 0),
    ppt_filename: fileName || '',
    ppt_size: Number(fileSize || 0),
    template_type: input.template_type || '',
    stage_name: stageName
  };
}

async function recordMetrics(input, metrics, stageName, errorMessage){
  try {
    const json = await postJson('api/log.cfm', {...input, ...metrics, stage_name: stageName, status: errorMessage ? 'failed' : 'success', error_message: errorMessage || ''});
    if(!json || !json.success) return {success:false, message:(json && json.message) || '数据库记录失败', detail:(json && json.detail) || ''};
    return json;
  } catch(error) {
    return {success:false, message:'数据库记录请求失败', detail:error.message || String(error)};
  }
}

function formatPromptText(text){
  return String(text || '').replace(/\r\n/g, '\n').replace(/(一、|二、|三、|四、|五、|六、|七、|Agent\d+|Intent Planner|Knowledge Builder|Presentation Strategist|Story Architect|Visual Director|Slide Planner|Presentation Critic)/g, '\n\n$1').replace(/\n{3,}/g, '\n\n').trim();
}

function formatPromptSummary(m){ return formatMetrics({source:m.provider, model:m.model, prompt_tokens:m.prompt_tokens, completion_tokens:m.completion_tokens, total_tokens:m.total_tokens, estimated_cost:m.estimated_cost, duration:m.duration_ms, db_log:m.db_log}); }
function formatJobSummary(status){
  const m = status.metrics || {};
  return [
    `Job #${status.jobId} · 状态：${status.status}`,
    `来源：${m.provider || 'openai'} · 模型：${m.model || ''}`,
    `Prompt Tokens：${m.prompt_tokens || 0} · Completion Tokens：${m.completion_tokens || 0} · Total Tokens：${m.total_tokens || 0}`,
    `Estimated Cost：$${Number(m.estimated_cost || 0).toFixed(5)} · 耗时：${m.duration_ms || 0} ms`,
    `页数：${m.slide_count || 0} · 文件大小：${Math.round(Number(m.ppt_size || 0) / 1024)} KB`,
    status.fileName ? `文件：${status.fileName}` : ''
  ].filter(Boolean).join('\n');
}
function formatRunSummary(p, d){
  p = p || {};
  const totalTokens = Number(p.total_tokens || 0) + Number(d.total_tokens || 0);
  const totalCost = Number(p.estimated_cost || 0) + Number(d.estimated_cost || 0);
  const totalDuration = Number(p.duration_ms || 0) + Number(d.duration_ms || 0);
  return [
    `生成 Prompt：${p.provider || 'openai'} · ${p.model || ''} · Prompt ${p.prompt_tokens || 0} · Completion ${p.completion_tokens || 0} · Total ${p.total_tokens || 0} · Cost $${Number(p.estimated_cost || 0).toFixed(5)} · ${p.duration_ms || 0} ms`,
    `生成 PPT：${d.provider || 'openai'} · ${d.model || ''} · Prompt ${d.prompt_tokens || 0} · Completion ${d.completion_tokens || 0} · Total ${d.total_tokens || 0} · Cost $${Number(d.estimated_cost || 0).toFixed(5)} · ${d.duration_ms || 0} ms`,
    `合计：Total Tokens ${totalTokens} · Estimated Cost $${totalCost.toFixed(5)} · 总耗时 ${totalDuration} ms · 页数 ${d.slide_count || 0} · 文件大小 ${Math.round(Number(d.ppt_size || 0) / 1024)} KB`,
    `Prompt ${formatDbLog(p.db_log)}`,
    `PPT ${formatDbLog(d.db_log)}`
  ].join('\n');
}
function formatBatchRows(rows){ return rows.map((r, i) => `${i + 1}. ${r.topic} / ${r.mode} / ${r.slides}页 / ${r.tokens} tokens / $${Number(r.cost).toFixed(5)} / ${r.file}`).join('\n') || '尚未完成。'; }
function formatMetrics(m){
  const parts = [];
  if(m.source) parts.push(`来源：${m.source}`);
  if(m.model) parts.push(`模型：${m.model}`);
  parts.push(`Prompt Tokens：${m.prompt_tokens || 0}`, `Completion Tokens：${m.completion_tokens || 0}`, `Total Tokens：${m.total_tokens || 0}`, `Estimated Cost：$${Number(m.estimated_cost || 0).toFixed(5)}`);
  if(m.duration !== undefined) parts.push(`耗时：${m.duration} ms`);
  if(m.db_log) parts.push(formatDbLog(m.db_log));
  return parts.join(' · ');
}
function formatDbLog(log){ if(!log) return '数据库记录：未返回'; return log.success ? `数据库记录：成功${log.job_id ? ` #${log.job_id}` : ''}` : `数据库记录：失败 ${log.message || ''}${log.detail ? ` | 错误：${log.detail}` : ''}`; }
function setBusy(id, text){ const btn=$(id); btn.disabled=true; btn.dataset.oldText=btn.textContent; btn.textContent=text; }
function resetButton(id, text){ const btn=$(id); btn.disabled=false; btn.textContent=text || btn.dataset.oldText || btn.textContent; }
function showMuted(title, body){ setResult('muted', title, body); }
function showSuccess(title, body){ setResult('success', title, body); }
function showError(body){ setResult('error', '需要处理', body); }
function setResult(type, title, body){ $('resultBox').className = `resultBox ${type}`; $('resultBox').innerHTML = `<strong>${escapeHtml(title)}</strong><span>${escapeHtml(body)}</span>`; }
function downloadBlob(blob, fileName){ const url=URL.createObjectURL(blob); const a=document.createElement('a'); a.href=url; a.download=fileName; document.body.appendChild(a); a.click(); a.remove(); setTimeout(()=>URL.revokeObjectURL(url), 1000); }
function makeFileName(topic, mode){ const name = clean(topic).replace(/[\\/:*?"<>|]+/g, '').slice(0, 36) || 'AI_PPT'; return `${name}_${mode}_${new Date().toISOString().slice(0,10)}.pptx`; }
function clean(value){ return String(value || '').replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F]/g, '').trim(); }
function escapeHtml(value){ return String(value || '').replace(/[&<>"']/g, (ch) => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[ch])); }
