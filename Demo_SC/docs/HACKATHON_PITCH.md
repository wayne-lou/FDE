# Hackathon Pitch

## One-liner

OpsTwin AI is an enterprise AI Agent platform that turns smart city and industrial IoT signals into auditable operational workflows.

## Problem

Most AI demos stop at chat. Real enterprises need AI systems that can connect to live data, understand SOPs and policies, create work orders, enforce permissions, and leave audit trails.

## Solution

OpsTwin AI combines:

- IoT telemetry ingestion
- RAG-based knowledge retrieval
- AI Agent task planning
- Workflow execution
- Human-in-the-loop operations
- Audit logging
- 3D operational visualization

## Why it matters

Smart city and industrial customers operate under real production constraints: safety, compliance, uptime, and accountability. AI must be deployed as part of the operational system, not as a standalone chatbot.

## Demo Flow

1. Show 3D operations dashboard
2. Show open smoke/oil fume alerts
3. Run AI Agent investigation
4. Agent retrieves SOP/policy context
5. Agent creates an operational plan
6. Work order and audit log are created
7. Operator uses CRUD modules to manage follow-up

## Technical Differentiation

- Built with Lucee CFML + PostgreSQL, proving legacy-friendly enterprise AI deployment
- pgvector-ready RAG schema
- Complete operational data model
- Generic CRUD APIs for every module
- Production concepts included: permissions, audit, fallback, observability
