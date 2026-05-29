DROP TABLE IF EXISTS rc_agent_task_steps, rc_agent_tasks, rc_audit_logs, rc_knowledge_documents, rc_recovery_sessions, rc_meetings, rc_logistics_tasks, rc_fatigue_assessments, rc_wearable_readings, rc_schedule_items, rc_race_events, rc_drivers, rc_users, rc_roles CASCADE;

CREATE TABLE rc_roles (role_id BIGSERIAL PRIMARY KEY, role_code VARCHAR(50) UNIQUE NOT NULL, role_name VARCHAR(120) NOT NULL, role_description TEXT);
CREATE TABLE rc_users (user_id BIGSERIAL PRIMARY KEY, role_id BIGINT REFERENCES rc_roles(role_id), email VARCHAR(160) UNIQUE NOT NULL, full_name VARCHAR(120) NOT NULL, phone VARCHAR(50), user_status VARCHAR(30) DEFAULT 'active', created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP);
CREATE INDEX idx_rc_users_role ON rc_users(role_id);

CREATE TABLE rc_drivers (driver_id BIGSERIAL PRIMARY KEY, driver_code VARCHAR(50) UNIQUE NOT NULL, driver_name VARCHAR(120) NOT NULL, team_name VARCHAR(120), primary_coach_user_id BIGINT REFERENCES rc_users(user_id), timezone_home VARCHAR(80), driver_status VARCHAR(30) DEFAULT 'active', created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP);
CREATE INDEX idx_rc_drivers_coach ON rc_drivers(primary_coach_user_id);

CREATE TABLE rc_race_events (race_event_id BIGSERIAL PRIMARY KEY, event_code VARCHAR(50) UNIQUE NOT NULL, event_name VARCHAR(160) NOT NULL, circuit_name VARCHAR(160), city VARCHAR(100), country VARCHAR(100), timezone_name VARCHAR(80), start_date DATE, end_date DATE, event_status VARCHAR(30) DEFAULT 'planned');

CREATE TABLE rc_schedule_items (schedule_item_id BIGSERIAL PRIMARY KEY, driver_id BIGINT REFERENCES rc_drivers(driver_id), race_event_id BIGINT REFERENCES rc_race_events(race_event_id), item_type VARCHAR(40), item_title VARCHAR(180), item_location VARCHAR(180), start_at TIMESTAMP, end_at TIMESTAMP, priority VARCHAR(30), schedule_status VARCHAR(30), notes TEXT);
CREATE INDEX idx_rc_schedule_driver_event ON rc_schedule_items(driver_id, race_event_id, start_at);

CREATE TABLE rc_wearable_readings (wearable_reading_id BIGSERIAL PRIMARY KEY, driver_id BIGINT REFERENCES rc_drivers(driver_id), metric_name VARCHAR(80), metric_value NUMERIC(12,2), metric_unit VARCHAR(40), quality_status VARCHAR(30), captured_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, raw_payload JSONB);
CREATE INDEX idx_rc_wearable_driver_time ON rc_wearable_readings(driver_id, captured_at DESC);

CREATE TABLE rc_fatigue_assessments (fatigue_assessment_id BIGSERIAL PRIMARY KEY, driver_id BIGINT REFERENCES rc_drivers(driver_id), race_event_id BIGINT REFERENCES rc_race_events(race_event_id), fatigue_score NUMERIC(5,2), sleep_score NUMERIC(5,2), timezone_load NUMERIC(5,2), cognitive_load NUMERIC(5,2), risk_level VARCHAR(30), assessment_summary TEXT, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP);
CREATE INDEX idx_rc_fatigue_driver_event ON rc_fatigue_assessments(driver_id, race_event_id, created_at DESC);

CREATE TABLE rc_logistics_tasks (logistics_task_id BIGSERIAL PRIMARY KEY, driver_id BIGINT REFERENCES rc_drivers(driver_id), race_event_id BIGINT REFERENCES rc_race_events(race_event_id), assigned_to_user_id BIGINT REFERENCES rc_users(user_id), task_type VARCHAR(50), task_title VARCHAR(180), task_description TEXT, priority VARCHAR(30), task_status VARCHAR(30), due_at TIMESTAMP, completed_at TIMESTAMP, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP);
CREATE INDEX idx_rc_tasks_status ON rc_logistics_tasks(task_status, priority, due_at);

CREATE TABLE rc_meetings (meeting_id BIGSERIAL PRIMARY KEY, race_event_id BIGINT REFERENCES rc_race_events(race_event_id), driver_id BIGINT REFERENCES rc_drivers(driver_id), meeting_type VARCHAR(50), meeting_title VARCHAR(180), meeting_status VARCHAR(30), scheduled_at TIMESTAMP, summary TEXT);

CREATE TABLE rc_recovery_sessions (recovery_session_id BIGSERIAL PRIMARY KEY, driver_id BIGINT REFERENCES rc_drivers(driver_id), race_event_id BIGINT REFERENCES rc_race_events(race_event_id), coach_user_id BIGINT REFERENCES rc_users(user_id), session_type VARCHAR(50), session_status VARCHAR(30), scheduled_at TIMESTAMP, duration_minutes INT, notes TEXT);

CREATE TABLE rc_knowledge_documents (knowledge_document_id BIGSERIAL PRIMARY KEY, document_type VARCHAR(60), document_title VARCHAR(200), document_source VARCHAR(200), document_content TEXT, chunk_text TEXT, embedding_text TEXT, embedding_json JSONB, document_status VARCHAR(30), created_by_user_id BIGINT REFERENCES rc_users(user_id), created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP);
CREATE INDEX idx_rc_knowledge_type ON rc_knowledge_documents(document_type, document_status);

CREATE TABLE rc_agent_tasks (agent_task_id BIGSERIAL PRIMARY KEY, requested_by_user_id BIGINT REFERENCES rc_users(user_id), driver_id BIGINT REFERENCES rc_drivers(driver_id), race_event_id BIGINT REFERENCES rc_race_events(race_event_id), goal_text TEXT, agent_status VARCHAR(30), risk_level VARCHAR(30), plan_summary TEXT, rag_context TEXT, created_logistics_task_id BIGINT REFERENCES rc_logistics_tasks(logistics_task_id), created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP);

CREATE TABLE rc_agent_task_steps (agent_task_step_id BIGSERIAL PRIMARY KEY, agent_task_id BIGINT REFERENCES rc_agent_tasks(agent_task_id) ON DELETE CASCADE, step_order INT, step_name VARCHAR(180), step_type VARCHAR(50), step_status VARCHAR(30), tool_name VARCHAR(100), input_payload JSONB, output_payload JSONB);

CREATE TABLE rc_audit_logs (audit_log_id BIGSERIAL PRIMARY KEY, user_id BIGINT REFERENCES rc_users(user_id), entity_name VARCHAR(100), entity_pk VARCHAR(100), action_name VARCHAR(100), action_summary TEXT, ip_address VARCHAR(80), request_payload JSONB, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP);
