<cfscript>
function sendJson(required any data, numeric statusCode=200) {
    cfcontent(type="application/json; charset=utf-8", reset=true);
    cfheader(statuscode=arguments.statusCode, statustext=(arguments.statusCode EQ 200 ? "OK" : "Error"));
    writeOutput(serializeJSON(arguments.data));
    abort;
}
function failJson(required string msg, numeric statusCode=500) {
    sendJson({"success":false,"message":arguments.msg}, arguments.statusCode);
}
function readBody() {
    var raw = toString(getHttpRequestData().content);
    if (!len(trim(raw))) return {};
    return deserializeJSON(raw);
}
function qToArray(required query q) {
    var arr=[]; var cols=listToArray(arguments.q.columnList);
    for (var r=1; r<=arguments.q.recordCount; r++) {
        var row={}; for (var c in cols) row[lcase(c)] = arguments.q[c][r]; arrayAppend(arr,row);
    }
    return arr;
}
function hasAny(required string s, required array terms) {
    var lower = lcase(arguments.s);
    for (var t in arguments.terms) if (find(lcase(t), lower)) return true;
    return false;
}
function levelRank(required string level) {
    var v = lcase(arguments.level & "");
    if (v == "critical") return 4;
    if (v == "high") return 3;
    if (v == "medium") return 2;
    return 1;
}
</cfscript>
<cftry>
<cfscript>
body = readBody();
goal = structKeyExists(body,"goal") && len(trim(body.goal&"")) ? body.goal : "Investigate open high risk alerts and create an operational response plan";
userId = structKeyExists(body,"user_id") ? val(body.user_id) : 1;
siteId = structKeyExists(body,"site_id") ? val(body.site_id) : 0;
zoneId = structKeyExists(body,"zone_id") ? val(body.zone_id) : 0;

goalText = lcase(goal);
focus = "all";
focusLabel = "all active monitoring areas";
if (hasAny(goal, ["餐馆","餐厅","饭店","厨房","油烟","油污","oil","fume","restaurant","kitchen"])) { focus="oil_fume"; focusLabel="restaurant / oil-fume monitoring"; }
else if (hasAny(goal, ["烟感","烟雾","消防","smoke","fire"])) { focus="smoke"; focusLabel="smoke / fire-safety monitoring"; }
else if (hasAny(goal, ["温度","湿度","temperature","humidity","热"])) { focus="temperature"; focusLabel="temperature / humidity monitoring"; }
else if (hasAny(goal, ["摄像","视频","camera","restricted","人员"])) { focus="camera"; focusLabel="camera / restricted-area events"; }
</cfscript>

<cfquery name="qAlerts" datasource="demo_sc">
    SELECT a.alert_id, a.alert_code, a.alert_title, a.alert_level, a.alert_status,
           a.alert_description, a.triggered_at,
           d.device_id, d.device_code, d.device_name, d.device_type, d.device_status,
           s.site_id, s.site_name, z.zone_id, z.zone_name
    FROM sc_alerts a
    INNER JOIN sc_devices d ON a.device_id = d.device_id
    INNER JOIN sc_sites s ON a.site_id = s.site_id
    LEFT JOIN sc_zones z ON a.zone_id = z.zone_id
    WHERE a.alert_status <> 'resolved'
    <cfif siteId GT 0>AND a.site_id = <cfqueryparam value="#siteId#" cfsqltype="cf_sql_bigint"></cfif>
    <cfif zoneId GT 0>AND a.zone_id = <cfqueryparam value="#zoneId#" cfsqltype="cf_sql_bigint"></cfif>
    <cfif focus EQ "oil_fume">
        AND (d.device_type = 'oil_fume_monitor' OR a.alert_code ILIKE '%OIL%' OR a.alert_title ILIKE '%fume%')
    <cfelseif focus EQ "smoke">
        AND (d.device_type = 'smoke_detector' OR a.alert_code ILIKE '%SMOKE%' OR a.alert_title ILIKE '%Smoke%')
    <cfelseif focus EQ "temperature">
        AND (d.device_type = 'temperature_humidity' OR a.alert_code ILIKE '%TEMP%' OR a.alert_title ILIKE '%Temperature%')
    <cfelseif focus EQ "camera">
        AND d.device_type = 'camera'
    </cfif>
    ORDER BY CASE a.alert_level WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END, a.triggered_at DESC
</cfquery>

<cfif qAlerts.recordCount EQ 0>
    <cfquery name="qAlerts" datasource="demo_sc">
        SELECT a.alert_id, a.alert_code, a.alert_title, a.alert_level, a.alert_status,
               a.alert_description, a.triggered_at,
               d.device_id, d.device_code, d.device_name, d.device_type, d.device_status,
               s.site_id, s.site_name, z.zone_id, z.zone_name
        FROM sc_alerts a
        INNER JOIN sc_devices d ON a.device_id = d.device_id
        INNER JOIN sc_sites s ON a.site_id = s.site_id
        LEFT JOIN sc_zones z ON a.zone_id = z.zone_id
        WHERE a.alert_status <> 'resolved'
        ORDER BY CASE a.alert_level WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END, a.triggered_at DESC
    </cfquery>
