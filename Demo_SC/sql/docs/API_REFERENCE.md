# API Reference

All API responses are JSON.

## CRUD Endpoints

| Module | Endpoint | Primary Key |
|---|---|---|
| Users | `/api/users.cfm` | `user_id` |
| Roles | `/api/roles.cfm` | `role_id` |
| Sites | `/api/sites.cfm` | `site_id` |
| Zones | `/api/zones.cfm` | `zone_id` |
| Devices | `/api/devices.cfm` | `device_id` |
| Sensor Readings | `/api/sensor_readings.cfm` | `reading_id` |
| Alerts | `/api/alerts.cfm` | `alert_id` |
| Work Orders | `/api/work_orders.cfm` | `work_order_id` |
| Inspections | `/api/inspections.cfm` | `inspection_id` |
| Maintenance Records | `/api/maintenance_records.cfm` | `maintenance_id` |
| Camera Events | `/api/camera_events.cfm` | `camera_event_id` |
| Meter Readings | `/api/meter_readings.cfm` | `meter_reading_id` |
| Knowledge Documents | `/api/knowledge_documents.cfm` | `knowledge_document_id` |
| Agent Tasks | `/api/agent_tasks.cfm` | `agent_task_id` |
| Agent Task Steps | `/api/agent_task_steps.cfm` | `agent_task_step_id` |
| Audit Logs | `/api/audit_logs.cfm` | `audit_log_id` |

## AI Endpoints

### Agent Plan

```http
POST /api/agent_plan.cfm
Content-Type: application/json
```

Body:

```json
{
  "goal": "Investigate repeated smoke detector alerts in Building A Floor 3",
  "site_id": 1,
  "zone_id": 2,
  "user_id": 1
}
```

### RAG Search

```http
POST /api/rag_search.cfm
Content-Type: application/json
```

Body:

```json
{
  "query": "What should we do when a smoke detector reports repeated offline events?",
  "limit": 5
}
```
