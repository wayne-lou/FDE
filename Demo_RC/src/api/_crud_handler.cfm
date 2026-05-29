<cfscript>
param name="url.action" default="list";
param name="url.limit" default="100";
param name="url.offset" default="0";
param name="url.id" default="0";

function sendJson(required any data, numeric statusCode=200) {
    cfcontent(type="application/json; charset=utf-8", reset=true);
    cfheader(statuscode=arguments.statusCode, statustext=(arguments.statusCode EQ 200 ? "OK" : "Error"));
    writeOutput(serializeJSON(arguments.data));
    abort;
}

function failJson(required string msg, numeric statusCode=500) {
    sendJson({"success":false,"message":arguments.msg}, arguments.statusCode);
}

function cfg(required string module) {
    var configs = {
        "roles":{"table":"rc_roles","pk":"role_id","columns":["role_code","role_name","role_description"]},
        "users":{"table":"rc_users","pk":"user_id","columns":["role_id","email","full_name","phone","user_status"]},
        "drivers":{"table":"rc_drivers","pk":"driver_id","columns":["driver_code","driver_name","team_name","primary_coach_user_id","timezone_home","driver_status"]},
        "race_events":{"table":"rc_race_events","pk":"race_event_id","columns":["event_code","event_name","circuit_name","city","country","timezone_name","start_date","end_date","event_status"]},
        "schedule_items":{"table":"rc_schedule_items","pk":"schedule_item_id","columns":["driver_id","race_event_id","item_type","item_title","item_location","start_at","end_at","priority","schedule_status","notes"]},
        "wearable_readings":{"table":"rc_wearable_readings","pk":"wearable_reading_id","columns":["driver_id","metric_name","metric_value","metric_unit","quality_status","captured_at","raw_payload"]},
        "fatigue_assessments":{"table":"rc_fatigue_assessments","pk":"fatigue_assessment_id","columns":["driver_id","race_event_id","fatigue_score","sleep_score","timezone_load","cognitive_load","risk_level","assessment_summary","created_at"]},
        "logistics_tasks":{"table":"rc_logistics_tasks","pk":"logistics_task_id","columns":["driver_id","race_event_id","assigned_to_user_id","task_type","task_title","task_description","priority","task_status","due_at","completed_at"]},
        "meetings":{"table":"rc_meetings","pk":"meeting_id","columns":["race_event_id","driver_id","meeting_type","meeting_title","meeting_status","scheduled_at","summary"]},
        "recovery_sessions":{"table":"rc_recovery_sessions","pk":"recovery_session_id","columns":["driver_id","race_event_id","coach_user_id","session_type","session_status","scheduled_at","duration_minutes","notes"]},
        "knowledge_documents":{"table":"rc_knowledge_documents","pk":"knowledge_document_id","columns":["document_type","document_title","document_source","document_content","chunk_text","embedding_text","embedding_json","document_status","created_by_user_id"]},
        "agent_tasks":{"table":"rc_agent_tasks","pk":"agent_task_id","columns":["requested_by_user_id","driver_id","race_event_id","goal_text","agent_status","risk_level","plan_summary","rag_context","created_logistics_task_id"]},
        "agent_task_steps":{"table":"rc_agent_task_steps","pk":"agent_task_step_id","columns":["agent_task_id","step_order","step_name","step_type","step_status","tool_name","input_payload","output_payload"]},
        "audit_logs":{"table":"rc_audit_logs","pk":"audit_log_id","columns":["user_id","entity_name","entity_pk","action_name","action_summary","ip_address","request_payload"]}
    };
    if (!structKeyExists(configs, arguments.module)) failJson("Unknown module: " & arguments.module, 400);
    return configs[arguments.module];
}

function queryToArray(required query q) {
    var arr = [];
    var cols = listToArray(arguments.q.columnList);
    for (var r=1; r <= arguments.q.recordCount; r++) {
        var row = {};
        for (var c in cols) row[lcase(c)] = arguments.q[c][r];
        arrayAppend(arr, row);
    }
    return arr;
}


function lookupLabels(required string module) {
    var m = arguments.module;
    if (m == "roles") return ["role_name","role_code"];
    if (m == "users") return ["full_name","email"];
    if (m == "drivers") return ["driver_name","driver_code"];
    if (m == "race_events") return ["event_name","event_code"];
    if (m == "schedule_items") return ["item_title","item_type"];
    if (m == "logistics_tasks") return ["task_title","priority"];
    if (m == "agent_tasks") return ["goal_text","agent_status"];
    return [];
}

function readBody() {
    var raw = toString(getHttpRequestData().content);
    if (!len(trim(raw))) return {};
    return deserializeJSON(raw);
}

