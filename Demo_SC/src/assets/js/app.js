function safeText(id, value) {
  const el = document.getElementById(id);
  if (el) el.textContent = value;
}

function levelClass(level) {
  const v = String(level || '').toLowerCase();
  if (v === 'critical') return 'critical';
  if (v === 'high') return 'high';
  if (v === 'medium') return 'medium';
  return 'low';
}

function sumBy(rows, field) {
  return (rows || []).reduce((sum, row) => sum + Number(row[field] || 0), 0);
}

async function loadDashboard() {
  const json = await apiGet('dashboard.cfm');
  const data = json.data || {};
  const openAlerts = data.open_alerts || [];
  const deviceTotal = sumBy(data.devices, 'total');
  const woTotal = sumBy(data.work_orders, 'total');
  safeText('alertCount', openAlerts.length);
  safeText('deviceCount', deviceTotal);
  safeText('woCount', woTotal);

  const alertList = document.getElementById('alertList');
  if (alertList) {
    alertList.innerHTML = openAlerts.length ? openAlerts.map(a => `
      <div class="alert-item">
        <div><span class="alert-level ${levelClass(a.alert_level)}">${escapeHtml(a.alert_level || '')}</span> ${escapeHtml(a.alert_title || '')}</div>
        <small>${escapeHtml(a.site_name || '')} · ${escapeHtml(a.zone_name || '')} · ${escapeHtml(a.device_code || '')} · ${escapeHtml(a.alert_status || '')}</small>
      </div>
    `).join('') : '<div class="muted">No active alerts.</div>';
  }

  renderOpsSnapshot(data);
  if (window.renderDeviceScene) window.renderDeviceScene(openAlerts, data.recent_readings || []);
}

function renderOpsSnapshot(data) {
  const target = document.getElementById('opsSnapshot');
  if (!target) return;
  const readings = data.recent_readings || [];
  target.innerHTML = readings.slice(0, 8).map(r => `
    <div class="snapshot-row">
      <span>${escapeHtml(r.device_code || '')}</span>
      <b>${escapeHtml(r.metric_name || '')}: ${escapeHtml(r.metric_value || '')}${escapeHtml(r.metric_unit || '')}</b>
      <small>${escapeHtml(r.quality_status || '')}</small>
    </div>
  `).join('') || '<div class="muted">No telemetry rows.</div>';
}

function getAgentGoal() {
  const el = document.getElementById('agentGoal');
  return (el && el.value.trim()) ? el.value.trim() : 'Investigate open high risk alerts and create an operational response plan';
}

async function runAgent() {
  const goal = getAgentGoal();
  safeText('agentStatus', 'Planning...');
  const planBox = document.getElementById('agentPlan');
  if (planBox) planBox.innerHTML = `
    <div class="agent-answer">
      <h3>Agent is working...</h3>
      <ul>
        <li>Reading active alerts and latest telemetry.</li>
        <li>Retrieving SOP / policy evidence through RAG.</li>
        <li>Assessing risk and preparing a workflow for human review.</li>
      </ul>
    </div>`;

  const result = await apiPost('agent_plan.cfm', { goal, site_id: 1, zone_id: 0, user_id: 1 });
  const data = result.data || {};
  safeText('agentStatus', 'Plan Created #' + data.agent_task_id);
  renderAgentPlan(data, goal);
  loadDashboard().catch(console.error);
}

