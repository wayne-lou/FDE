# V11 - MiniMax Voice Clone + Talking Head Avatar + Memory Agent

This version implements the actual product pipeline:

Photo -> Avatar profile -> D-ID talking head adapter
Voice sample -> MiniMax voice clone -> MiniMax T2A mp3
Memory -> RAG evidence -> grounded agent answer
Output -> cloned voice audio -> local avatar lip-sync, optional D-ID talking-head video

## Accounts / Keys required

### 1. MiniMax API
Go to MiniMax developer platform and create an API key.

Official docs:
- Voice Clone: https://platform.minimax.io/docs/api-reference/voice-cloning-clone
- Voice Clone guide: https://platform.minimax.io/docs/guides/speech-voice-clone
- T2A HTTP: https://platform.minimax.io/docs/api-reference/speech-t2a-http

You need:
- `MINIMAX_API_KEY`

MiniMax voice clone audio requirements from official docs:
- mp3 / m4a / wav
- at least 10 seconds, up to 5 minutes
- up to 20MB

### 2. D-ID API for Talking Head Avatar
Go to D-ID Studio and create an API key.

Official docs:
- Getting Started: https://docs.d-id.com/reference/get-started
- Create Talk: https://docs.d-id.com/reference/createtalk

You need:
- `D_ID_API_KEY`

D-ID requires public URLs for the uploaded photo and audio. Set:
- `HM_PUBLIC_BASE_URL=http://demos.e-xanke.com/demo_hm`

If D-ID key is missing, the app still uses local photo avatar + CSS lip-sync.

## Start bridge on Windows / Python 3.13

```bat
cd C:\inetpub\demos\demo_hm\voice_clone_service
set HM_VOICE_PROVIDER=minimax
set MINIMAX_API_KEY=your_minimax_key
set D_ID_API_KEY=your_did_basic_key
set HM_PUBLIC_BASE_URL=http://demos.e-xanke.com/demo_hm
python server.py --project-root C:\inetpub\demos\demo_hm
```

Health check:

```bat
curl http://127.0.0.1:7866/health
```

## Flow

1. Persona Studio: create a persona.
2. Upload at least one clean voice sample. MiniMax requires at least 10 seconds.
3. Upload a clear portrait photo.
4. Open Hologram Agent and ask a question.
5. Agent performs Memory RAG and produces an answer.
6. `/api/voice.cfm` calls Python bridge -> MiniMax clone/T2A -> returns mp3 URL.
7. `/api/avatar.cfm` calls Python bridge -> D-ID talk if configured.
8. Frontend plays audio and animates avatar.

## Important

This does not train a local model on the production server. The server remains Python 3.13 compatible. Real voice clone comes from MiniMax provider API.
