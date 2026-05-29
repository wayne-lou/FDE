<cfscript>
function sendJson(required any data){cfcontent(type="application/json; charset=utf-8", reset=true); writeOutput(serializeJSON(data)); abort;}
function q2a(required query q){var a=[]; var cols=listToArray(q.columnList); for(var r=1;r<=q.recordCount;r++){var row={}; for(var c in cols) row[lcase(c)]=q[c][r]; arrayAppend(a,row);} return a;}
try {
  qDrivers=queryExecute("SELECT driver_status, COUNT(*) total FROM rc_drivers GROUP BY driver_status",[],{datasource:"demo_rc"});
  qTasks=queryExecute("SELECT task_status, COUNT(*) total FROM rc_logistics_tasks GROUP BY task_status",[],{datasource:"demo_rc"});
  qFatigue=queryExecute("SELECT f.*, d.driver_name, d.driver_code FROM rc_fatigue_assessments f JOIN rc_drivers d ON f.driver_id=d.driver_id ORDER BY f.created_at DESC LIMIT 5",[],{datasource:"demo_rc"});
  qSchedule=queryExecute("SELECT s.*, d.driver_name FROM rc_schedule_items s JOIN rc_drivers d ON s.driver_id=d.driver_id ORDER BY s.start_at ASC LIMIT 8",[],{datasource:"demo_rc"});
  qReadings=queryExecute("SELECT w.*, d.driver_name, d.driver_code FROM rc_wearable_readings w JOIN rc_drivers d ON w.driver_id=d.driver_id ORDER BY w.captured_at DESC LIMIT 8",[],{datasource:"demo_rc"});
  qOpenTasks=queryExecute("SELECT t.*, d.driver_name FROM rc_logistics_tasks t JOIN rc_drivers d ON t.driver_id=d.driver_id WHERE task_status <> 'completed' ORDER BY CASE priority WHEN 'critical' THEN 1 WHEN 'high' THEN 2 ELSE 3 END, due_at ASC LIMIT 8",[],{datasource:"demo_rc"});
  sendJson({success:true,data:{drivers:q2a(qDrivers),tasks:q2a(qTasks),fatigue:q2a(qFatigue),schedule:q2a(qSchedule),recent_readings:q2a(qReadings),open_tasks:q2a(qOpenTasks)}});
} catch(any e){sendJson({success:false,message:e.message});}
</cfscript>
