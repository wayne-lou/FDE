# V22 Avatar Visual Upgrade

This version improves the front-end hologram avatar display:

- Uploaded portrait is rendered as a larger 2.5D holographic bust instead of a small sticker on the body.
- The old moving scan line is disabled.
- The hologram tube, base, portrait depth, breathing/speaking motion, and lighting are improved.
- `api/avatar.cfm` now calls the same Python bridge port `8010` for future talking-head provider integration.

## What this version does NOT do

It does not create a true 3D mesh from one photo. True photo-to-talking-head or photo-to-3D avatar requires an external provider/API or a local model such as DeeVid/D-ID/LivePortrait/VASA-style models.

## What to prepare for the next provider step

1. A clear front-facing portrait photo.
2. A generated MiniMax cloned voice audio URL.
3. DeeVid/D-ID/other talking-head API key.
4. Public HTTP access to the uploaded image and generated audio.