</cfif>

<cfquery name="qReadings" datasource="demo_sc">
    SELECT d.device_code, d.device_name, d.device_type, r.metric_name, r.metric_value, r.metric_unit, r.quality_status, r.captured_at
    FROM sc_sensor_readings r
    INNER JOIN sc_devices d ON r.device_id = d.device_id
    WHERE r.captured_at >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
    <cfif focus EQ "oil_fume">
        AND d.device_type = 'oil_fume_monitor'
    <cfelseif focus EQ "smoke">
        AND d.device_type = 'smoke_detector'
    <cfelseif focus EQ "temperature">
        AND d.device_type = 'temperature_humidity'
    </cfif>
    ORDER BY CASE r.quality_status WHEN 'critical' THEN 1 WHEN 'warning' THEN 2 ELSE 3 END, r.captured_at DESC
    LIMIT 10
</cfquery>

<cfquery name="qDocs" datasource="demo_sc">
    SELECT knowledge_document_id, document_title, document_type, left(chunk_text, 500) AS chunk_text
    FROM sc_knowledge_documents
    WHERE document_status='active'
    <cfif focus EQ "oil_fume">
        AND (document_content ILIKE '%oil fume%' OR document_title ILIKE '%Oil%')
    <cfelseif focus EQ "smoke">
        AND (document_content ILIKE '%smoke%' OR document_title ILIKE '%Smoke%')
    <cfelseif focus EQ "temperature">
        AND (document_content ILIKE '%temperature%' OR document_content ILIKE '%sensor%' OR document_title ILIKE '%Device%')
    </cfif>
    ORDER BY knowledge_document_id DESC
    LIMIT 5
</cfquery>

<cfscript>
alerts = qToArray(qAlerts);
readings = qToArray(qReadings);
ragDocs = qToArray(qDocs);
openCount = arrayLen(alerts);
criticalCount = 0; highCount = 0;
for (a in alerts) {
    if (lcase(a.alert_level&"") == "critical") criticalCount++;
    if (lcase(a.alert_level&"") == "high") highCount++;
}
if (openCount == 0) {
    risk = "low";
    topAlert = {};
    answerTitle = "No active matching issue found";
    answer = "No unresolved alert matched this question. The agent still checked recent telemetry and knowledge documents, but no immediate work order was created.";
} else {
    topAlert = alerts[1];
    risk = topAlert.alert_level;
    answerTitle = topAlert.alert_title & " is the most urgent issue";
    answer = "For your question, the most relevant issue is " & topAlert.alert_title & " at " & topAlert.site_name & " / " & topAlert.zone_name & ". The alert level is " & ucase(topAlert.alert_level) & ", device " & topAlert.device_code & " is reporting " & topAlert.device_status & " status. The agent matched this against " & focusLabel & ", checked recent telemetry, retrieved SOP/policy evidence, and prepared a human-reviewed response workflow.";
}
recommendedAction = "Create or review a work order, notify the responsible operator, verify device readings on site, and keep the AI recommendation human-approved before closure.";
createdWorkOrderId = 0;
</cfscript>

<cfif openCount GT 0>
    <cfquery name="qWo" datasource="demo_sc">
        INSERT INTO sc_work_orders(alert_id, site_id, zone_id, created_by_user_id, work_order_title, work_order_description, priority, work_order_status, due_at)
        VALUES (
            <cfqueryparam value="#topAlert.alert_id#" cfsqltype="cf_sql_bigint">,
            <cfqueryparam value="#topAlert.site_id#" cfsqltype="cf_sql_bigint">,
            <cfqueryparam value="#topAlert.zone_id#" cfsqltype="cf_sql_bigint">,
            <cfqueryparam value="#userId#" cfsqltype="cf_sql_bigint">,
            <cfqueryparam value="#'AI response plan: ' & left(topAlert.alert_title, 80)#" cfsqltype="cf_sql_varchar">,
            <cfqueryparam value="#answer & ' Recommended action: ' & recommendedAction#" cfsqltype="cf_sql_longvarchar">,
            <cfqueryparam value="#risk#" cfsqltype="cf_sql_varchar">,
            'draft',
            CURRENT_TIMESTAMP + INTERVAL '4 hours'
        ) RETURNING work_order_id
    </cfquery>
    <cfscript>createdWorkOrderId = qWo.work_order_id[1];</cfscript>
</cfif>

