# HoloMemory AI Demo (`/demo_hm/`)

A Lucee CF + PostgreSQL web MVP for a hologram-style memory companion.

## Core capability

- **Avatar**: browser hologram-style avatar that reacts to agent output.
- **Voice Clone**: browser TTS fallback plus provider fields for ElevenLabs / Cartesia / Azure / local clone.
- **Memory RAG**: memories are split into chunks, indexed with PostgreSQL full-text search, and retrieved as evidence.
- **Agent**: intent classification → RAG retrieval → persona style → grounding/safety → response → voice → avatar animation.

## Deploy

1. Create database: `demo_hm`.
2. Run SQL in order:
   - `sql/001_schema.sql`
   - `sql/002_seed.sql`
3. Create Lucee datasource named `demo_hm` pointing to PostgreSQL database `demo_hm`.
4. Copy the `demo_hm` folder to:
   - Windows/IIS: `C:\inetpub\demos\demo_hm\`
5. Open:
   - `/demo_hm/index.cfm`
   - `/demo_hm/admin/crud.cfm?module=personas`

## OpenAI / external AI extension

This MVP is designed to run without paid AI APIs. To connect real AI:

- Replace `services/AgentService.cfc::composeResponse()` with an OpenAI / Gemini / Claude call.
- Keep the same returned structure: answer, evidence, steps, voice, avatar.
- Add embeddings to `hm_memory_chunks.embedding_json` or replace full-text search with pgvector.
- Keep human-visible evidence so the answer is memory-grounded, not generic chat.

## Voice clone extension

- Store provider voice id in `hm_voice_profiles.provider_voice_id`.
- Use `sample_audio_url` for consented sample clips.
- Replace browser `speechSynthesis` in `assets/js/app.js` with provider TTS endpoint.
- Always label generated speech as AI-generated.

## Safety notes

This project should be positioned as a **memory companion**, not as impersonation. For production, require explicit consent, family permissions, audit logs, deletion rights, and clear AI-generated labels.

## v4 AI Core Notes

This version upgrades the demo from a fixed-flow mock into a more realistic AI product skeleton:

1. Memory RAG
   - `services/RagService.cfc` builds a query profile from the user's question.
   - It expands intent/focus terms, scores memory chunks, returns evidence, match reasons, grounding level, and excerpts.
   - Current default is local lexical/semantic scoring for easy Lucee deployment.
   - Production upgrade: replace `scoreLocal()` with pgvector + embedding search.

2. Agent
   - `services/AgentService.cfc` runs: intent detection -> RAG -> evidence grounding -> persona style -> safety review -> answer -> voice adapter -> avatar state.
   - It stores conversations, messages, retrievals, agent tasks, agent steps, and audit logs.

3. Voice Clone
   - Browser TTS is used as fallback.
   - `api/voice.cfm` documents and isolates provider integration points so API keys stay server-side.
   - Voice profile table already supports provider voice IDs and clone status.

4. Avatar
   - The hologram avatar now has speaking / thinking / warm / nostalgic / careful / uncertain states.
   - Mouth animation is linked to speech synthesis.
   - Avatar color and expression come from Agent output, not static UI.

5. Safety / Grounding
   - If evidence is weak or missing, the Agent refuses to fabricate.
   - Sensitive identity/authorization style requests are flagged as medium risk.

## v6 Voice Clone / Avatar Setup

Open Persona Studio:

`http://your-domain/demo_hm/admin/persona_manager.cfm`

Upload a photo and a voice sample for a persona. For a real clone, start the local voice service:

```bash
cd C:\inetpub\demos\demo_hm\voice_clone_service
pip install -r requirements.txt
python server.py --project-root C:\inetpub\demos\demo_hm
```

The front end will call `/demo_hm/api/voice.cfm`, which calls the local service. If it returns an audio URL, the avatar plays that generated voice. If not, it uses a gender-safe browser fallback.

## V12 MiniMax Mainland Setup

For China mainland MiniMax key, run the Python bridge with:

```bat
cd C:\inetpub\demos\demo_hm\voice_clone_service
set HM_VOICE_PROVIDER=minimax
set MINIMAX_REGION=cn
set MINIMAX_API_HOST=https://api.minimax.chat
set MINIMAX_API_KEY=YOUR_NEW_MINIMAX_KEY
set HM_PUBLIC_BASE_URL=http://demos.e-xanke.com/demo_hm
python server.py --project-root C:\inetpub\demos\demo_hm
```

If your MiniMax console exposes GroupId and API returns auth/account errors:

```bat
set MINIMAX_GROUP_ID=YOUR_GROUP_ID
```

Then check:

```text
http://127.0.0.1:7866/health
```
