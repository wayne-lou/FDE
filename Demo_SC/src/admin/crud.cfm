<cfparam name="url.module" default="devices">
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CRUD - <cfoutput>#encodeForHtml(url.module)#</cfoutput></title>
    <link rel="stylesheet" href="../assets/css/app.css">
</head>
<body>
<div class="layout">
    <aside class="sidebar">
            <div class="brand">OpsTwin AI</div>
            <a href="../index.cfm">3D Operations</a>
            <a href="crud.cfm?module=users">Users</a>
            <a href="crud.cfm?module=roles">Roles</a>
            <a href="crud.cfm?module=sites">Sites</a>
            <a href="crud.cfm?module=zones">Zones</a>
            <a href="crud.cfm?module=devices">Devices</a>
            <a href="crud.cfm?module=sensor_readings">Sensor Readings</a>
            <a href="crud.cfm?module=alerts">Alerts</a>
            <a href="crud.cfm?module=work_orders">Work Orders</a>
            <a href="crud.cfm?module=inspections">Inspections</a>
            <a href="crud.cfm?module=maintenance_records">Maintenance</a>
            <a href="crud.cfm?module=camera_events">Camera Events</a>
            <a href="crud.cfm?module=meter_readings">Meter Readings</a>
            <a href="crud.cfm?module=knowledge_documents">Knowledge Base</a>
            <a href="crud.cfm?module=agent_tasks">Agent Tasks</a>
            <a href="crud.cfm?module=agent_task_steps">Agent Steps</a>
            <a href="crud.cfm?module=audit_logs">Audit Logs</a>
        </aside>
    <main class="main">
        <header class="hero compact">
            <div>
                <h1>Module: <cfoutput>#encodeForHtml(url.module)#</cfoutput></h1>
                <p>CRUD console with list-safe fields, row edit, success status, and long-text truncation.</p>
            </div>
            <button onclick="loadRows()">Refresh</button>
        </header>
        <section class="crud-grid">
            <div class="card wide">
                <h2>Rows</h2>
                <div class="table-wrap"><table id="dataTable"></table></div>
            </div>
            <div class="card">
                <h2>Create / Update</h2>
                <input type="hidden" id="recordId">
                <div id="selectedRecord" class="selected-record muted">No row selected. Click Edit in the list to update or delete.</div>
                <div id="formFields" class="form-fields"></div>
                <details class="advanced-json"><summary>Advanced JSON Payload</summary><textarea id="jsonPayload" rows="8">{}</textarea></details>
                <div class="button-row">
                    <button onclick="createRow()">Create</button>
                    <button onclick="updateRow()">Update</button>
                    <button class="danger" onclick="deleteRow()">Delete</button>
                </div>
                <div id="crudResult" class="result-box muted">Ready.</div>
            </div>
        </section>
    </main>
</div>
<script>
    window.SC_MODULE = "<cfoutput>#encodeForJavaScript(url.module)#</cfoutput>";
</script>
<script src="../assets/js/api.js"></script>
<script src="../assets/js/crud.js"></script>
</body>
</html>
