<!DOCTYPE html>
<html lang="en">
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"><title>RaceOps AI</title><link rel="stylesheet" href="assets/css/app.css"></head>
<body>
<div class="layout">
  <aside class="sidebar">
    <div class="brand">RaceOps AI</div>
    <a href="index.cfm">3D Operations</a>
    <a href="admin/crud.cfm?module=users">Users</a>
    <a href="admin/crud.cfm?module=roles">Roles</a>
    <a href="admin/crud.cfm?module=drivers">Drivers</a>
    <a href="admin/crud.cfm?module=race_events">Race Events</a>
    <a href="admin/crud.cfm?module=schedule_items">Schedule</a>
    <a href="admin/crud.cfm?module=wearable_readings">Wearables</a>
    <a href="admin/crud.cfm?module=fatigue_assessments">Fatigue</a>
    <a href="admin/crud.cfm?module=logistics_tasks">Logistics Tasks</a>
    <a href="admin/crud.cfm?module=meetings">Meetings</a>
    <a href="admin/crud.cfm?module=recovery_sessions">Recovery</a>
    <a href="admin/crud.cfm?module=knowledge_documents">Knowledge Base</a>
    <a href="admin/crud.cfm?module=agent_tasks">Agent Tasks</a>
    <a href="admin/crud.cfm?module=agent_task_steps">Agent Steps</a>
    <a href="admin/crud.cfm?module=audit_logs">Audit Logs</a>
  </aside>
  <main class="main">
    <header class="hero"><div><h1>RaceOps AI — Driver Operations Agent</h1><p>Driver recovery + schedule orchestration + RAG + human-reviewed logistics workflow.</p></div></header>
    <section class="card agent-console"><h2>Ask the DriverOps Agent</h2><p class="muted">Use natural language. The agent checks wearable data, schedule load, recovery SOP/RAG evidence, and prepares a human-reviewed task.</p><div class="prompt-row"><input id="agentGoal" value="今天车手是不是疲劳过高？需要调整哪些后勤安排？"><button onclick="runAgent()">Run AI Agent</button></div><div class="prompt-chips"><button class="chip" onclick="setAgentGoal('Which driver has the highest fatigue risk today?')">Highest fatigue risk</button><button class="chip" onclick="setAgentGoal('今天车手休息恢复怎么安排最好？')">Recovery plan</button><button class="chip" onclick="setAgentGoal('今天会议和媒体安排是否过载？')">Meeting overload</button></div></section>
    <section class="grid"><div class="card"><h3>Drivers</h3><div id="driverCount" class="metric">--</div></div><div class="card"><h3>Open Tasks</h3><div id="taskCount" class="metric">--</div></div><div class="card"><h3>High Fatigue</h3><div id="fatigueCount" class="metric">--</div></div><div class="card"><h3>AI Task</h3><div id="agentStatus" class="metric small">Ready</div></div></section>
    <section class="screen-wrap"><div id="threeCanvas"></div><div class="side-panel"><h2>DriverOps Board</h2><div id="riskList"></div><h2>Agent Plan</h2><div id="agentPlan" class="muted">Ask a question to generate a DriverOps workflow.</div><h2>Telemetry Snapshot</h2><div id="opsSnapshot"></div></div></section>
  </main>
</div>
<script src="assets/js/api.js"></script><script src="https://cdn.jsdelivr.net/npm/three@0.149.0/build/three.min.js"></script><script src="assets/js/three-dashboard.js"></script><script src="assets/js/app.js"></script>
</body></html>
