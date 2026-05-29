component output="false" {
    public struct function plan(required string goal, numeric site_id=0, numeric zone_id=0, numeric user_id=1) output="false" {
        var rag = new services.RagService();
        var docs = rag.search(arguments.goal, 5);
        var context = rag.buildContext(docs);
        var telemetry = latestOperationalContext(arguments.site_id, arguments.zone_id);
        var plan = buildPlan(arguments.goal, context, telemetry);
        var createdWorkOrderId = createDraftWorkOrder(arguments.user_id, arguments.site_id, arguments.zone_id, plan);

        var taskQ = queryExecute(
            "INSERT INTO sc_agent_tasks(requested_by_user_id, site_id, zone_id, goal_text, agent_status, risk_level, plan_summary, rag_context, created_work_order_id) VALUES (?, ?, ?, ?, 'planned', ?, ?, ?, ?) RETURNING agent_task_id",
            [
                {value: arguments.user_id, cfsqltype:"cf_sql_bigint"},
                {value: arguments.site_id == 0 ? javacast("null", "") : arguments.site_id, cfsqltype:"cf_sql_bigint"},
                {value: arguments.zone_id == 0 ? javacast("null", "") : arguments.zone_id, cfsqltype:"cf_sql_bigint"},
                {value: arguments.goal, cfsqltype:"cf_sql_longvarchar"},
                {value: plan.risk_level, cfsqltype:"cf_sql_varchar"},
                {value: plan.summary, cfsqltype:"cf_sql_longvarchar"},
                {value: context, cfsqltype:"cf_sql_longvarchar"},
                {value: createdWorkOrderId == 0 ? javacast("null", "") : createdWorkOrderId, cfsqltype:"cf_sql_bigint"}
            ],
            {datasource:"demo_sc"}
        );
        var agentTaskId = taskQ.agent_task_id[1];

        var orderNum = 1;
        for (var step in plan.steps) {
            queryExecute(
                "INSERT INTO sc_agent_task_steps(agent_task_id, step_order, step_name, step_type, step_status, tool_name, input_payload, output_payload) VALUES (?, ?, ?, ?, ?, ?, CAST(? AS jsonb), CAST(? AS jsonb))",
                [
                    {value: agentTaskId, cfsqltype:"cf_sql_bigint"},
                    {value: orderNum, cfsqltype:"cf_sql_integer"},
                    {value: step.name, cfsqltype:"cf_sql_varchar"},
                    {value: step.type, cfsqltype:"cf_sql_varchar"},
                    {value: orderNum <= 3 ? "completed" : "pending", cfsqltype:"cf_sql_varchar"},
                    {value: step.tool, cfsqltype:"cf_sql_varchar"},
                    {value: serializeJSON(step.input), cfsqltype:"cf_sql_longvarchar"},
                    {value: serializeJSON({"demo_result":"planned", "created_work_order_id": createdWorkOrderId}), cfsqltype:"cf_sql_longvarchar"}
                ],
                {datasource:"demo_sc"}
            );
            orderNum++;
        }

        queryExecute(
            "INSERT INTO sc_audit_logs(user_id, entity_name, entity_pk, action_name, action_summary, request_payload) VALUES (?, 'sc_agent_tasks', ?, 'agent_plan_created', ?, CAST(? AS jsonb))",
            [
                {value: arguments.user_id, cfsqltype:"cf_sql_bigint"},
                {value: agentTaskId & "", cfsqltype:"cf_sql_varchar"},
                {value: "AI Agent plan generated with RAG context and workflow steps", cfsqltype:"cf_sql_varchar"},
                {value: serializeJSON({goal: arguments.goal, site_id: arguments.site_id, zone_id: arguments.zone_id, created_work_order_id: createdWorkOrderId}), cfsqltype:"cf_sql_longvarchar"}
            ],
            {datasource:"demo_sc"}
        );

        plan.agent_task_id = agentTaskId;
        plan.created_work_order_id = createdWorkOrderId;
        plan.rag_documents = docs;
        plan.telemetry_context = telemetry;
        return plan;
    }

    private struct function buildPlan(required string goal, required string context, required struct telemetry) output="false" {
        if (structKeyExists(application, "aiMockMode") && application.aiMockMode == "false" && len(application.openAiApiKey ?: "")) {
            try { return openAiPlan(arguments.goal, arguments.context, arguments.telemetry); }
            catch (any e) { var fallback = mockPlan(arguments.goal, arguments.context, arguments.telemetry); fallback.ai_mode = "local-fallback-after-openai-error"; fallback.openai_error = e.message; return fallback; }
        }
        return mockPlan(arguments.goal, arguments.context, arguments.telemetry);
    }

    private struct function mockPlan(required string goal, required string context, required struct telemetry) output="false" {
        var risk = "medium";
        if (arguments.telemetry.high_alert_count > 0 || findNoCase("smoke", arguments.goal) || findNoCase("fire", arguments.goal)) risk = "high";
        if (arguments.telemetry.critical_alert_count > 0 || findNoCase("oil", arguments.goal)) risk = "critical";
        return {
            "ai_mode": "local-agent-demo",
            "risk_level": risk,
            "summary": "RAG retrieved SOP and policy context, telemetry was checked against active alerts, risk was assessed, and a draft work order / notification workflow was prepared for human review.",
            "steps": [
                {"name":"Read latest device telemetry and active alerts", "type":"tool", "tool":"alerts.lookup", "input":{"open_alerts":arguments.telemetry.open_alert_count, "critical_alerts":arguments.telemetry.critical_alert_count}},
                {"name":"Retrieve SOP / policy evidence through RAG", "type":"rag", "tool":"knowledge.search", "input":{"query":arguments.goal, "context_preview":left(arguments.context, 300)}},
                {"name":"Assess operational risk and escalation path", "type":"reasoning", "tool":"risk.assess", "input":{"risk_level":risk}},
                {"name":"Create draft work order for operator approval", "type":"workflow", "tool":"work_orders.create", "input":{"priority":risk}},
                {"name":"Notify responsible operator", "type":"workflow", "tool":"notification.dispatch", "input":{"channel":"operator_console"}},
                {"name":"Write audit trail and monitor follow-up", "type":"audit", "tool":"audit_logs.create", "input":{"status":"planned"}}
            ]
        };
    }

    private struct function openAiPlan(required string goal, required string context, required struct telemetry) output="false" {
        var prompt = "You are an enterprise AI agent for smart city operations. Return JSON only with keys risk_level, summary, steps. Each step has name,type,tool,input. Goal: " & arguments.goal & chr(10) & "Telemetry: " & serializeJSON(arguments.telemetry) & chr(10) & "RAG context: " & arguments.context;
        var body = {"model": application.openAiModel, "messages": [{"role":"system", "content":"Return strict JSON only. No markdown."}, {"role":"user", "content": prompt}], "temperature": 0.2};
        var httpResult = "";
        cfhttp(url="https://api.openai.com/v1/chat/completions", method="post", result="httpResult", charset="utf-8", timeout=30) {
            cfhttpparam(type="header", name="Authorization", value="Bearer " & application.openAiApiKey);
            cfhttpparam(type="header", name="Content-Type", value="application/json");
            cfhttpparam(type="body", value=serializeJSON(body));
        }
        var response = deserializeJSON(httpResult.fileContent);
        var content = response.choices[1].message.content;
        var parsed = deserializeJSON(content);
        parsed.ai_mode = "openai:" & application.openAiModel;
        return parsed;
    }

    private struct function latestOperationalContext(numeric site_id=0, numeric zone_id=0) output="false" {
        var where = "WHERE a.alert_status <> 'resolved'";
        var params = [];
        if (arguments.site_id > 0) { where &= " AND a.site_id = ?"; arrayAppend(params, {value:arguments.site_id, cfsqltype:"cf_sql_bigint"}); }
        if (arguments.zone_id > 0) { where &= " AND a.zone_id = ?"; arrayAppend(params, {value:arguments.zone_id, cfsqltype:"cf_sql_bigint"}); }
        var q = queryExecute("SELECT COUNT(*) total, SUM(CASE WHEN alert_level='critical' THEN 1 ELSE 0 END) critical_total, SUM(CASE WHEN alert_level='high' THEN 1 ELSE 0 END) high_total FROM sc_alerts a " & where, params, {datasource:"demo_sc"});
        return {"open_alert_count": val(q.total[1]), "critical_alert_count": val(q.critical_total[1]), "high_alert_count": val(q.high_total[1])};
    }

    private numeric function createDraftWorkOrder(required numeric user_id, numeric site_id=0, numeric zone_id=0, required struct plan) output="false" {
        var alertQ = queryExecute("SELECT alert_id, site_id, zone_id, alert_title FROM sc_alerts WHERE alert_status <> 'resolved' ORDER BY CASE alert_level WHEN 'critical' THEN 1 WHEN 'high' THEN 2 ELSE 3 END, triggered_at DESC LIMIT 1", {}, {datasource:"demo_sc"});
        if (alertQ.recordCount == 0 && arguments.site_id == 0) return 0;
        var sid = arguments.site_id > 0 ? arguments.site_id : alertQ.site_id[1];
        var zid = arguments.zone_id > 0 ? arguments.zone_id : (alertQ.recordCount ? alertQ.zone_id[1] : javacast("null", ""));
        var aid = alertQ.recordCount ? alertQ.alert_id[1] : javacast("null", "");
        var title = "AI response plan: " & left(arguments.plan.summary, 80);
        var q = queryExecute(
            "INSERT INTO sc_work_orders(alert_id, site_id, zone_id, created_by_user_id, work_order_title, work_order_description, priority, work_order_status, due_at) VALUES (?, ?, ?, ?, ?, ?, ?, 'draft', CURRENT_TIMESTAMP + INTERVAL '4 hours') RETURNING work_order_id",
            [
                {value: aid, cfsqltype:"cf_sql_bigint"},
                {value: sid, cfsqltype:"cf_sql_bigint"},
                {value: zid, cfsqltype:"cf_sql_bigint"},
                {value: arguments.user_id, cfsqltype:"cf_sql_bigint"},
                {value: title, cfsqltype:"cf_sql_varchar"},
                {value: arguments.plan.summary, cfsqltype:"cf_sql_longvarchar"},
                {value: arguments.plan.risk_level, cfsqltype:"cf_sql_varchar"}
            ], {datasource:"demo_sc"}
        );
        return q.work_order_id[1];
    }
}
