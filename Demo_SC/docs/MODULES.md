# Functional Modules

## 1. User & Role Management
Tables: `sc_users`, `sc_roles`

## 2. Site & Zone Management
Tables: `sc_sites`, `sc_zones`

## 3. Device Management
Tables: `sc_devices`
Device types include smoke detector, oil fume monitor, temperature/humidity sensor, camera, electric meter, water meter.

## 4. Sensor Telemetry
Tables: `sc_sensor_readings`
Stores real-time IoT readings and quality status.

## 5. Alert Management
Tables: `sc_alerts`
Open, acknowledged, resolved status flow.

## 6. Work Order Management
Tables: `sc_work_orders`
Used by operators and AI Agent workflows.

## 7. Inspection Management
Tables: `sc_inspections`
Tracks field inspection plans and results.

## 8. Maintenance Records
Tables: `sc_maintenance_records`
Tracks device maintenance and repair history.

## 9. Camera Events
Tables: `sc_camera_events`
Stores AI vision or camera-triggered events.

## 10. Meter Readings
Tables: `sc_meter_readings`
Stores water/electricity readings.

## 11. Knowledge Base / RAG
Tables: `sc_knowledge_documents`
Stores SOP, policy, device manuals and enterprise knowledge.

## 12. AI Agent Tasks
Tables: `sc_agent_tasks`, `sc_agent_task_steps`
Tracks generated agent plans and execution steps.

## 13. Audit Logs
Tables: `sc_audit_logs`
Records operational actions for compliance and debugging.
