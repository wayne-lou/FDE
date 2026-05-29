const MODULE_CONFIG = {
  wearable_readings: {hide: ['raw_payload'], textarea: ['raw_payload']},
  knowledge_documents: {hide: ['document_content','embedding_text','embedding_json'], textarea: ['document_content','chunk_text','embedding_text','embedding_json'], truncate: ['chunk_text','document_title','document_source']},
  agent_tasks: {hide: ['rag_context'], textarea: ['goal_text','plan_summary','rag_context']},
  agent_task_steps: {hide: ['input_payload','output_payload'], textarea: ['input_payload','output_payload']},
  audit_logs: {hide: ['request_payload'], textarea: ['action_summary','request_payload']},
  schedule_items: {textarea:['notes']},
  meetings: {textarea:['summary']},
  logistics_tasks: {textarea:['task_description']},
  recovery_sessions: {textarea:['notes']},
  fatigue_assessments: {textarea:['assessment_summary']}
};

const LOOKUP_CONFIG = {
  role_id: {module:'roles', value:'role_id', label:['role_name','role_code']},
  user_id: {module:'users', value:'user_id', label:['full_name','email']},
  primary_coach_user_id: {module:'users', value:'user_id', label:['full_name','email']},
  assigned_to_user_id: {module:'users', value:'user_id', label:['full_name','email']},
  requested_by_user_id: {module:'users', value:'user_id', label:['full_name','email']},
  coach_user_id: {module:'users', value:'user_id', label:['full_name','email']},
  created_by_user_id: {module:'users', value:'user_id', label:['full_name','email']},
  driver_id: {module:'drivers', value:'driver_id', label:['driver_name','driver_code']},
  race_event_id: {module:'race_events', value:'race_event_id', label:['event_name','event_code']},
  created_logistics_task_id: {module:'logistics_tasks', value:'logistics_task_id', label:['task_title','priority']},
  logistics_task_id: {module:'logistics_tasks', value:'logistics_task_id', label:['task_title','priority']},
  agent_task_id: {module:'agent_tasks', value:'agent_task_id', label:['goal_text','agent_status']}
};

const ENUM_CONFIG = {
  user_status: ['active','inactive','suspended'],
  driver_status: ['active','resting','injured','inactive'],
  event_status: ['planned','active','completed','cancelled'],
  item_type: ['flight','hotel','media','briefing','simulator','track_walk','gym','physio','meal','sleep','race_session','recovery'],
  priority: ['low','medium','high','critical'],
  schedule_status: ['planned','confirmed','changed','completed','cancelled'],
  quality_status: ['good','warning','bad','unknown'],
  risk_level: ['low','medium','high','critical'],
  task_type: ['transport','hotel','meal','media','recovery','briefing','equipment','health_check','schedule_change'],
  task_status: ['draft','open','assigned','in_progress','completed','cancelled'],
  meeting_type: ['engineering','strategy','media','medical','performance','logistics'],
  meeting_status: ['scheduled','completed','cancelled'],
  session_type: ['physio','nap','hydration','cooldown','massage','sleep_block','mental_reset'],
  session_status: ['scheduled','completed','cancelled'],
  document_status: ['active','inactive','archived'],
  agent_status: ['planned','running','completed','failed','cancelled'],
  step_status: ['pending','running','completed','failed','skipped']
};

let CURRENT_ROWS = [];
let FORM_KEYS = [];
let LOOKUPS = {};

async function loadLookups() {
  const modules = [...new Set(Object.values(LOOKUP_CONFIG).map(x => x.module))];
  const results = await Promise.allSettled(
    modules.map(m => apiGet(`${m}.cfm?action=lookup&limit=500`).then(j => [m, j.data || []]))
  );
  results.forEach(r => { if (r.status === 'fulfilled') LOOKUPS[r.value[0]] = r.value[1]; });
}

