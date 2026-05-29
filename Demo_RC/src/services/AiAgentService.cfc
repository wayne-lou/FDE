component output="false" {
  public struct function plan(required string goal, numeric driver_id=1, numeric race_event_id=1, numeric user_id=1) output="false" {
    var rag = new services.RagService();
    var docs = rag.search(arguments.goal, 5);
    var context = rag.buildContext(docs);
    var ops = latestContext(arguments.driver_id, arguments.race_event_id);
    var plan = buildPlan(arguments.goal, context, ops);
    var taskId = createDraftTask(arguments.user_id, arguments.driver_id, arguments.race_event_id, plan);
    var q = queryExecute("INSERT INTO rc_agent_tasks(requested_by_user_id, driver_id, race_event_id, goal_text, agent_status, risk_level, plan_summary, rag_context, created_logistics_task_id) VALUES (?, ?, ?, ?, 'planned', ?, ?, ?, ?) RETURNING agent_task_id",[
      {value:arguments.user_id,cfsqltype:'cf_sql_bigint'},{value:arguments.driver_id,cfsqltype:'cf_sql_bigint'},{value:arguments.race_event_id,cfsqltype:'cf_sql_bigint'},{value:arguments.goal,cfsqltype:'cf_sql_longvarchar'},{value:plan.risk_level,cfsqltype:'cf_sql_varchar'},{value:plan.summary,cfsqltype:'cf_sql_longvarchar'},{value:context,cfsqltype:'cf_sql_longvarchar'},{value:taskId,cfsqltype:'cf_sql_bigint'}],{datasource:'demo_rc'});
    var agentTaskId=q.agent_task_id[1]; var n=1;
    for (var step in plan.steps){ queryExecute("INSERT INTO rc_agent_task_steps(agent_task_id,step_order,step_name,step_type,step_status,tool_name,input_payload,output_payload) VALUES (?,?,?,?,?,?,CAST(? AS jsonb),CAST(? AS jsonb))",[
      {value:agentTaskId,cfsqltype:'cf_sql_bigint'},{value:n,cfsqltype:'cf_sql_integer'},{value:step.name,cfsqltype:'cf_sql_varchar'},{value:step.type,cfsqltype:'cf_sql_varchar'},{value:n<=3?'completed':'pending',cfsqltype:'cf_sql_varchar'},{value:step.tool,cfsqltype:'cf_sql_varchar'},{value:serializeJSON(step.input),cfsqltype:'cf_sql_longvarchar'},{value:serializeJSON({created_logistics_task_id:taskId}),cfsqltype:'cf_sql_longvarchar'}],{datasource:'demo_rc'}); n++; }
    queryExecute("INSERT INTO rc_audit_logs(user_id,entity_name,entity_pk,action_name,action_summary,request_payload) VALUES (?, 'rc_agent_tasks', ?, 'agent_plan_created', ?, CAST(? AS jsonb))",[
      {value:arguments.user_id,cfsqltype:'cf_sql_bigint'},{value:agentTaskId&'',cfsqltype:'cf_sql_varchar'},{value:'DriverOps agent plan generated with RAG and human-reviewed workflow',cfsqltype:'cf_sql_varchar'},{value:serializeJSON({goal:arguments.goal,driver_id:arguments.driver_id,race_event_id:arguments.race_event_id}),cfsqltype:'cf_sql_longvarchar'}],{datasource:'demo_rc'});
    plan.agent_task_id=agentTaskId; plan.created_logistics_task_id=taskId; plan.rag_documents=docs; plan.operational_context=ops; return plan;
  }

  private struct function latestContext(required numeric driver_id, required numeric race_event_id) output="false" {
    var f=queryExecute("SELECT * FROM rc_fatigue_assessments WHERE driver_id=? AND race_event_id=? ORDER BY created_at DESC LIMIT 1",[{value:arguments.driver_id,cfsqltype:'cf_sql_bigint'},{value:arguments.race_event_id,cfsqltype:'cf_sql_bigint'}],{datasource:'demo_rc'});
    var t=queryExecute("SELECT COUNT(*) total, SUM(CASE WHEN priority IN ('high','critical') AND task_status <> 'completed' THEN 1 ELSE 0 END) high_total FROM rc_logistics_tasks WHERE driver_id=? AND race_event_id=? AND task_status <> 'completed'",[{value:arguments.driver_id,cfsqltype:'cf_sql_bigint'},{value:arguments.race_event_id,cfsqltype:'cf_sql_bigint'}],{datasource:'demo_rc'});
    var s=queryExecute("SELECT COUNT(*) total FROM rc_schedule_items WHERE driver_id=? AND race_event_id=? AND start_at BETWEEN CURRENT_TIMESTAMP AND CURRENT_TIMESTAMP + INTERVAL '12 hours'",[{value:arguments.driver_id,cfsqltype:'cf_sql_bigint'},{value:arguments.race_event_id,cfsqltype:'cf_sql_bigint'}],{datasource:'demo_rc'});
    return {fatigue_score:f.recordCount?val(f.fatigue_score[1]):0,sleep_score:f.recordCount?val(f.sleep_score[1]):0,risk_level:f.recordCount?f.risk_level[1]:'unknown',open_tasks:val(t.total[1]),high_tasks:val(t.high_total[1]),next_12h_schedule_count:val(s.total[1])};
  }

  private struct function buildPlan(required string goal, required string context, required struct ops) output="false" {
    if (structKeyExists(application,'aiMockMode') && application.aiMockMode == 'false' && len(application.openAiApiKey ?: '')) { try { return openAiPlan(arguments.goal,arguments.context,arguments.ops); } catch(any e){} }
    return localPlan(arguments.goal,arguments.context,arguments.ops);
  }

  private struct function localPlan(required string goal, required string context, required struct ops) output="false" {
    var g=lcase(arguments.goal); var topic='fatigue';
    if(find('酒店',g)||findNoCase('hotel',g)||find('行程',g)||findNoCase('travel',g)) topic='logistics';
    if(find('会议',g)||findNoCase('meeting',g)||find('briefing',g)) topic='meeting';
    if(find('休息',g)||find('恢复',g)||findNoCase('recovery',g)||findNoCase('sleep',g)) topic='recovery';
    var risk=(arguments.ops.fatigue_score>=75||arguments.ops.high_tasks>0)?'high':'medium';
    if(arguments.ops.fatigue_score>=85) risk='critical';
    var title={fatigue:'Driver fatigue risk requires schedule protection',recovery:'Recovery window should be protected before next session',meeting:'Briefing and meeting load should be rebalanced',logistics:'Logistics plan should avoid driver cognitive overload'}[topic];
    var summary=title & '. Fatigue score ' & arguments.ops.fatigue_score & ', sleep score ' & arguments.ops.sleep_score & ', next-12h schedule items ' & arguments.ops.next_12h_schedule_count & '. RAG policy context was checked and a human-reviewed logistics/recovery task was prepared.';
    return {ai_mode:'local-driverops-agent',risk_level:risk,summary:summary,answer_title:title,steps:[
      {name:'Read wearable recovery indicators',type:'tool',tool:'wearables.lookup',input:arguments.ops},
      {name:'Check race-weekend schedule density',type:'tool',tool:'schedule.lookup',input:{next_12h_items:arguments.ops.next_12h_schedule_count}},
      {name:'Retrieve recovery / fatigue SOP through RAG',type:'rag',tool:'knowledge.search',input:{query:arguments.goal,context_preview:left(arguments.context,260)}},
      {name:'Assess driver load and escalation path',type:'reasoning',tool:'fatigue.assess',input:{risk_level:risk}},
      {name:'Create human-reviewed logistics/recovery task',type:'workflow',tool:'logistics_tasks.create',input:{priority:risk}},
      {name:'Notify performance coach and operations coordinator',type:'workflow',tool:'notification.dispatch',input:{channel:'ops_console'}}]};
  }

  private numeric function createDraftTask(required numeric user_id, required numeric driver_id, required numeric race_event_id, required struct plan) output="false" {
    var q=queryExecute("INSERT INTO rc_logistics_tasks(driver_id,race_event_id,assigned_to_user_id,task_type,task_title,task_description,priority,task_status,due_at) VALUES (?,?,?,?,?,?,?,'draft',CURRENT_TIMESTAMP + INTERVAL '2 hours') RETURNING logistics_task_id",[
      {value:arguments.driver_id,cfsqltype:'cf_sql_bigint'},{value:arguments.race_event_id,cfsqltype:'cf_sql_bigint'},{value:arguments.user_id,cfsqltype:'cf_sql_bigint'},{value:'recovery',cfsqltype:'cf_sql_varchar'},{value:'AI plan: '&left(arguments.plan.answer_title,120),cfsqltype:'cf_sql_varchar'},{value:arguments.plan.summary,cfsqltype:'cf_sql_longvarchar'},{value:arguments.plan.risk_level,cfsqltype:'cf_sql_varchar'}],{datasource:'demo_rc'});
    return q.logistics_task_id[1];
  }

  private struct function openAiPlan(required string goal, required string context, required struct ops) output="false" {
    var prompt='You are a DriverOps AI agent for a racing team. Return strict JSON with risk_level, summary, answer_title, steps. Goal: '&arguments.goal&chr(10)&'Ops context:'&serializeJSON(arguments.ops)&chr(10)&'RAG:'&arguments.context;
    var body={model:application.openAiModel,messages:[{role:'system',content:'Return JSON only. No markdown.'},{role:'user',content:prompt}],temperature:0.2}; var httpResult='';
    cfhttp(url='https://api.openai.com/v1/chat/completions',method='post',result='httpResult',charset='utf-8',timeout=30){cfhttpparam(type='header',name='Authorization',value='Bearer '&application.openAiApiKey); cfhttpparam(type='header',name='Content-Type',value='application/json'); cfhttpparam(type='body',value=serializeJSON(body));}
    var r=deserializeJSON(httpResult.fileContent); var parsed=deserializeJSON(r.choices[1].message.content); parsed.ai_mode='openai:'&application.openAiModel; return parsed;
  }
}
