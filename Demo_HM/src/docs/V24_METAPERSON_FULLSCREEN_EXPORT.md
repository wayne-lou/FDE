# V24 MetaPerson Full-screen Creator Fix

Changed Persona Studio MetaPerson Creator from a small embedded iframe to a full-screen modal.

## Flow
1. Select persona.
2. Confirm the persona has an active clear front photo.
3. Paste MetaPerson App Client ID and App Client Secret.
4. Click **Open Creator**.
5. Wait until the full-screen Creator is visible and authenticated.
6. Click **Generate From Active Photo** or use the Creator UI to upload/generate.
7. Wait until the 3D avatar is fully visible and controllable in the Creator.
8. Click **Export GLB**. If external JS message does not return a URL, use the Export/Download button inside MetaPerson Creator.
9. When the GLB URL fills into the `3D Avatar GLB URL` field, click **Save Exported GLB**.
10. Open Hologram Agent and verify the GLB loads in the hologram area.

No Python voice bridge files changed in this version.
