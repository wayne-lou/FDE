# V16 Persona Studio JS Fix

Only front-end Persona Studio click/upload handling was changed.

- Replaced unsafe DOM id global references such as `persona_id.value` with explicit `document.getElementById(...)` helpers.
- Fixed `Upload Assets` showing `Select a persona first` even after a persona was selected.
- Fixed `Prepare Voice Clone` click binding with inline + JS fallback.
- Bumped script cache version to `persona_manager.js?v=16`.
- Python voice bridge files were not changed.