async function loadRows() {
  showToast('Loading...', 'muted');
  if (!Object.keys(LOOKUPS).length) await loadLookups();
  const json = await apiGet(`${window.SC_MODULE}.cfm?action=list&limit=100`);
  CURRENT_ROWS = json.data || [];
  renderTable(CURRENT_ROWS);
  buildFormFromRows(CURRENT_ROWS);
  showToast(`Loaded ${CURRENT_ROWS.length} rows`, 'ok');
}

function moduleConfig() { return MODULE_CONFIG[window.SC_MODULE] || {}; }
function hiddenColumns() { return new Set([...(moduleConfig().hide || [])]); }

function renderTable(rows) {
  const table = document.getElementById('dataTable');
  if (!rows.length) { table.innerHTML = '<tr><td>No records returned. Check seed data or API error below.</td></tr>'; return; }
  const hide = hiddenColumns();
  const keys = Object.keys(rows[0]).filter(k => !hide.has(k));
  table.innerHTML = `<thead><tr>${keys.map(k => `<th>${escapeHtml(k)}</th>`).join('')}<th>Action</th></tr></thead>` +
    `<tbody>${rows.map((r, idx) => `<tr>${keys.map(k => `<td title="${escapeAttr(formatFull(r[k]))}">${formatVal(k, r[k])}</td>`).join('')}<td><button class="small-btn" onclick="selectRow(${idx})">Edit</button></td></tr>`).join('')}</tbody>`;
}

function buildFormFromRows(rows) {
  const box = document.getElementById('formFields');
  const hide = hiddenColumns();
  document.getElementById('recordId').value = '';
  setSelectedText('No row selected. Click Edit in the list to update or delete.');
  if (!rows.length) { box.innerHTML = '<p class="muted">No sample row available. Use Advanced JSON Payload.</p>'; return; }
  const pk = primaryKeyName(rows[0]);
  FORM_KEYS = Object.keys(rows[0]).filter(k => k !== pk && k !== 'created_at' && k !== 'updated_at' && !hide.has(k));
  box.innerHTML = FORM_KEYS.map(k => fieldHtml(k, '')).join('');
  syncJsonFromForm();
}

function fieldHtml(k, v) {
  const cfg = moduleConfig();
  const textarea = new Set(cfg.textarea || []);
  const safeK = escapeAttr(k), safeV = escapeAttr(v ?? '');
  if (LOOKUP_CONFIG[k]) return selectHtml(k, v);
  if (ENUM_CONFIG[k]) return enumSelectHtml(k, v);
  if (textarea.has(k) || String(v ?? '').length > 100) {
    return `<label>${safeK}</label><textarea data-field="${safeK}" rows="4" oninput="syncJsonFromForm()">${escapeHtml(v ?? '')}</textarea>`;
  }
  return `<label>${safeK}</label><input data-field="${safeK}" value="${safeV}" oninput="syncJsonFromForm()">`;
}

function enumSelectHtml(k, v) {
  const options = ['<option value="">-- select --</option>'].concat((ENUM_CONFIG[k] || []).map(opt =>
    `<option value="${escapeAttr(opt)}" ${String(opt) === String(v ?? '') ? 'selected' : ''}>${escapeHtml(opt)}</option>`
  )).join('');
  return `<label>${escapeHtml(k)}</label><select data-field="${escapeAttr(k)}" onchange="syncJsonFromForm()">${options}</select>`;
}

function selectHtml(k, v) {
  const conf = LOOKUP_CONFIG[k];
  const rows = LOOKUPS[conf.module] || [];
  const options = ['<option value="">-- select --</option>'].concat(rows.map(r => {
    const val = r[conf.value];
    const label = conf.label.map(x => r[x]).filter(Boolean).join(' · ') || `${conf.module} #${val}`;
    return `<option value="${escapeAttr(val)}" ${String(val) === String(v ?? '') ? 'selected' : ''}>${escapeHtml(label)} (#${escapeHtml(val)})</option>`;
  })).join('');
  return `<label>${escapeHtml(k.replace(/_id$/, ''))}</label><select data-field="${escapeAttr(k)}" onchange="syncJsonFromForm()">${options}</select>`;
}

