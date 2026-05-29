# Deployment Guide

## 1. Requirements

- Docker Desktop
- PostgreSQL client optional
- Lucee 6 or compatible Lucee Docker image
- OpenAI-compatible API key optional

## 2. Start with Docker Compose

```bash
cd smartcity-agent-demo
cp .env.example .env
# edit .env if needed
cd docker
docker compose up -d
```

## 3. Initialize Database

The database name must be:

```text
demo_sc
```

Run:

```bash
psql -h localhost -U postgres -d demo_sc -f ../sql/001_schema.sql
psql -h localhost -U postgres -d demo_sc -f ../sql/002_seed_data.sql
```

Default password in docker compose is `postgres`.

## 4. Lucee Datasource

In Lucee Admin, create datasource:

```text
Name: demo_sc
Type: PostgreSQL
Host: postgres or localhost
Database: demo_sc
User: postgres
Password: postgres
Port: 5432
```

If running Lucee outside Docker, use host `localhost`.

## 5. Open the App

```text
http://localhost:8888/index.cfm
```

## 6. AI Agent / RAG Setup

The demo can run in mock mode without an API key.

To enable real LLM calls, set environment variables:

```bash
OPENAI_API_KEY=your_key
OPENAI_MODEL=gpt-4.1-mini
AI_MOCK_MODE=false
```

The current implementation provides:

- RAG retrieval scaffold from `sc_knowledge_documents`
- Agent plan generation endpoint
- Work order creation flow
- Audit logging
- Fallback mock response when LLM is unavailable

## 7. Production Hardening Next Steps

- Add real authentication middleware
- Add pgvector extension and embedding generation worker
- Add queue-based ingestion for high-volume telemetry
- Add rate limiting for AI endpoints
- Add Datadog / OpenTelemetry tracing
- Add row-level permission checks
- Add automated evaluation set for AI Agent responses

## AI Agent / RAG Runtime Modes

The demo supports two modes:

1. **Local agent demo mode**: default. Set `AI_MOCK_MODE=true`. The system still performs real database writes: RAG search, agent task creation, workflow step creation, audit log creation, and draft work order creation. It does not call an external model.
2. **OpenAI-backed mode**: set `AI_MOCK_MODE=false`, `OPENAI_API_KEY=<your key>`, and optionally `OPENAI_MODEL=gpt-4o-mini` or another supported chat model. The `AiAgentService.cfc` calls OpenAI Chat Completions, requests strict JSON, then persists the agent task, steps, audit log, and draft work order.

RAG in this version uses PostgreSQL text search over `sc_knowledge_documents` fields. The schema includes `embedding_json`; for production, enable `pgvector`, replace `embedding_json` with a vector column, and update `RagService.cfc` to rank by vector similarity.

## Subfolder Deployment

This version uses relative API and asset paths, so it can run under `/demo_sc/` or at site root without breaking `/api/...` calls.
