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
        "roles": {"table":"sc_roles", "pk":"role_id", "columns":["role_code","role_name","role_description"]},
        "users": {"table":"sc_users", "pk":"user_id", "columns":["role_id","email","full_name","phone","user_status"]},
        "sites": {"table":"sc_sites", "pk":"site_id", "columns":["site_code","site_name","site_type","address","city","province","latitude","longitude","site_status"]},
        "zones": {"table":"sc_zones", "pk":"zone_id", "columns":["site_id","zone_code","zone_name","floor_label","risk_level","zone_status"]},
        "devices": {"table":"sc_devices", "pk":"device_id", "columns":["site_id","zone_id","device_code","device_name","device_type","vendor_name","install_location","latitude","longitude","device_status","last_seen_at"]},
        "sensor_readings": {"table":"sc_sensor_readings", "pk":"reading_id", "columns":["device_id","metric_name","metric_value","metric_unit","quality_status","captured_at","raw_payload"]},
        "alerts": {"table":"sc_alerts", "pk":"alert_id", "columns":["device_id","site_id","zone_id","alert_code","alert_title","alert_level","alert_status","alert_description","triggered_at","resolved_at","assigned_user_id"]},
        "work_orders": {"table":"sc_work_orders", "pk":"work_order_id", "columns":["alert_id","site_id","zone_id","created_by_user_id","assigned_to_user_id","work_order_title","work_order_description","priority","work_order_status","due_at","completed_at"]},
        "inspections": {"table":"sc_inspections", "pk":"inspection_id", "columns":["site_id","zone_id","inspector_user_id","inspection_type","inspection_status","scheduled_at","completed_at","result_summary"]},
        "maintenance_records": {"table":"sc_maintenance_records", "pk":"maintenance_id", "columns":["device_id","work_order_id","technician_user_id","maintenance_type","maintenance_status","maintenance_notes","started_at","completed_at"]},
        "camera_events": {"table":"sc_camera_events", "pk":"camera_event_id", "columns":["device_id","site_id","zone_id","event_type","event_level","event_summary","snapshot_url","detected_at","raw_payload"]},
        "meter_readings": {"table":"sc_meter_readings", "pk":"meter_reading_id", "columns":["device_id","meter_type","reading_value","reading_unit","reading_period","captured_at","raw_payload"]},
        "knowledge_documents": {"table":"sc_knowledge_documents", "pk":"knowledge_document_id", "columns":["document_type","document_title","document_source","document_content","chunk_text","embedding_text","embedding_json","document_status","created_by_user_id"]},
        "agent_tasks": {"table":"sc_agent_tasks", "pk":"agent_task_id", "columns":["requested_by_user_id","site_id","zone_id","goal_text","agent_status","risk_level","plan_summary","rag_context","created_work_order_id"]},
        "agent_task_steps": {"table":"sc_agent_task_steps", "pk":"agent_task_step_id", "columns":["agent_task_id","step_order","step_name","step_type","step_status","tool_name","input_payload","output_payload"]},
        "audit_logs": {"table":"sc_audit_logs", "pk":"audit_log_id", "columns":["user_id","entity_name","entity_pk","action_name","action_summary","ip_address","request_payload"]}
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
    if (m == "sites") return ["site_name","site_code"];
    if (m == "zones") return ["zone_name","zone_code"];
    if (m == "devices") return ["device_name","device_code"];
    if (m == "alerts") return ["alert_title","alert_code"];
    if (m == "work_orders") return ["work_order_title","priority"];
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
        <cfquery name="qLookup" datasource="demo_sc">
            SELECT #arrayToList(selectCols)# FROM #c.table# ORDER BY #c.pk# DESC LIMIT #limitVal# OFFSET #offsetVal#
        </cfquery>
        <cfscript>sendJson({"success":true,"data":queryToArray(qLookup)});</cfscript>

    <cfelseif actionName EQ "list">
        <cfquery name="qList" datasource="demo_sc">
            SELECT * FROM #c.table# ORDER BY #c.pk# DESC LIMIT #limitVal# OFFSET #offsetVal#
        </cfquery>
        <cfscript>sendJson({"success":true,"data":queryToArray(qList)});</cfscript>

    <cfelseif actionName EQ "get">
        <cfquery name="qGet" datasource="demo_sc">
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
        <cfquery name="qCreate" datasource="demo_sc">
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
        <cfquery name="qUpdate" datasource="demo_sc">
            UPDATE #c.table# SET
            <cfloop from="1" to="#arrayLen(cols)#" index="i">
                <cfif i GT 1>,</cfif>#cols[i]# = <cfqueryparam value="#vals[i]#" cfsqltype="#types[i]#">
            </cfloop>
            WHERE #c.pk# = <cfqueryparam value="#idVal#" cfsqltype="cf_sql_bigint">
        </cfquery>
        <cfscript>sendJson({"success":true,"id":idVal});</cfscript>

    <cfelseif actionName EQ "delete">
        <cfquery name="qDelete" datasource="demo_sc">
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
