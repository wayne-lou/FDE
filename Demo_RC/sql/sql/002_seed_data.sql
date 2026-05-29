INSERT INTO rc_roles(role_code,role_name,role_description) VALUES
('admin','Admin','System admin'),('coach','Performance Coach','Driver performance and recovery'),('logistics','Logistics Coordinator','Travel and schedule operations'),('engineer','Race Engineer','Engineering stakeholder');
INSERT INTO rc_users(role_id,email,full_name,phone,user_status) VALUES
(1,'admin@demo-rc.local','Admin User','+1-000-000-0001','active'),(2,'coach@demo-rc.local','Performance Coach','+1-000-000-0002','active'),(3,'ops@demo-rc.local','Logistics Manager','+1-000-000-0003','active'),(4,'engineer@demo-rc.local','Race Engineer','+1-000-000-0004','active');
INSERT INTO rc_drivers(driver_code,driver_name,team_name,primary_coach_user_id,timezone_home,driver_status) VALUES
('DRV-01','Alex Rivera','Eclipse Racing',2,'Europe/London','active'),('DRV-02','Mika Chen','Eclipse Racing',2,'America/Los_Angeles','active');
INSERT INTO rc_race_events(event_code,event_name,circuit_name,city,country,timezone_name,start_date,end_date,event_status) VALUES
('MON-2026','Monaco Race Weekend','Circuit de Monaco','Monaco','Monaco','Europe/Monaco','2026-05-29','2026-05-31','active');
INSERT INTO rc_schedule_items(driver_id,race_event_id,item_type,item_title,item_location,start_at,end_at,priority,schedule_status,notes) VALUES
(1,1,'media','Sponsor media session','Paddock Media Center',CURRENT_TIMESTAMP + INTERVAL '2 hours',CURRENT_TIMESTAMP + INTERVAL '3 hours','high','confirmed','Could be shortened if fatigue risk increases'),
(1,1,'briefing','Engineering briefing','Team Garage',CURRENT_TIMESTAMP + INTERVAL '4 hours',CURRENT_TIMESTAMP + INTERVAL '5 hours','high','confirmed','Prep tire and setup feedback'),
(1,1,'recovery','Physio recovery block','Hotel Recovery Room',CURRENT_TIMESTAMP + INTERVAL '6 hours',CURRENT_TIMESTAMP + INTERVAL '7 hours','critical','planned','Protect sleep window'),
(2,1,'simulator','Simulator refresh','Sim Room',CURRENT_TIMESTAMP + INTERVAL '3 hours',CURRENT_TIMESTAMP + INTERVAL '4 hours','medium','planned','Optional if overload high');
INSERT INTO rc_wearable_readings(driver_id,metric_name,metric_value,metric_unit,quality_status,captured_at,raw_payload) VALUES
(1,'sleep_hours',4.8,'hours','warning',CURRENT_TIMESTAMP - INTERVAL '1 hour','{"source":"oura","sleep_debt":true}'),
(1,'hrv',38,'ms','warning',CURRENT_TIMESTAMP - INTERVAL '45 minutes','{"baseline":55}'),
(1,'resting_heart_rate',68,'bpm','warning',CURRENT_TIMESTAMP - INTERVAL '30 minutes','{"baseline":58}'),
(2,'sleep_hours',7.2,'hours','good',CURRENT_TIMESTAMP - INTERVAL '1 hour','{"source":"garmin"}');
INSERT INTO rc_fatigue_assessments(driver_id,race_event_id,fatigue_score,sleep_score,timezone_load,cognitive_load,risk_level,assessment_summary) VALUES
(1,1,82,46,75,78,'high','Sleep debt, media load, and timezone adjustment indicate elevated fatigue risk.'),(2,1,34,86,30,40,'low','Stable recovery profile.');
INSERT INTO rc_logistics_tasks(driver_id,race_event_id,assigned_to_user_id,task_type,task_title,task_description,priority,task_status,due_at) VALUES
(1,1,3,'recovery','Protect 90-minute recovery window','Move non-critical media or logistics items away from driver recovery block.','high','open',CURRENT_TIMESTAMP + INTERVAL '2 hours'),
(1,1,2,'health_check','Review fatigue indicators','Coach to review sleep, HRV and cognitive load before next briefing.','high','assigned',CURRENT_TIMESTAMP + INTERVAL '1 hour');
INSERT INTO rc_meetings(race_event_id,driver_id,meeting_type,meeting_title,meeting_status,scheduled_at,summary) VALUES
(1,1,'engineering','FP2 feedback briefing','scheduled',CURRENT_TIMESTAMP + INTERVAL '4 hours','Discuss tire temperature and corner balance feedback.'),
(1,1,'media','Sponsor Q&A','scheduled',CURRENT_TIMESTAMP + INTERVAL '2 hours','Can be shortened if fatigue risk remains high.');
INSERT INTO rc_recovery_sessions(driver_id,race_event_id,coach_user_id,session_type,session_status,scheduled_at,duration_minutes,notes) VALUES
(1,1,2,'physio','scheduled',CURRENT_TIMESTAMP + INTERVAL '6 hours',60,'Focus on neck, hydration, breathing reset.'),(1,1,2,'sleep_block','scheduled',CURRENT_TIMESTAMP + INTERVAL '8 hours',90,'Protect from non-critical interruptions.');
INSERT INTO rc_knowledge_documents(document_type,document_title,document_source,document_content,chunk_text,embedding_text,embedding_json,document_status,created_by_user_id) VALUES
('SOP','Driver fatigue escalation SOP','Performance Ops Manual','If fatigue score exceeds 75 or sleep hours below 5, reduce non-critical media load, notify coach, protect recovery window, and require human approval before schedule changes.','fatigue score above 75 sleep below 5 reduce media protect recovery notify coach human approval','fatigue escalation recovery workflow','{}','active',1),
('Policy','Race weekend recovery policy','Team Policy','Driver recovery windows are protected operational blocks. Schedule changes must preserve recovery, nutrition, hydration and briefing readiness.','recovery window schedule change nutrition hydration briefing readiness','driver recovery policy','{}','active',1),
('Playbook','Media overload mitigation','Operations Playbook','For high media load, shorten sessions, combine interviews, or move low-priority sponsor tasks after recovery.','media load shorten session combine interviews move low priority tasks','media overload','{}','active',1);