function renderAgentPlan(data, goal) {
  const el = document.getElementById('agentPlan');
  if (!el) return;
  const steps = data.steps || [];
  const docs = data.rag_documents || [];
  const alerts = data.matched_alerts || [];
  const readings = data.recent_readings || [];
  const t = data.telemetry_context || {};
  el.innerHTML = `
    <div class="agent-summary">
      <div class="badge">${escapeHtml(data.ai_mode || 'local-agent')}</div>
      <div class="badge ${levelClass(data.risk_level)}">Risk: ${escapeHtml(data.risk_level || 'unknown')}</div>
      <div class="badge">Focus: ${escapeHtml(data.focus || 'all')}</div>
      ${data.created_work_order_id ? `<div class="badge">Work Order #${data.created_work_order_id}</div>` : ''}
      <p><b>Question:</b> ${escapeHtml(goal || '')}</p>
    </div>

    <div class="agent-answer strong-answer">
      <h3>${escapeHtml(data.answer_title || 'AI Agent Analysis')}</h3>
      <p>${escapeHtml(data.answer || '')}</p>
      <p><b>Recommended next step:</b> ${escapeHtml(data.recommended_action || '')}</p>
    </div>

    <h3>Matched Alerts</h3>
    <div class="alert-analysis-list">
      ${alerts.length ? alerts.map(a => `
        <div class="analysis-alert-card ${levelClass(a.alert_level)}">
          <div><span class="alert-level ${levelClass(a.alert_level)}">${escapeHtml(a.alert_level || '')}</span> <b>${escapeHtml(a.alert_title || '')}</b></div>
          <small>${escapeHtml(a.site_name || '')} · ${escapeHtml(a.zone_name || '')} · ${escapeHtml(a.device_code || '')} · ${escapeHtml(a.device_type || '')}</small>
          <p>${escapeHtml(a.alert_description || '')}</p>
        </div>`).join('') : '<div class="muted">No unresolved alert matched this question.</div>'}
    </div>

    <h3>Telemetry Checked</h3>
    <div class="telemetry-grid">
      ${readings.length ? readings.map(r => `
        <div class="telemetry-card">
          <b>${escapeHtml(r.device_code || '')}</b>
          <span>${escapeHtml(r.metric_name || '')}: ${escapeHtml(r.metric_value || '')}${escapeHtml(r.metric_unit || '')}</span>
          <small>${escapeHtml(r.quality_status || '')} · ${escapeHtml(r.captured_at || '')}</small>
        </div>`).join('') : '<div class="muted">No recent telemetry rows matched this focus.</div>'}
    </div>

    <div class="agent-answer">
      <h3>Execution Summary</h3>
      <ul>
        <li>Matched alerts: <b>${escapeHtml(t.matched_alert_count ?? '-')}</b></li>
        <li>Critical alerts: <b>${escapeHtml(t.critical_alert_count ?? '-')}</b>; High alerts: <b>${escapeHtml(t.high_alert_count ?? '-')}</b></li>
        <li>Telemetry rows checked: <b>${escapeHtml(t.readings_checked ?? '-')}</b></li>
      </ul>
    </div>

    <h3>Agent Workflow</h3>
    <div class="timeline">
      ${steps.map((s, i) => `
        <div class="timeline-step">
          <div class="step-num">${i + 1}</div>
          <div>
            <b>${escapeHtml(s.name || '')}</b>
            <small>${escapeHtml(s.type || '')} · ${escapeHtml(s.tool || '')}</small>
          </div>
        </div>`).join('')}
    </div>
    <h3>RAG Evidence</h3>
    <div class="evidence-grid">
      ${docs.length ? docs.map(d => `
        <div class="rag-doc">
          <b>${escapeHtml(d.document_title || '')}</b>
          <small>${escapeHtml(d.document_type || '')}</small>
          <p>${escapeHtml(d.chunk_text || '')}</p>
        </div>`).join('') : '<div class="muted">No matching knowledge documents.</div>'}
    </div>
  `;
}

function escapeHtml(str) {
  return String(str ?? '').replace(/[&<>'"]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[c]));
}

document.querySelectorAll('.chip').forEach(btn => {
  btn.addEventListener('click', () => {
    const input = document.getElementById('agentGoal');
    if (input) input.value = btn.getAttribute('data-prompt') || '';
  });
});

document.getElementById('runAgentBtn')?.addEventListener('click', () => runAgent().catch(err => {
  safeText('agentStatus', 'Error');
  const box = document.getElementById('agentPlan');
  if (box) box.innerHTML = `<div class="error-box">${escapeHtml(err.message)}</div>`;
}));

// Initialize 3D immediately so the page is not blank even if API fails.
if (window.renderDeviceScene) window.renderDeviceScene([], []);
loadDashboard().catch(err => {
  console.error(err);
  safeText('alertCount', 'ERR');
  const box = document.getElementById('alertList');
  if (box) box.innerHTML = `<div class="error-box">Dashboard API error: ${escapeHtml(err.message)}</div>`;
});
