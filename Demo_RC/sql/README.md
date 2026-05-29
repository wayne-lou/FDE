# RaceOps AI — Driver Operations FDE Demo

A Lucee CF + PostgreSQL demo for a single Forward Deployed Engineer embedded inside a racing team. It focuses on driver recovery, schedule load, wearable telemetry, logistics workflows, RAG knowledge retrieval, and human-reviewed AI agent actions.

Root path: `/demo_rc/`  
Database: `demo_rc`

## Deploy
1. Create PostgreSQL database `demo_rc`.
2. Run `sql/001_schema.sql`, then `sql/002_seed_data.sql`.
3. Create a Lucee datasource named `demo_rc` pointing to that database.
4. Copy the `demo_rc` folder to `C:\inetpub\demos\demo_rc`.
5. Open `/demo_rc/index.cfm`.

## AI / RAG
Default mode is local deterministic demo mode. To use OpenAI, set environment variables:

- `AI_MOCK_MODE=false`
- `OPENAI_API_KEY=...`
- `OPENAI_MODEL=gpt-4.1-mini`

The local agent still demonstrates the production workflow: wearable lookup, schedule density check, RAG retrieval, risk assessment, draft logistics task creation, audit logging, and human-in-the-loop approval.
