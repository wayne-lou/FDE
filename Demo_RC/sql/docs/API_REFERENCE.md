# API Reference

Each CRUD module supports:

- `GET /demo_rc/api/<module>.cfm?action=list`
- `GET /demo_rc/api/<module>.cfm?action=lookup`
- `GET /demo_rc/api/<module>.cfm?action=get&id=1`
- `POST /demo_rc/api/<module>.cfm?action=create`
- `POST /demo_rc/api/<module>.cfm?action=update&id=1`
- `POST /demo_rc/api/<module>.cfm?action=delete&id=1`

Agent:

- `POST /demo_rc/api/agent_plan.cfm`

Body:

```json
{"goal":"今天车手是不是疲劳过高？需要调整哪些后勤安排？","driver_id":1,"race_event_id":1,"user_id":1}
```
