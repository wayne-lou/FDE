component output="false" {
    public struct function config(required string module) output="false" {
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
        if (!structKeyExists(configs, arguments.module)) throw(message="Unknown module: " & arguments.module);
        return configs[arguments.module];
    }

    public query function list(required string module, numeric limit=100, numeric offset=0) output="false" {
        var cfg = config(arguments.module);
        var sqlText = "SELECT * FROM " & cfg.table & " ORDER BY " & cfg.pk & " DESC LIMIT ? OFFSET ?";
        return queryExecute(sqlText, [
            {value: arguments.limit, cfsqltype:"cf_sql_integer"},
            {value: arguments.offset, cfsqltype:"cf_sql_integer"}
        ], {datasource:"demo_sc"});
    }

    public query function get(required string module, required numeric id) output="false" {
        var cfg = config(arguments.module);
        return queryExecute("SELECT * FROM " & cfg.table & " WHERE " & cfg.pk & " = ?", [
            {value: arguments.id, cfsqltype:"cf_sql_bigint"}
        ], {datasource:"demo_sc"});
    }

    public struct function create(required string module, required struct data) output="false" {
        var cfg = config(arguments.module);
        var columns = [];
        var placeholders = [];
        var params = [];
        for (var col in cfg.columns) {
            if (structKeyExists(arguments.data, col) && !isNull(arguments.data[col]) && trim(arguments.data[col] & "") != "") {
                arrayAppend(columns, col);
                arrayAppend(placeholders, "?");
                arrayAppend(params, {value: normalizeValue(arguments.data[col]), cfsqltype: inferSqlType(col, arguments.data[col])});
            }
        }
        if (arrayLen(columns) == 0) throw(message="No valid fields provided for create.");
        var sqlText = "INSERT INTO " & cfg.table & " (" & arrayToList(columns) & ") VALUES (" & arrayToList(placeholders) & ") RETURNING " & cfg.pk;
        var q = queryExecute(sqlText, params, {datasource:"demo_sc"});
        return {"success": true, "id": q[cfg.pk][1]};
    }

    public struct function update(required string module, required numeric id, required struct data) output="false" {
        var cfg = config(arguments.module);
        var sets = [];
        var params = [];
        for (var col in cfg.columns) {
            if (structKeyExists(arguments.data, col)) {
                arrayAppend(sets, col & " = ?");
                arrayAppend(params, {value: normalizeValue(arguments.data[col]), cfsqltype: inferSqlType(col, arguments.data[col])});
            }
        }
        if (arrayLen(sets) == 0) throw(message="No valid fields provided for update.");
        arrayAppend(params, {value: arguments.id, cfsqltype:"cf_sql_bigint"});
        var sqlText = "UPDATE " & cfg.table & " SET " & arrayToList(sets) & " WHERE " & cfg.pk & " = ?";
        queryExecute(sqlText, params, {datasource:"demo_sc"});
        return {"success": true, "id": arguments.id};
    }

    public struct function delete(required string module, required numeric id) output="false" {
        var cfg = config(arguments.module);
        queryExecute("DELETE FROM " & cfg.table & " WHERE " & cfg.pk & " = ?", [
            {value: arguments.id, cfsqltype:"cf_sql_bigint"}
        ], {datasource:"demo_sc"});
        return {"success": true, "id": arguments.id};
    }

    public struct function readJsonBody() output="false" {
        var raw = toString(getHttpRequestData().content);
        if (len(trim(raw)) == 0) return {};
        return deserializeJSON(raw);
    }

    private any function normalizeValue(required any value) output="false" {
        if (isStruct(arguments.value) || isArray(arguments.value)) return serializeJSON(arguments.value);
        if (isSimpleValue(arguments.value) && trim(arguments.value & "") == "") return javacast("null", "");
        return arguments.value;
    }

    private string function inferSqlType(required string col, required any value) output="false" {
        if (findNoCase("_id", arguments.col) || listFindNoCase("site_id,zone_id,device_id,role_id,user_id,alert_id,work_order_id,agent_task_id", arguments.col)) return "cf_sql_bigint";
        if (findNoCase("latitude", arguments.col) || findNoCase("longitude", arguments.col) || findNoCase("value", arguments.col)) return "cf_sql_decimal";
        if (findNoCase("_at", arguments.col)) return "cf_sql_timestamp";
        if (findNoCase("payload", arguments.col) || findNoCase("content", arguments.col) || findNoCase("description", arguments.col) || findNoCase("summary", arguments.col)) return "cf_sql_longvarchar";
        return "cf_sql_varchar";
    }
}
