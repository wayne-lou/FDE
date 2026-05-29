# SmartCity Agent Demo

Enterprise AI Agent + RAG + IoT Operations platform built with **Lucee CFML**, **PostgreSQL**, **pgvector-ready schema**, and a **Three.js operational dashboard**.

This project is designed as a portfolio / hackathon-grade ToB demo for Forward Deployed Engineering, enterprise AI deployment, industrial monitoring, and smart city operations.

## What it demonstrates

- IoT telemetry ingestion from smart city / industrial devices
- Device, alert, work order, inspection, maintenance, camera event, meter reading and knowledge document management
- RAG-ready knowledge base using PostgreSQL + vector embedding column
- AI Agent workflow that can inspect alerts, retrieve operational knowledge, generate action plans, create work orders, and write audit logs
- Role-based access control and audit logging structure
- Production-oriented concepts: fallback, observability, permissions, workflow state, event logs
- Three.js 3D operations screen for a visually strong demo

## Main Stack

- Backend: Lucee CFML
- Database: PostgreSQL database name `demo_sc`
- AI/RAG: OpenAI-compatible LLM API, pgvector-ready knowledge table, mock fallback mode included
- Frontend: Vanilla JS + Three.js
- Deployment: Docker Compose for PostgreSQL + Lucee

## Quick Start

See `docs/DEPLOYMENT.md`.

## Default Demo Login

This initial version does not enforce login in the UI yet, but the database includes users and roles for RBAC expansion.

## API Convention

Each API endpoint supports:

- `action=list`
- `action=get&id=...`
- `action=create`
- `action=update&id=...`
- `action=delete&id=...`

Example:

```bash
GET /api/devices.cfm?action=list
GET /api/devices.cfm?action=get&id=1
POST /api/devices.cfm?action=create
POST /api/devices.cfm?action=update&id=1
POST /api/devices.cfm?action=delete&id=1
```

## Important

This is an initial complete scaffold. It is intentionally simple enough to run and extend, but covers the full business surface area instead of only a toy chatbot.
