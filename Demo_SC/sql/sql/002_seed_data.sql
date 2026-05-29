INSERT INTO sc_roles(role_code, role_name, role_description) VALUES
('admin','System Administrator','Full access to platform configuration and operations'),
('operator','Operations Manager','Can manage alerts, work orders, inspections and AI tasks'),
('inspector','Field Inspector','Can execute inspections and update work orders'),
('viewer','Executive Viewer','Read-only access to dashboards and reports');

INSERT INTO sc_users(role_id, email, full_name, phone, user_status) VALUES
(1,'admin@demo-sc.local','Admin User','+1-000-000-0001','active'),
(2,'ops.manager@demo-sc.local','Operations Manager','+1-000-000-0002','active'),
(3,'inspector.li@demo-sc.local','Inspector Li','+1-000-000-0003','active'),
(4,'director@demo-sc.local','Executive Director','+1-000-000-0004','active');

INSERT INTO sc_sites(site_code, site_name, site_type, address, city, province, latitude, longitude, site_status) VALUES
('SC-PARK-001','East District Smart Industrial Park','industrial_park','88 Innovation Road','Beijing','Beijing',39.904200,116.407400,'active'),
('SC-BLDG-002','Central Commercial Building','commercial_building','19 Central Ave','Shanghai','Shanghai',31.230400,121.473700,'active');

INSERT INTO sc_zones(site_id, zone_code, zone_name, floor_label, risk_level, zone_status) VALUES
(1,'A-F1','Building A Floor 1','F1','normal','active'),
(1,'A-F3','Building A Floor 3','F3','elevated','active'),
(1,'B-KITCHEN','Building B Restaurant Area','F2','high','active'),
(2,'C-LOBBY','Central Lobby','F1','normal','active');

INSERT INTO sc_devices(site_id, zone_id, device_code, device_name, device_type, vendor_name, install_location, latitude, longitude, device_status, last_seen_at) VALUES
(1,1,'SMK-A1-001','Smoke Detector A1-001','smoke_detector','SafeSense','Building A Floor 1 West Corridor',39.904210,116.407410,'online',NOW()),
(1,2,'SMK-A3-003','Smoke Detector A3-003','smoke_detector','SafeSense','Building A Floor 3 Equipment Room',39.904240,116.407450,'warning',NOW() - INTERVAL '3 minutes'),
(1,3,'OIL-B2-009','Oil Fume Monitor B2-009','oil_fume_monitor','CleanAir','Building B Restaurant Exhaust Pipe',39.904260,116.407480,'online',NOW()),
(1,2,'TH-A3-011','Temperature Humidity Sensor A3-011','temperature_humidity','EnviroTech','Building A Floor 3 South Wing',39.904235,116.407430,'online',NOW()),
(1,1,'CAM-A1-002','Camera A1-002','camera','VisionBox','Building A Floor 1 Entrance',39.904225,116.407420,'online',NOW()),
(2,4,'MTR-C1-E01','Electricity Meter C1-E01','electric_meter','MeterPro','Central Building Main Panel',31.230410,121.473710,'online',NOW()),
(2,4,'MTR-C1-W01','Water Meter C1-W01','water_meter','MeterPro','Central Building Water Room',31.230420,121.473720,'online',NOW());

INSERT INTO sc_sensor_readings(device_id, metric_name, metric_value, metric_unit, quality_status, captured_at, raw_payload) VALUES
(1,'smoke_density',0.0200,'ppm','normal',NOW() - INTERVAL '10 minutes','{"source":"simulator"}'),
(2,'smoke_density',0.3200,'ppm','warning',NOW() - INTERVAL '3 minutes','{"source":"simulator","threshold":0.25}'),
(3,'oil_fume_concentration',7.8000,'mg/m3','critical',NOW() - INTERVAL '5 minutes','{"source":"simulator","threshold":6.0}'),
(4,'temperature',31.5000,'C','warning',NOW() - INTERVAL '2 minutes','{"source":"simulator","threshold":30}'),
(4,'humidity',68.0000,'%','normal',NOW() - INTERVAL '2 minutes','{"source":"simulator"}');

INSERT INTO sc_alerts(device_id, site_id, zone_id, alert_code, alert_title, alert_level, alert_status, alert_description, triggered_at, assigned_user_id) VALUES
(2,1,2,'SMOKE_DENSITY_HIGH','Smoke density exceeded threshold','high','open','Smoke detector A3-003 reported repeated high smoke density readings.',NOW() - INTERVAL '3 minutes',2),
(3,1,3,'OIL_FUME_CRITICAL','Oil fume concentration critical','critical','open','Restaurant exhaust monitoring device reported critical oil fume concentration.',NOW() - INTERVAL '5 minutes',2),
(4,1,2,'TEMP_WARNING','Temperature above normal range','medium','acknowledged','Temperature sensor reported elevated temperature in Building A Floor 3.',NOW() - INTERVAL '2 minutes',3);

