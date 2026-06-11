# v14 Prepare Voice Button Fix

This patch is intentionally small. It fixes the Persona Studio button event binding and updates the CF voice API to call the Python bridge on `http://127.0.0.1:8010`.

Changed files only:
- `Application.cfc`
- `api/voice.cfm`
- `assets/js/persona_manager.js`

Python service files were not rewritten.
