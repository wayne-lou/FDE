# HoloMemory AI v6 - Real Core Upgrade

This version adds a real product structure for Avatar + Voice Clone + Memory RAG + Agent.

## 1. Persona Studio
Open:

`/demo_hm/admin/persona_manager.cfm`

Use it to select a persona, upload:

- photo / avatar image
- voice sample audio, even one short sentence such as “今天天气很好”

The uploaded files are saved under:

`/demo_hm/uploads/personas/{persona_id}/`

The DB updates:

- `hm_personas.reference_photo_url`
- `hm_avatar_profiles.image_url`
- `hm_voice_profiles.sample_audio_url`
- `hm_voice_profiles.sample_audio_path`
- `hm_voice_profiles.voice_provider = local_xtts`
- `hm_voice_profiles.voice_clone_status = sample_uploaded`

## 2. Voice Clone
This version includes a local voice clone service under:

`/demo_hm/voice_clone_service/`

It uses XTTS-v2 zero-shot voice cloning. It does not require training a new model from scratch. The uploaded speaker sample is used as the reference voice.

Run:

```bash
cd C:\inetpub\demos\demo_hm\voice_clone_service
pip install -r requirements.txt
python server.py --project-root C:\inetpub\demos\demo_hm
```

Then the CF endpoint:

`/demo_hm/api/voice.cfm`

calls:

`http://127.0.0.1:7866/tts`

If the service succeeds, the page plays the generated audio. If it fails, the page falls back to browser TTS and clearly shows fallback mode.

## 3. Gender-safe fallback
If a real clone is not available:

- male persona uses male-preferred browser voice and lower pitch
- female persona uses female-preferred browser voice
- pet persona uses high/playful fallback

This prevents “grandfather using random female voice” when no clone engine is running.

## 4. Avatar
The avatar now uses the uploaded photo when available.

- uploaded photo is shown inside the hologram tube
- speaking animation is linked to audio playback
- if no photo exists, it falls back to the 3D hologram figure

## 5. Memory RAG + Agent
The Agent flow remains:

Intent detection → Memory retrieval → Evidence grounding → Persona style → Safety review → Voice synthesis → Avatar animation.

The important product behavior is:

- answer only from saved memory evidence
- if no evidence exists, say it does not remember
- voice uses persona-specific sample when local XTTS is running
- avatar uses persona-specific uploaded image

## 6. What is real vs configurable
Real in this package:

- persona management
- photo upload
- voice sample upload
- local XTTS voice clone service code
- CF voice endpoint integration
- gender-safe fallback
- avatar image binding
- memory evidence grounding

Requires local environment setup:

- Python model dependencies
- XTTS-v2 model download on first run
- enough CPU/GPU resources for audio generation

