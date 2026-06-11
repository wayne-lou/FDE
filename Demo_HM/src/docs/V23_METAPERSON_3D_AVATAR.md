# V23 MetaPerson 3D Avatar Integration

This version adds a real 3D avatar slot for HoloMemory AI.

Flow:

1. Persona Studio -> upload/select a clear front photo.
2. Paste MetaPerson App Client ID and App Client Secret.
3. Open Creator.
4. Generate From Active Photo, or use the embedded MetaPerson UI.
5. Export GLB.
6. Save Exported GLB.
7. Hologram Agent renders `model_url` with Three.js GLTFLoader.

Notes:

- MetaPerson web integration uses an iframe and JS messages.
- REST API is not used here because MetaPerson REST API is Enterprise-only.
- If GLB loading fails because of provider CORS or expired URL, manually download the GLB and host it under `/demo_hm/uploads/models/`, then paste that URL into `3D Avatar GLB URL` and click Save 3D Avatar.
