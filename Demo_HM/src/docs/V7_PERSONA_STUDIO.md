# v7 Persona Studio update

This version fixes the Persona Studio UX:

- One unified left menu across Hologram Agent, Persona Studio, and CRUD pages.
- Persona Studio now shows all personas in a list and uses one create/edit form.
- Create/edit fields include name, relationship, gender, birth date, persona type, status, speaking style, catchphrases, and bio.
- Photo and voice upload are part of the same persona management page.
- Multiple photo and voice files are supported by uploading each selected file to the persona asset endpoint.
- Live camera capture is supported through browser getUserMedia.
- Live voice recording is supported through MediaRecorder.
- Latest uploaded photo becomes the active avatar reference.
- Latest uploaded voice sample becomes the active local XTTS speaker reference.
- Male/female/pet gender is saved at persona level so fallback voice selection will not randomly use the wrong gender.

API added:

- `/api/persona_studio.cfm?action=list`
- `/api/persona_studio.cfm?action=save`
- `/api/persona_studio.cfm?action=upload`
- `/api/persona_studio.cfm?action=assets&persona_id=...`

If the database was already created before v7, the API creates `hm_persona_assets` automatically. You can also run the new tail section in `sql/001_schema.sql` manually.
