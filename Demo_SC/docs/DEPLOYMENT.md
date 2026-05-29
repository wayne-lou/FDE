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
