CREATE EXTENSION IF NOT EXISTS pgcrypto;
-- Optional for real vector search. Enable when pgvector is installed.
-- CREATE EXTENSION IF NOT EXISTS vector;

DROP TABLE IF EXISTS sc_audit_logs CASCADE;
DROP TABLE IF EXISTS sc_agent_task_steps CASCADE;
DROP TABLE IF EXISTS sc_agent_tasks CASCADE;
DROP TABLE IF EXISTS sc_knowledge_documents CASCADE;
DROP TABLE IF EXISTS sc_meter_readings CASCADE;
DROP TABLE IF EXISTS sc_camera_events CASCADE;
DROP TABLE IF EXISTS sc_maintenance_records CASCADE;
DROP TABLE IF EXISTS sc_inspections CASCADE;
DROP TABLE IF EXISTS sc_work_orders CASCADE;
DROP TABLE IF EXISTS sc_alerts CASCADE;
DROP TABLE IF EXISTS sc_sensor_readings CASCADE;
DROP TABLE IF EXISTS sc_devices CASCADE;
DROP TABLE IF EXISTS sc_zones CASCADE;
DROP TABLE IF EXISTS sc_sites CASCADE;
DROP TABLE IF EXISTS sc_users CASCADE;
DROP TABLE IF EXISTS sc_roles CASCADE;

