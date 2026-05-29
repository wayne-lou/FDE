<cfscript>
function sendJson(required any data, numeric statusCode=200) {
    cfcontent(type="application/json; charset=utf-8", reset=true);
    cfheader(statuscode=arguments.statusCode, statustext=(arguments.statusCode EQ 200 ? "OK" : "Error"));
    writeOutput(serializeJSON(arguments.data));
    abort;
}
function qToArray(required query q) {
    var arr = [];
    var cols = listToArray(arguments.q.columnList);
    for (var r = 1; r <= arguments.q.recordCount; r++) {
        var row = {};
        for (var c in cols) row[lcase(c)] = arguments.q[c][r];
        arrayAppend(arr, row);
    }
    return arr;
}
</cfscript>
<cftry>
    <cfquery name="qDevices" datasource="demo_sc">
        SELECT device_status, COUNT(*) AS total
        FROM sc_devices
        GROUP BY device_status
        ORDER BY device_status
    </cfquery>

    <cfquery name="qAlerts" datasource="demo_sc">
        SELECT alert_status, alert_level, COUNT(*) AS total
        FROM sc_alerts
        GROUP BY alert_status, alert_level
        ORDER BY alert_status, alert_level
    </cfquery>

    <cfquery name="qWorkOrders" datasource="demo_sc">
        SELECT work_order_status, priority, COUNT(*) AS total
        FROM sc_work_orders
        GROUP BY work_order_status, priority
        ORDER BY work_order_status, priority
    </cfquery>

    <cfquery name="qRecentReadings" datasource="demo_sc">
        SELECT d.device_code, d.device_name, d.device_type, r.metric_name, r.metric_value, r.metric_unit, r.quality_status, r.captured_at
        FROM sc_sensor_readings r
        JOIN sc_devices d ON r.device_id = d.device_id
        ORDER BY r.captured_at DESC
        LIMIT 20
    </cfquery>

    <cfquery name="qOpenAlerts" datasource="demo_sc">
        SELECT a.alert_id, a.alert_code, a.alert_title, a.alert_level, a.alert_status, a.triggered_at,
               d.device_code, d.device_name, d.device_type, z.zone_name, s.site_name
        FROM sc_alerts a
        JOIN sc_devices d ON a.device_id = d.device_id
        LEFT JOIN sc_zones z ON a.zone_id = z.zone_id
        LEFT JOIN sc_sites s ON a.site_id = s.site_id
        WHERE a.alert_status <> 'resolved'
        ORDER BY CASE a.alert_level WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END, a.triggered_at DESC
        LIMIT 20
    </cfquery>

    <cfscript>
    sendJson({
        "success": true,
        "data": {
            "devices": qToArray(qDevices),
            "alerts": qToArray(qAlerts),
            "work_orders": qToArray(qWorkOrders),
            "recent_readings": qToArray(qRecentReadings),
            "open_alerts": qToArray(qOpenAlerts)
        }
    });
    </cfscript>
    <cfcatch type="any">
        <cfscript>
        sendJson({"success":false,"message":cfcatch.message,"detail":cfcatch.detail ?: ""},500);
        </cfscript>
    </cfcatch>
</cftry>
