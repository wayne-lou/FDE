# V8 Persona Studio fixes

- Left menu now has one Persona Studio entry; the old separate `personas` CRUD entry was removed to avoid split workflows.
- `admin/crud.cfm?module=personas` redirects to `admin/persona_manager.cfm`.
- Persona Studio is now the single place for creating/editing a persona, uploading multiple photos, uploading multiple voice samples, live camera capture, and live microphone recording.
- Normal persona management does not require Python.
- True same-voice cloned output requires starting the local XTTS Python service in `voice_clone_service/`. Without that service, the app falls back to gender-safe browser TTS and marks it as fallback.
