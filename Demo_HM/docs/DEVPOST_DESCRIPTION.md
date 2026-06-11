# Devpost Submission Copy

## Project Name

HoloMemory AI

## Tagline

A memory-grounded digital human platform for families and future generations.

## Short Description

HoloMemory AI transforms consented family memories, voice recordings, photos, and personal stories into an evidence-grounded digital human. Family members can ask questions, hear a familiar cloned voice, see a 3D avatar respond, and inspect the memories used to produce each answer.

## Inspiration

Families preserve thousands of photos and recordings, but the wisdom and emotional context behind them are often difficult for future generations to access. We wanted to explore a more meaningful use of generative AI: not replacing a person or pretending to be them, but preserving approved stories, expressions, voice, and family knowledge in a transparent memory companion.

The central design question was: can a digital human remain emotionally engaging while still showing its evidence and refusing to invent family history?

## What It Does

HoloMemory AI lets a family build a digital persona from:

- identity and relationship information,
- photos and a MetaPerson 3D avatar,
- consented voice samples and MiniMax voice cloning,
- diaries, chats, photo notes, videos, and family stories,
- speaking style, familiar expressions, and personal advice.

When someone asks a question, the memory agent:

1. identifies the question's intent and focus,
2. retrieves relevant family-memory chunks,
3. scores and selects evidence,
4. performs grounding and safety checks,
5. composes a response in the persona's speaking style,
6. generates cloned speech,
7. animates the digital human,
8. displays the memories used in the answer.

Judge Mode exposes the complete reasoning path so the experience is emotionally compelling without becoming a black box.

## How We Built It

The web application uses Lucee CFML and JavaScript with PostgreSQL as the structured memory store.

- `RagService` builds a query profile and scores memory chunks using titles, summaries, transcripts, keywords, location, date, and emotional metadata.
- `AgentService` orchestrates retrieval, grounding, persona style, safety review, audit logging, voice output, and avatar state.
- MiniMax provides the cloned elder Mandarin voice through a local Python/Flask bridge.
- MetaPerson produces the GLB avatar, which is rendered with Three.js and GLTFLoader.
- Optional browser-side motion detection lets a wave trigger a subtle avatar reaction. Camera frames never leave the device.
- Dedicated Judge Mode, Retrieval Explorer, and Pipeline views explain the product and evidence flow.

The prototype currently runs on a Lucee/PostgreSQL deployment. Its production Google Cloud path uses Cloud Run for the web and voice services, Cloud SQL for PostgreSQL, Cloud Storage for consented media, Secret Manager for provider credentials, and Vertex AI embeddings for larger memory archives.

## Challenges

### Keeping the Digital Human Grounded

The most important challenge was preventing a warm, human-style response from becoming fabricated family history. We solved this by making retrieval evidence part of the agent contract and by returning uncertainty when no relevant memory exists.

### Voice and Avatar Integration

Voice cloning and 3D avatar creation use different providers and asynchronous workflows. We isolated provider calls behind adapters so the conversation flow can continue with safe fallbacks.

### Presenting Explainability Emotionally

Raw RAG scores and database rows are not meaningful to families or judges. We designed evidence cards and Judge Mode to communicate retrieval, relevance, and usage without making the experience feel like an admin dashboard.

### Respectful Design

A family digital human raises consent, privacy, impersonation, and emotional-safety concerns. The prototype clearly labels generated output, keeps evidence visible, and avoids positioning the system as a legal identity replacement.

## Accomplishments

- Built an end-to-end memory-grounded digital-human conversation.
- Connected family memories to visible response evidence.
- Integrated a cloned Mandarin elder voice.
- Rendered a full-body MetaPerson GLB avatar with Three.js.
- Added safety, grounding, audit, and anti-fabrication steps.
- Added local-only gesture interaction.
- Created screenshot-ready views that explain both retrieval and the digital-human creation pipeline.

## What We Learned

The emotional quality of a digital human does not come from visual realism alone. Trust comes from source quality, transparent retrieval, familiar voice details, and the ability to say "I do not remember."

We also learned that evidence should be designed as part of the user experience, not hidden in developer logs. Families need to understand why a response was produced and which memories shaped it.

## What's Next

- Package the Lucee application and Python bridge for Cloud Run.
- Move PostgreSQL to Cloud SQL.
- Store consented media in Cloud Storage with signed URLs.
- Manage provider credentials with Secret Manager.
- Add Vertex AI embeddings for multilingual semantic retrieval.
- Add family workspaces, authentication, consent renewal, deletion, and export.
- Support richer memory ingestion from scanned albums and recorded interviews.
- Conduct user research with families, archivists, and grief-support professionals.

## Built With

- Lucee CFML
- JavaScript
- Three.js
- PostgreSQL
- Python / Flask
- MiniMax
- MetaPerson Avatar SDK
- HTML / CSS

## Demo Links

- Live demo: [http://demos.e-xanke.com/demo_hm/](http://demos.e-xanke.com/demo_hm/)
- Source code: [https://github.com/wayne-lou/FDE/tree/main/Demo_HM](https://github.com/wayne-lou/FDE/tree/main/Demo_HM)

## Submission Notes

Use this file as the source for the Devpost project description. The README and architecture document belong in GitHub. For Devpost, paste the relevant sections into the project form and upload the strongest screenshots or architecture image directly to the submission gallery.