INSERT INTO sc_work_orders(alert_id, site_id, zone_id, created_by_user_id, assigned_to_user_id, work_order_title, work_order_description, priority, work_order_status, due_at) VALUES
(1,1,2,2,3,'Inspect Smoke Detector A3-003','Check smoke detector status, inspect equipment room, verify whether smoke source exists, and update incident result.','high','in_progress',NOW() + INTERVAL '2 hours'),
(2,1,3,2,3,'Investigate Oil Fume Critical Alert','Inspect restaurant exhaust pipe and verify oil fume purification device operation.','critical','new',NOW() + INTERVAL '1 hour');

INSERT INTO sc_inspections(site_id, zone_id, inspector_user_id, inspection_type, inspection_status, scheduled_at, completed_at, result_summary) VALUES
(1,2,3,'fire_safety','scheduled',NOW() + INTERVAL '30 minutes',NULL,NULL),
(1,3,3,'oil_fume_compliance','completed',NOW() - INTERVAL '1 day',NOW() - INTERVAL '23 hours','Filter was partially blocked. Cleaning completed.');

INSERT INTO sc_maintenance_records(device_id, work_order_id, technician_user_id, maintenance_type, maintenance_status, maintenance_notes, started_at, completed_at) VALUES
(3,2,3,'filter_cleaning','completed','Cleaned oil fume purification filter and recalibrated sensor.',NOW() - INTERVAL '1 day',NOW() - INTERVAL '23 hours');

INSERT INTO sc_camera_events(device_id, site_id, zone_id, event_type, event_level, event_summary, snapshot_url, detected_at, raw_payload) VALUES
(5,1,1,'person_detected','info','Camera detected normal entry activity.','/assets/demo/cam-a1-002.jpg',NOW() - INTERVAL '20 minutes','{"confidence":0.94}'),
(5,1,1,'restricted_area_entry','warning','Camera detected after-hours movement near restricted corridor.','/assets/demo/cam-a1-002-warning.jpg',NOW() - INTERVAL '8 minutes','{"confidence":0.82}');

INSERT INTO sc_meter_readings(device_id, meter_type, reading_value, reading_unit, reading_period, captured_at, raw_payload) VALUES
(6,'electricity',12880.5000,'kWh','daily',NOW() - INTERVAL '1 hour','{"source":"simulator"}'),
(7,'water',325.9000,'m3','daily',NOW() - INTERVAL '1 hour','{"source":"simulator"}');

INSERT INTO sc_knowledge_documents(document_type, document_title, document_source, document_content, chunk_text, embedding_text, embedding_json, created_by_user_id) VALUES
('sop','Smoke Detector Repeated Alert SOP','Internal SOP','When a smoke detector reports repeated high smoke density, field staff must verify device health, inspect local environment, confirm whether fire risk exists, and escalate to emergency response if visible smoke or heat source is confirmed.','Repeated smoke detector alert requires device health check, local inspection, risk confirmation, and emergency escalation if real smoke is confirmed.','smoke detector repeated alert emergency inspection escalation',NULL,1),
('policy','Oil Fume Monitoring Compliance Policy','City Regulation','Restaurant oil fume concentration above threshold must be inspected within one hour. If purification equipment is offline or blocked, issue a remediation work order and verify after cleaning.','Oil fume above threshold requires inspection within one hour, remediation work order, and verification after cleaning.','oil fume threshold inspection remediation verification',NULL,1),
('sop','Device Offline Troubleshooting SOP','Internal SOP','For repeated offline events, check device power, network connection, gateway status, and recent maintenance history. Replace device if offline events repeat more than three times within 24 hours.','Repeated offline events require power, network, gateway, and maintenance history checks.','device offline troubleshooting gateway power network maintenance',NULL,1);

INSERT INTO sc_agent_tasks(requested_by_user_id, site_id, zone_id, goal_text, agent_status, risk_level, plan_summary, rag_context) VALUES
(2,1,2,'Investigate repeated smoke detector alerts in Building A Floor 3','planned','high','Retrieve device readings, check SOP, assess risk, create inspection work order, notify inspector.','Smoke Detector Repeated Alert SOP');

INSERT INTO sc_agent_task_steps(agent_task_id, step_order, step_name, step_type, step_status, tool_name, input_payload, output_payload) VALUES
(1,1,'Retrieve recent device telemetry','tool','completed','sensor_readings.lookup','{"device_code":"SMK-A3-003"}','{"latest_smoke_density":0.32,"quality_status":"warning"}'),
(1,2,'Retrieve relevant SOP','rag','completed','knowledge.search','{"query":"repeated smoke detector alert"}','{"document_title":"Smoke Detector Repeated Alert SOP"}'),
(1,3,'Create inspection work order','workflow','pending','work_orders.create','{"priority":"high"}',NULL);

INSERT INTO sc_audit_logs(user_id, entity_name, entity_pk, action_name, action_summary, ip_address, request_payload) VALUES
(1,'sc_system','seed','seed_data_loaded','Initial demo seed data loaded','127.0.0.1','{}');