<cfscript>
ragContext = serializeJSON(ragDocs);
steps = [
    {"name":"Understand operator question and identify target domain", "type":"reasoning", "tool":"intent.classify", "input":{"goal":goal,"focus":focus}},
    {"name":"Query matching active alerts and latest telemetry", "type":"tool", "tool":"alerts.telemetry.lookup", "input":{"matched_alerts":openCount,"readings_checked":arrayLen(readings)}},
    {"name":"Retrieve SOP / policy evidence through RAG", "type":"rag", "tool":"knowledge.search", "input":{"query":goal,"documents_found":arrayLen(ragDocs)}},
    {"name":"Assess risk level and operational impact", "type":"reasoning", "tool":"risk.assess", "input":{"risk_level":risk,"critical_alerts":criticalCount,"high_alerts":highCount}},
    {"name":"Prepare draft work order for human review", "type":"workflow", "tool":"work_orders.create", "input":{"priority":risk,"created_work_order_id":createdWorkOrderId}},
    {"name":"Write audit trail and monitor follow-up", "type":"audit", "tool":"audit_logs.create", "input":{"status":"planned"}}
];
</cfscript>

<cfquery name="qTask" datasource="demo_sc">
    INSERT INTO sc_agent_tasks(requested_by_user_id, site_id, zone_id, goal_text, agent_status, risk_level, plan_summary, rag_context, created_work_order_id)
    VALUES (
        <cfqueryparam value="#userId#" cfsqltype="cf_sql_bigint">,
        <cfif siteId GT 0><cfqueryparam value="#siteId#" cfsqltype="cf_sql_bigint"><cfelse>NULL</cfif>,
        <cfif zoneId GT 0><cfqueryparam value="#zoneId#" cfsqltype="cf_sql_bigint"><cfelse>NULL</cfif>,
        <cfqueryparam value="#goal#" cfsqltype="cf_sql_longvarchar">,
        'planned',
        <cfqueryparam value="#risk#" cfsqltype="cf_sql_varchar">,
        <cfqueryparam value="#answer#" cfsqltype="cf_sql_longvarchar">,
        <cfqueryparam value="#ragContext#" cfsqltype="cf_sql_longvarchar">,
        <cfif createdWorkOrderId GT 0><cfqueryparam value="#createdWorkOrderId#" cfsqltype="cf_sql_bigint"><cfelse>NULL</cfif>
    ) RETURNING agent_task_id
</cfquery>
<cfscript>agentTaskId = qTask.agent_task_id[1];</cfscript>

<cfloop from="1" to="#arrayLen(steps)#" index="i">
    <cfset stepStatus = "completed">
    <cfset stepOutput = serializeJSON({"result":"completed","risk_level":risk,"created_work_order_id":createdWorkOrderId})>
    <cfquery name="qStep" datasource="demo_sc">
        INSERT INTO sc_agent_task_steps(agent_task_id, step_order, step_name, step_type, step_status, tool_name, input_payload, output_payload)
        VALUES (
            <cfqueryparam value="#agentTaskId#" cfsqltype="cf_sql_bigint">,
            <cfqueryparam value="#i#" cfsqltype="cf_sql_integer">,
            <cfqueryparam value="#steps[i].name#" cfsqltype="cf_sql_varchar">,
            <cfqueryparam value="#steps[i].type#" cfsqltype="cf_sql_varchar">,
            <cfqueryparam value="#stepStatus#" cfsqltype="cf_sql_varchar">,
            <cfqueryparam value="#steps[i].tool#" cfsqltype="cf_sql_varchar">,
            CAST(<cfqueryparam value="#serializeJSON(steps[i].input)#" cfsqltype="cf_sql_longvarchar"> AS jsonb),
            CAST(<cfqueryparam value="#stepOutput#" cfsqltype="cf_sql_longvarchar"> AS jsonb)
        )
    </cfquery>
</cfloop>

<cfquery name="qAudit" datasource="demo_sc">
    INSERT INTO sc_audit_logs(user_id, entity_name, entity_pk, action_name, action_summary, request_payload)
    VALUES (
        <cfqueryparam value="#userId#" cfsqltype="cf_sql_bigint">,
        'sc_agent_tasks',
        <cfqueryparam value="#agentTaskId#" cfsqltype="cf_sql_varchar">,
        'agent_plan_created',
        'AI Agent plan generated with question-specific analysis, RAG evidence and workflow steps',
        CAST(<cfqueryparam value="#serializeJSON(body)#" cfsqltype="cf_sql_longvarchar"> AS jsonb)
    )
</cfquery>

<cfscript>
result = {
    "ai_mode":"local-agent-demo",
    "llm_status":"local deterministic agent; OpenAI can be enabled later in ai/OpenAIClient.cfc",
    "goal": goal,
    "focus": focus,
    "agent_task_id": agentTaskId,
    "created_work_order_id": createdWorkOrderId,
    "risk_level": risk,
    "answer_title": answerTitle,
    "answer": answer,
    "recommended_action": recommendedAction,
    "matched_alerts": alerts,
    "recent_readings": readings,
    "steps": steps,
    "rag_documents": ragDocs,
    "telemetry_context": {"matched_alert_count":openCount,"critical_alert_count":criticalCount,"high_alert_count":highCount,"readings_checked":arrayLen(readings)}
};
sendJson({"success":true,"data":result});
</cfscript>
<cfcatch type="any">
    <cfscript>failJson(cfcatch.message & (len(cfcatch.detail) ? " - " & cfcatch.detail : ""), 500);</cfscript>
</cfcatch>
</cftry>
