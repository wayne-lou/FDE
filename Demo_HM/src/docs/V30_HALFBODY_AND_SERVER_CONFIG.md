# V30

- Fix 3D GLB rendering from full-body T-pose to a cleaner half-body hologram camera/crop.
- Move MiniMax config option to `Application.cfc` via `application.minimaxApiKey`, `application.minimaxApiHost`, `application.minimaxRegion`, `application.minimaxGroupId`, `application.hmPublicBaseUrl`.
- Lucee passes MiniMax config to the local Python bridge, so uvicorn no longer needs `set MINIMAX_API_KEY=...` every time if `Application.cfc` is configured.
- Python still supports environment variables as fallback.