CREATE TABLE sc_roles (
    role_id BIGSERIAL PRIMARY KEY,
    role_code VARCHAR(50) NOT NULL UNIQUE,
    role_name VARCHAR(100) NOT NULL,
    role_description TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE sc_users (
    user_id BIGSERIAL PRIMARY KEY,
    role_id BIGINT NOT NULL REFERENCES sc_roles(role_id),
    email VARCHAR(255) NOT NULL UNIQUE,
    full_name VARCHAR(120) NOT NULL,
    phone VARCHAR(50),
    user_status VARCHAR(30) NOT NULL DEFAULT 'active',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_sc_users_role_id ON sc_users(role_id);
CREATE INDEX idx_sc_users_status ON sc_users(user_status);

CREATE TABLE sc_sites (
    site_id BIGSERIAL PRIMARY KEY,
    site_code VARCHAR(50) NOT NULL UNIQUE,
    site_name VARCHAR(150) NOT NULL,
    site_type VARCHAR(50) NOT NULL,
    address TEXT,
    city VARCHAR(80),
    province VARCHAR(80),
    latitude NUMERIC(10,6),
    longitude NUMERIC(10,6),
    site_status VARCHAR(30) NOT NULL DEFAULT 'active',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_sc_sites_type ON sc_sites(site_type);
CREATE INDEX idx_sc_sites_status ON sc_sites(site_status);

CREATE TABLE sc_zones (
    zone_id BIGSERIAL PRIMARY KEY,
    site_id BIGINT NOT NULL REFERENCES sc_sites(site_id),
    zone_code VARCHAR(50) NOT NULL,
    zone_name VARCHAR(150) NOT NULL,
    floor_label VARCHAR(50),
    risk_level VARCHAR(30) NOT NULL DEFAULT 'normal',
    zone_status VARCHAR(30) NOT NULL DEFAULT 'active',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(site_id, zone_code)
);
CREATE INDEX idx_sc_zones_site_id ON sc_zones(site_id);
CREATE INDEX idx_sc_zones_risk_level ON sc_zones(risk_level);

CREATE TABLE sc_devices (
    device_id BIGSERIAL PRIMARY KEY,
    site_id BIGINT NOT NULL REFERENCES sc_sites(site_id),
    zone_id BIGINT REFERENCES sc_zones(zone_id),
    device_code VARCHAR(80) NOT NULL UNIQUE,
    device_name VARCHAR(150) NOT NULL,
    device_type VARCHAR(50) NOT NULL,
    vendor_name VARCHAR(100),
    install_location TEXT,
    latitude NUMERIC(10,6),
    longitude NUMERIC(10,6),
    device_status VARCHAR(30) NOT NULL DEFAULT 'online',
    last_seen_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_sc_devices_site_id ON sc_devices(site_id);
CREATE INDEX idx_sc_devices_zone_id ON sc_devices(zone_id);
CREATE INDEX idx_sc_devices_type_status ON sc_devices(device_type, device_status);

CREATE TABLE sc_sensor_readings (
    reading_id BIGSERIAL PRIMARY KEY,
    device_id BIGINT NOT NULL REFERENCES sc_devices(device_id),
    metric_name VARCHAR(80) NOT NULL,
    metric_value NUMERIC(14,4) NOT NULL,
    metric_unit VARCHAR(30),
    quality_status VARCHAR(30) NOT NULL DEFAULT 'normal',
    captured_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    raw_payload JSONB
);
CREATE INDEX idx_sc_sensor_readings_device_time ON sc_sensor_readings(device_id, captured_at DESC);
CREATE INDEX idx_sc_sensor_readings_metric ON sc_sensor_readings(metric_name);
CREATE INDEX idx_sc_sensor_readings_quality ON sc_sensor_readings(quality_status);

CREATE TABLE sc_alerts (
    alert_id BIGSERIAL PRIMARY KEY,
    device_id BIGINT NOT NULL REFERENCES sc_devices(device_id),
    site_id BIGINT NOT NULL REFERENCES sc_sites(site_id),
    zone_id BIGINT REFERENCES sc_zones(zone_id),
    alert_code VARCHAR(80) NOT NULL,
    alert_title VARCHAR(200) NOT NULL,
    alert_level VARCHAR(30) NOT NULL,
    alert_status VARCHAR(30) NOT NULL DEFAULT 'open',
    alert_description TEXT,
    triggered_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMP,
    assigned_user_id BIGINT REFERENCES sc_users(user_id)
);
CREATE INDEX idx_sc_alerts_status_level ON sc_alerts(alert_status, alert_level);
CREATE INDEX idx_sc_alerts_device_id ON sc_alerts(device_id);
CREATE INDEX idx_sc_alerts_site_zone ON sc_alerts(site_id, zone_id);
CREATE INDEX idx_sc_alerts_triggered_at ON sc_alerts(triggered_at DESC);

CREATE TABLE sc_work_orders (
    work_order_id BIGSERIAL PRIMARY KEY,
    alert_id BIGINT REFERENCES sc_alerts(alert_id),
    site_id BIGINT NOT NULL REFERENCES sc_sites(site_id),
    zone_id BIGINT REFERENCES sc_zones(zone_id),
    created_by_user_id BIGINT REFERENCES sc_users(user_id),
    assigned_to_user_id BIGINT REFERENCES sc_users(user_id),
    work_order_title VARCHAR(200) NOT NULL,
    work_order_description TEXT,
    priority VARCHAR(30) NOT NULL DEFAULT 'medium',
    work_order_status VARCHAR(30) NOT NULL DEFAULT 'new',
    due_at TIMESTAMP,
    completed_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_sc_work_orders_status_priority ON sc_work_orders(work_order_status, priority);
CREATE INDEX idx_sc_work_orders_alert_id ON sc_work_orders(alert_id);
CREATE INDEX idx_sc_work_orders_assigned_user ON sc_work_orders(assigned_to_user_id);

CREATE TABLE sc_inspections (
    inspection_id BIGSERIAL PRIMARY KEY,
    site_id BIGINT NOT NULL REFERENCES sc_sites(site_id),
    zone_id BIGINT REFERENCES sc_zones(zone_id),
    inspector_user_id BIGINT NOT NULL REFERENCES sc_users(user_id),
    inspection_type VARCHAR(80) NOT NULL,
    inspection_status VARCHAR(30) NOT NULL DEFAULT 'scheduled',
    scheduled_at TIMESTAMP,
    completed_at TIMESTAMP,
    result_summary TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_sc_inspections_site_zone ON sc_inspections(site_id, zone_id);
CREATE INDEX idx_sc_inspections_status ON sc_inspections(inspection_status);
CREATE INDEX idx_sc_inspections_inspector ON sc_inspections(inspector_user_id);

CREATE TABLE sc_maintenance_records (
    maintenance_id BIGSERIAL PRIMARY KEY,
    device_id BIGINT NOT NULL REFERENCES sc_devices(device_id),
    work_order_id BIGINT REFERENCES sc_work_orders(work_order_id),
    technician_user_id BIGINT REFERENCES sc_users(user_id),
    maintenance_type VARCHAR(80) NOT NULL,
    maintenance_status VARCHAR(30) NOT NULL DEFAULT 'completed',
    maintenance_notes TEXT,
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_sc_maintenance_device_id ON sc_maintenance_records(device_id);
CREATE INDEX idx_sc_maintenance_work_order_id ON sc_maintenance_records(work_order_id);
CREATE INDEX idx_sc_maintenance_status ON sc_maintenance_records(maintenance_status);

CREATE TABLE sc_camera_events (
    camera_event_id BIGSERIAL PRIMARY KEY,
    device_id BIGINT NOT NULL REFERENCES sc_devices(device_id),
    site_id BIGINT NOT NULL REFERENCES sc_sites(site_id),
    zone_id BIGINT REFERENCES sc_zones(zone_id),
    event_type VARCHAR(80) NOT NULL,
    event_level VARCHAR(30) NOT NULL DEFAULT 'info',
    event_summary TEXT,
    snapshot_url TEXT,
    detected_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    raw_payload JSONB
);
CREATE INDEX idx_sc_camera_events_device_time ON sc_camera_events(device_id, detected_at DESC);
CREATE INDEX idx_sc_camera_events_type_level ON sc_camera_events(event_type, event_level);

CREATE TABLE sc_meter_readings (
    meter_reading_id BIGSERIAL PRIMARY KEY,
    device_id BIGINT NOT NULL REFERENCES sc_devices(device_id),
    meter_type VARCHAR(50) NOT NULL,
    reading_value NUMERIC(16,4) NOT NULL,
    reading_unit VARCHAR(30) NOT NULL,
    reading_period VARCHAR(30),
    captured_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    raw_payload JSONB
);
CREATE INDEX idx_sc_meter_readings_device_time ON sc_meter_readings(device_id, captured_at DESC);
CREATE INDEX idx_sc_meter_readings_type ON sc_meter_readings(meter_type);

CREATE TABLE sc_knowledge_documents (
    knowledge_document_id BIGSERIAL PRIMARY KEY,
    document_type VARCHAR(50) NOT NULL,
    document_title VARCHAR(255) NOT NULL,
    document_source VARCHAR(255),
    document_content TEXT NOT NULL,
    chunk_text TEXT,
    embedding_text TEXT,
    -- When pgvector is enabled, replace embedding_json with embedding vector(1536)
    embedding_json JSONB,
    document_status VARCHAR(30) NOT NULL DEFAULT 'active',
    created_by_user_id BIGINT REFERENCES sc_users(user_id),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_sc_knowledge_type_status ON sc_knowledge_documents(document_type, document_status);
CREATE INDEX idx_sc_knowledge_title ON sc_knowledge_documents(document_title);

CREATE TABLE sc_agent_tasks (
    agent_task_id BIGSERIAL PRIMARY KEY,
    requested_by_user_id BIGINT REFERENCES sc_users(user_id),
    site_id BIGINT REFERENCES sc_sites(site_id),
    zone_id BIGINT REFERENCES sc_zones(zone_id),
    goal_text TEXT NOT NULL,
    agent_status VARCHAR(30) NOT NULL DEFAULT 'planned',
    risk_level VARCHAR(30) DEFAULT 'unknown',
    plan_summary TEXT,
    rag_context TEXT,
    created_work_order_id BIGINT REFERENCES sc_work_orders(work_order_id),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_sc_agent_tasks_status ON sc_agent_tasks(agent_status);
CREATE INDEX idx_sc_agent_tasks_site_zone ON sc_agent_tasks(site_id, zone_id);

CREATE TABLE sc_agent_task_steps (
    agent_task_step_id BIGSERIAL PRIMARY KEY,
    agent_task_id BIGINT NOT NULL REFERENCES sc_agent_tasks(agent_task_id) ON DELETE CASCADE,
    step_order INT NOT NULL,
    step_name VARCHAR(150) NOT NULL,
    step_type VARCHAR(50) NOT NULL,
    step_status VARCHAR(30) NOT NULL DEFAULT 'pending',
    tool_name VARCHAR(100),
    input_payload JSONB,
    output_payload JSONB,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(agent_task_id, step_order)
);
CREATE INDEX idx_sc_agent_task_steps_task ON sc_agent_task_steps(agent_task_id);
CREATE INDEX idx_sc_agent_task_steps_status ON sc_agent_task_steps(step_status);

CREATE TABLE sc_audit_logs (
    audit_log_id BIGSERIAL PRIMARY KEY,
    user_id BIGINT REFERENCES sc_users(user_id),
    entity_name VARCHAR(100) NOT NULL,
    entity_pk VARCHAR(100),
    action_name VARCHAR(80) NOT NULL,
    action_summary TEXT,
    ip_address VARCHAR(80),
    request_payload JSONB,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_sc_audit_logs_entity ON sc_audit_logs(entity_name, entity_pk);
CREATE INDEX idx_sc_audit_logs_user_time ON sc_audit_logs(user_id, created_at DESC);
CREATE INDEX idx_sc_audit_logs_action ON sc_audit_logs(action_name);
