component output="false" {
  public struct function config(required string module) output="false" {
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
    if (!structKeyExists(configs, arguments.module)) throw(message="Unknown module: " & arguments.module);
    return configs[arguments.module];
  }
}
