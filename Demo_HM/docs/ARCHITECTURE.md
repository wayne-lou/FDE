# HoloMemory AI Architecture

## System Overview

HoloMemory AI is an evidence-grounded digital-human system. It separates memory retrieval, persona composition, safety review, voice generation, and avatar presentation so that every response can remain traceable to family-approved source material.

```mermaid
flowchart TB
    subgraph Browser["Browser Experience"]
        HOME["Hologram Agent"]
        JUDGE["Judge Mode"]
        EXPLORER["Memory Retrieval Explorer"]
        GESTURE["Local Gesture Detection"]
        THREE["Three.js Avatar Renderer"]
    end

    subgraph Web["Lucee CFML Application"]
        API["CFML API Endpoints"]
        AGENT["AgentService"]
        RAG["RagService"]
        SAFETY["Grounding + Safety Review"]
        GEMINI["GeminiService"]
        PERSONA["Grounded Response + Fallback"]
        AUDIT["Conversation + Audit Logging"]
    end

    subgraph Data["PostgreSQL"]
        PEOPLE[("Personas")]
        MEMORIES[("Memory Items")]
        CHUNKS[("Memory Chunks")]
        CONV[("Conversations + Retrievals")]
    end

    subgraph Media["Voice and Avatar"]
        BRIDGE["Python Voice Bridge"]
        MINIMAX["MiniMax Voice Clone"]
        META["MetaPerson Avatar SDK"]
    end

    HOME --> API
    GESTURE --> THREE
    API --> AGENT
    AGENT --> RAG
    RAG --> MEMORIES
    RAG --> CHUNKS
    AGENT --> PEOPLE
    AGENT --> SAFETY
    SAFETY --> GEMINI
    GEMINI --> PERSONA
    PERSONA --> AUDIT
    AUDIT --> CONV
    PERSONA --> BRIDGE
    BRIDGE --> MINIMAX
    PERSONA --> THREE
    META --> THREE
    API --> HOME
    RAG --> JUDGE
    RAG --> EXPLORER
```

## Grounded Response Sequence

```mermaid
sequenceDiagram
    participant F as Family Member
    participant UI as HoloMemory UI
    participant A as AgentService
    participant R as RagService
    participant DB as PostgreSQL
    participant G as Google Gemini API
    participant V as Voice Bridge
    participant H as 3D Avatar

    F->>UI: Ask a family question
    UI->>A: persona_id + question
    A->>R: Build query profile
    R->>DB: Load active memory chunks
    DB-->>R: Candidate evidence
    R-->>A: Ranked evidence + match reasons
    A->>A: Grounding and safety review
    A->>G: Question + persona style + retrieved evidence
    G-->>A: Grounded persona-styled response
    Note over A,G: Local grounded fallback if Gemini is unavailable
    A->>DB: Store conversation, retrievals, steps, audit
    A-->>UI: Answer + evidence + voice/avatar metadata
    UI->>V: Generate cloned speech
    V-->>UI: Audio URL
    UI->>H: Speaking and emotional state
    UI-->>F: Voice, avatar, answer, and visible evidence
```

## Core Data Relationships

```mermaid
erDiagram
    PERSONA ||--o{ MEMORY_ITEM : owns
    MEMORY_ITEM ||--o{ MEMORY_CHUNK : contains
    PERSONA ||--o{ VOICE_PROFILE : has
    PERSONA ||--o{ AVATAR_PROFILE : has
    PERSONA ||--o{ CONVERSATION : participates
    CONVERSATION ||--o{ MESSAGE : contains
    CONVERSATION ||--o{ RAG_RETRIEVAL : records
    AGENT_TASK ||--o{ AGENT_STEP : explains
```

## Component Responsibilities

### Browser

- Renders the cinematic product experience.
- Loads and animates GLB avatars with Three.js.
- Displays retrieved memories and evidence usage.
- Plays generated voice audio.
- Performs optional gesture detection locally without sending frames to the server.

### Lucee CFML

- Exposes the application API.
- Loads persona, voice, avatar, and consent metadata.
- Coordinates retrieval, safety, response composition, logging, and provider adapters.

### Retrieval and Grounding

- Builds an intent and focus profile from the question.
- Scores memory chunks across title, summary, transcript, keywords, location, date, and emotion.
- Returns evidence excerpts, match reasons, and grounding strength.
- Refuses to invent memories when evidence is absent or weak.

### Google Gemini

- Receives only the current question, persona speaking style, and retrieved memory evidence.
- Generates the concise natural-language response used for voice playback.
- Is instructed not to add unsupported family facts.
- Returns to a deterministic local grounded response if the API is unavailable.

### Voice and Avatar

- The Python bridge isolates MiniMax provider calls from the browser.
- MetaPerson creates exportable GLB avatars.
- Three.js renders the avatar and applies subtle visual states without skeletal retargeting.

## Google Cloud Integration and Production Topology

The current prototype calls the Google Gemini API for grounded response generation. It is portable to the following broader Google Cloud architecture:

```mermaid
flowchart LR
    USER["Family Browser"] --> LB["Cloud Load Balancing / HTTPS"]
    LB --> WEB["Cloud Run<br/>Lucee Web App"]
    WEB --> SQL[("Cloud SQL for PostgreSQL")]
    WEB --> STORAGE["Cloud Storage<br/>Consented Media"]
    WEB --> VOICE["Cloud Run<br/>Python Voice Bridge"]
    WEB --> GEMINI["Gemini API<br/>Grounded Responses"]
    WEB --> VERTEX["Vertex AI<br/>Embeddings Upgrade"]
    WEB --> SECRET["Secret Manager"]
    WEB --> LOG["Cloud Logging + Audit"]
```

Recommended production controls:

- Secret Manager for MiniMax and MetaPerson credentials.
- Cloud SQL private connectivity and encrypted backups.
- Signed Cloud Storage URLs for consented media.
- Identity-aware access controls for family workspaces.
- Vertex AI embeddings or vector search for larger memory archives.
- Cloud Logging for retrieval, consent, deletion, and safety audits.

## Trust Boundaries

1. Provider credentials remain server-side and are loaded from environment variables.
2. Family media must be consented and access-controlled.
3. Browser gesture frames remain on-device.
4. Every generated response carries grounding and AI-generated labels.
5. Production systems should support revocation, deletion, export, and family-level permissions.
