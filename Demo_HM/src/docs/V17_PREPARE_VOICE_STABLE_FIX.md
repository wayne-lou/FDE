# v17 Prepare Voice Stable Fix

Fixes:
- Prepare Voice Clone can be executed after selecting a persona that already has uploaded voice assets; no need to upload again.
- Removed duplicate click triggering that could call `voice.cfm` twice.
- `voice.cfm` now syncs the latest `hm_persona_assets` voice file into `hm_voice_profiles` before calling the provider bridge.
- `voice.cfm` now returns actionable JSON when the provider bridge returns HTTP 500 or non-JSON text, instead of silently falling back for clone-preparation requests.
- Python bridge files were not changed.

Expected test:
1. Keep Python bridge running on port 8010.
2. Select a persona with an uploaded voice sample.
3. Click Prepare Voice Clone.
4. Network should show exactly one POST to `/demo_hm/api/voice.cfm`.
5. If MiniMax fails, the Response JSON should include provider/bridge error details.
