# V25 MetaPerson Fullscreen Force Fix

- Forces the MetaPerson iframe wrapper to be appended to document.body.
- Applies inline fixed-position modal styles to avoid cached CSS/layout issues.
- Retains existing MetaPerson iframe flow and GLB save fields.
- No Python files changed.

Steps:
1. Hard refresh Persona Studio.
2. Select persona.
3. Click Open Creator.
4. Full-screen iframe should cover the page.
5. Click Generate From Active Photo.
6. Wait until the 3D avatar appears and can rotate.
7. Click Export GLB.
8. If the GLB URL fills the field, click Save Exported GLB.
