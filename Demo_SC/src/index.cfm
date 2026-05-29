<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>SmartCity Agent Demo</title>
    <link rel="stylesheet" href="assets/css/app.css">
</head>
<body>
    <div class="layout">
        <aside class="sidebar">
            <div class="brand">OpsTwin AI</div>
            <a href="index.cfm">3D Operations</a>
            <a href="admin/crud.cfm?module=users">Users</a>
            <a href="admin/crud.cfm?module=roles">Roles</a>
            <a href="admin/crud.cfm?module=sites">Sites</a>
            <a href="admin/crud.cfm?module=zones">Zones</a>
            <a href="admin/crud.cfm?module=devices">Devices</a>
            <a href="admin/crud.cfm?module=sensor_readings">Sensor Readings</a>
            <a href="admin/crud.cfm?module=alerts">Alerts</a>
            <a href="admin/crud.cfm?module=work_orders">Work Orders</a>
            <a href="admin/crud.cfm?module=inspections">Inspections</a>
            <a href="admin/crud.cfm?module=maintenance_records">Maintenance</a>
            <a href="admin/crud.cfm?module=camera_events">Camera Events</a>
            <a href="admin/crud.cfm?module=meter_readings">Meter Readings</a>
            <a href="admin/crud.cfm?module=knowledge_documents">Knowledge Base</a>
            <a href="admin/crud.cfm?module=agent_tasks">Agent Tasks</a>
            <a href="admin/crud.cfm?module=agent_task_steps">Agent Steps</a>
            <a href="admin/crud.cfm?module=audit_logs">Audit Logs</a>
        </aside>
        <main class="main">
            <header class="hero">
                <div>
                    <h1>Enterprise AI Agent for Smart City Operations</h1>
                    <p>IoT telemetry + RAG + workflow orchestration + production auditability.</p>
                </div>
            </header>
            <section class="agent-console card">
                <div>
                    <h2>Ask the Operations Agent</h2>
                    <p class="muted">Use a natural-language operations goal. The agent will check telemetry, retrieve SOP/RAG evidence, assess risk, and prepare a human-reviewed work order.</p>
                    <div class="prompt-row">
                        <input id="agentGoal" value="Which sites have active high-risk monitoring issues today, and what response workflow should we start?">
                        <button id="runAgentBtn">Run AI Agent</button>
                    </div>
                    <div class="prompt-chips">
                        <button type="button" class="chip" data-prompt="Check today's unresolved smoke and oil-fume alerts and prepare an escalation plan.">High-risk alerts today</button>
                        <button type="button" class="chip" data-prompt="Find devices with abnormal telemetry and create a maintenance response plan.">Abnormal telemetry</button>
                        <button type="button" class="chip" data-prompt="Use SOP and policy evidence to explain the current operational risk and recommended next steps.">RAG risk explanation</button>
                    </div>
                </div>
            </section>
            <section class="grid">
                <div class="card"><h3>Open Alerts</h3><div id="alertCount" class="metric">--</div></div>
                <div class="card"><h3>Devices</h3><div id="deviceCount" class="metric">--</div></div>
                <div class="card"><h3>Work Orders</h3><div id="woCount" class="metric">--</div></div>
                <div class="card"><h3>AI Task</h3><div id="agentStatus" class="metric small">Ready</div></div>
            </section>
            <section class="screen-wrap">
                <div id="threeCanvas"></div>
                <div class="side-panel">
                    <h2>Live Alerts</h2>
                    <div id="alertList"></div>
                    <h2>Agent Plan</h2>
                    <div id="agentPlan" class="agent-plan-placeholder">Enter an operations goal and click “Run AI Agent”.</div>
                    <h2>Telemetry Snapshot</h2>
                    <div id="opsSnapshot"></div>
                </div>
            </section>
        </main>
    </div>
    <script src="https://unpkg.com/three@0.160.0/build/three.min.js"></script>
    <script src="assets/js/api.js"></script>
    <script src="assets/js/three-dashboard.js"></script>
    <script src="assets/js/app.js"></script>
</body>
</html>