function fillForm(row) {
  const box = document.getElementById('formFields');
  box.innerHTML = FORM_KEYS.map(k => fieldHtml(k, row[k] ?? '')).join('');
  syncJsonFromForm();
}

function syncJsonFromForm() {
  const data = {};
  document.querySelectorAll('[data-field]').forEach(el => {
    const key = el.getAttribute('data-field');
    let val = el.value;
    if (val === '') return;
    if (key.endsWith('_id') && !isNaN(Number(val))) val = Number(val);
    else if ((key.includes('latitude') || key.includes('longitude') || key.includes('value')) && !isNaN(Number(val))) val = Number(val);
    data[key] = val;
  });
  document.getElementById('jsonPayload').value = JSON.stringify(data, null, 2);
}

function formatFull(v) { return v === null || v === undefined ? '' : (typeof v === 'object' ? JSON.stringify(v) : String(v)); }
function formatVal(key, v) {
  if (v === null || v === undefined) return '';
  let s = typeof v === 'object' ? JSON.stringify(v) : String(v);
  const isLong = s.length > 90;
  if (isLong) s = s.slice(0, 90) + '…';
  return `<span class="cell-text ${isLong ? 'truncated' : ''}">${escapeHtml(s)}</span>`;
}
function primaryKeyName(row) { return Object.keys(row).find(k => k.endsWith('_id')) || 'id'; }

function selectRow(idx) {
  const row = CURRENT_ROWS[idx];
  const pk = primaryKeyName(row);
  document.getElementById('recordId').value = row[pk];
  setSelectedText(`Selected ${pk}=${row[pk]}`);
  fillForm(row);
  showToast(`Selected ${pk}=${row[pk]}. Edit fields then Update, or Delete.`, 'ok');
}

function setSelectedText(text) { const el = document.getElementById('selectedRecord'); if (el) el.textContent = text; }

function payload() {
  syncJsonFromForm();
  try { return JSON.parse(document.getElementById('jsonPayload').value || '{}'); }
  catch (e) { alert('JSON payload is invalid: ' + e.message); throw e; }
}

async function createRow() {
  const result = await apiPost(`${window.SC_MODULE}.cfm?action=create`, payload());
  showResult(`Created successfully. New ID: ${result.id || ''}`);
  await loadRows();
}
async function updateRow() {
  const id = document.getElementById('recordId').value;
  if (!id) return alert('Please select a row from the list first.');
  const result = await apiPost(`${window.SC_MODULE}.cfm?action=update&id=${encodeURIComponent(id)}`, payload());
  showResult(`Updated successfully. ID: ${result.id || id}`);
  await loadRows();
}
async function deleteRow() {
  const id = document.getElementById('recordId').value;
  if (!id) return alert('Please select a row from the list first.');
  if (!confirm('Delete selected record #' + id + '?')) return;
  const result = await apiPost(`${window.SC_MODULE}.cfm?action=delete&id=${encodeURIComponent(id)}`, {});
  showResult(`Deleted successfully. ID: ${result.id || id}`);
  await loadRows();
}

function showResult(message) {
  const box = document.getElementById('crudResult');
  box.className = 'result-box success';
  box.innerHTML = `<b>${escapeHtml(message)}</b>`;
}
function showToast(message, type) {
  const box = document.getElementById('crudResult');
  if (!box) return;
  box.className = 'result-box ' + (type || '');
  box.innerHTML = escapeHtml(message);
}
function escapeHtml(str) { return String(str ?? '').replace(/[&<>'"]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[c])); }
function escapeAttr(str) { return escapeHtml(str).replace(/\n/g, ' '); }

loadRows().catch(err => {
  const box = document.getElementById('crudResult');
  box.className = 'result-box error';
  box.textContent = err.message;
});