function sqlType(required string col) {
    if (right(arguments.col,3) == "_id" || listFindNoCase("entity_pk,step_order", arguments.col)) return "cf_sql_bigint";
    if (findNoCase("latitude", arguments.col) || findNoCase("longitude", arguments.col) || findNoCase("value", arguments.col)) return "cf_sql_decimal";
    if (findNoCase("_at", arguments.col)) return "cf_sql_timestamp";
    if (findNoCase("payload", arguments.col) || findNoCase("content", arguments.col) || findNoCase("description", arguments.col) || findNoCase("summary", arguments.col) || findNoCase("context", arguments.col)) return "cf_sql_longvarchar";
    return "cf_sql_varchar";
}

function cleanValue(required any v) {
    if (isStruct(arguments.v) || isArray(arguments.v)) return serializeJSON(arguments.v);
    return arguments.v;
}

moduleName = request.moduleName;
actionName = lcase(url.action);
c = cfg(moduleName);
limitVal = min(max(val(url.limit),1),500);
offsetVal = max(val(url.offset),0);
idVal = val(url.id);
</cfscript>

<cftry>
    <cfif actionName EQ "lookup">
        <cfscript>
            labelCols = lookupLabels(moduleName);
            selectCols = [c.pk];
            for (lc in labelCols) arrayAppend(selectCols, lc);
        </cfscript>
        <cfquery name="qLookup" datasource="demo_rc">
            SELECT #arrayToList(selectCols)# FROM #c.table# ORDER BY #c.pk# DESC LIMIT #limitVal# OFFSET #offsetVal#
        </cfquery>
        <cfscript>sendJson({"success":true,"data":queryToArray(qLookup)});</cfscript>

    <cfelseif actionName EQ "list">
        <cfquery name="qList" datasource="demo_rc">
            SELECT * FROM #c.table# ORDER BY #c.pk# DESC LIMIT #limitVal# OFFSET #offsetVal#
        </cfquery>
        <cfscript>sendJson({"success":true,"data":queryToArray(qList)});</cfscript>

    <cfelseif actionName EQ "get">
        <cfquery name="qGet" datasource="demo_rc">
            SELECT * FROM #c.table# WHERE #c.pk# = <cfqueryparam value="#idVal#" cfsqltype="cf_sql_bigint">
        </cfquery>
        <cfscript>sendJson({"success":true,"data":queryToArray(qGet)});</cfscript>

    <cfelseif actionName EQ "create">
        <cfscript>
            body = readBody();
            cols = [];
            vals = [];
            types = [];
            for (col in c.columns) {
                if (structKeyExists(body, col) && len(trim(body[col] & ""))) {
                    arrayAppend(cols, col);
                    arrayAppend(vals, cleanValue(body[col]));
                    arrayAppend(types, sqlType(col));
                }
            }
            if (!arrayLen(cols)) failJson("No valid fields provided for create.", 400);
        </cfscript>
        <cfquery name="qCreate" datasource="demo_rc">
            INSERT INTO #c.table# (#arrayToList(cols)#) VALUES (
            <cfloop from="1" to="#arrayLen(cols)#" index="i">
                <cfif i GT 1>,</cfif><cfqueryparam value="#vals[i]#" cfsqltype="#types[i]#">
            </cfloop>
            ) RETURNING #c.pk#
        </cfquery>
        <cfscript>sendJson({"success":true,"id":qCreate[c.pk][1]});</cfscript>

    <cfelseif actionName EQ "update">
        <cfscript>
            body = readBody();
            cols = [];
            vals = [];
            types = [];
            for (col in c.columns) {
                if (structKeyExists(body, col)) {
                    arrayAppend(cols, col);
                    arrayAppend(vals, cleanValue(body[col]));
                    arrayAppend(types, sqlType(col));
                }
            }
            if (!arrayLen(cols)) failJson("No valid fields provided for update.", 400);
        </cfscript>
        <cfquery name="qUpdate" datasource="demo_rc">
            UPDATE #c.table# SET
            <cfloop from="1" to="#arrayLen(cols)#" index="i">
                <cfif i GT 1>,</cfif>#cols[i]# = <cfqueryparam value="#vals[i]#" cfsqltype="#types[i]#">
            </cfloop>
            WHERE #c.pk# = <cfqueryparam value="#idVal#" cfsqltype="cf_sql_bigint">
        </cfquery>
        <cfscript>sendJson({"success":true,"id":idVal});</cfscript>

    <cfelseif actionName EQ "delete">
        <cfquery name="qDelete" datasource="demo_rc">
            DELETE FROM #c.table# WHERE #c.pk# = <cfqueryparam value="#idVal#" cfsqltype="cf_sql_bigint">
        </cfquery>
        <cfscript>sendJson({"success":true,"id":idVal});</cfscript>

    <cfelse>
        <cfscript>failJson("Unsupported action: " & actionName, 400);</cfscript>
    </cfif>

    <cfcatch type="any">
        <cfscript>failJson(cfcatch.message & (len(cfcatch.detail) ? " - " & cfcatch.detail : ""), 500);</cfscript>
    </cfcatch>
</cftry>
