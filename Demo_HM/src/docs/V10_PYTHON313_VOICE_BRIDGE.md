# HoloMemory AI v10 - Python 3.13 Voice Bridge

## Why this version exists

The original local XTTS service used Coqui TTS / XTTS-v2. On this server, Python is 3.13.9. `pip install TTS` fails because Coqui TTS versions require older Python versions, so this v10 service avoids TTS completely.

This version does **not** install Python 3.11 and does **not** touch system Python.

## What works on Python 3.13

The new `voice_clone_service/server.py` is standard-library only:

```bat
cd C:\inetpub\demos\demo_hm\voice_clone_service
python server.py --project-root C:\inetpub\demos\demo_hm
```

Health check:

```text
http://127.0.0.1:7866/health
```

## Real voice cloning path

Python 3.13 cannot run local Coqui XTTS in this setup. To make uploaded samples generate same-timbre speech, use a hosted voice-clone provider.

Supported in this v10 bridge:

- ElevenLabs Instant Voice Clone

ElevenLabs provides Instant Voice Cloning through its API and supports text-to-speech generation with cloned voices.

Set environment variables before starting the service:

```bat
set HM_VOICE_PROVIDER=elevenlabs
set ELEVENLABS_API_KEY=YOUR_KEY
cd C:\inetpub\demos\demo_hm\voice_clone_service
python server.py --project-root C:\inetpub\demos\demo_hm
```

Then the web app will:

1. Use the uploaded voice sample as speaker reference.
2. Create a provider voice id if none exists.
3. Generate an MP3 response in `uploads/generated_voice/<persona_id>/`.
4. Return `audio_url` to the front end.
5. Animate the avatar while audio plays.

## If no provider is configured

The service returns `success:false` with a clear explanation. The CF app then uses gender-safe browser TTS fallback. It will not pretend to have cloned the voice.

## Important note

One short sentence such as “今天天气很好” can be used as a demo reference sample, but better voice similarity usually requires more clean audio. ElevenLabs recommends short sample upload for Instant Voice Clone, but quality improves with cleaner and longer samples.
