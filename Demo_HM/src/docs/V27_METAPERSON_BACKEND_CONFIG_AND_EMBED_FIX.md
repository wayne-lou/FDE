# V27 MetaPerson Backend Config + Embedded Creator Fix

Scope: Persona Studio / MetaPerson only. Python voice bridge is unchanged.

Changes:
- Removed MetaPerson Client ID / Secret input fields from the page.
- Persona Studio now reads MetaPerson credentials from server-side config via `api/persona_studio.cfm?action=metaperson_config`.
- Supports environment variables:
  - `METAPERSON_CLIENT_ID`
  - `METAPERSON_CLIENT_SECRET`
- Also supports `application.metapersonClientId` and `application.metapersonClientSecret` if set in Lucee application scope.
- MetaPerson Creator stays embedded in the page instead of full-screen modal.
- External buttons are the intended workflow: Generate From Active Photo → Export GLB → Save Exported GLB.
- UI parameters now try to hide MetaPerson's internal selfie/upload/sample-avatar controls when supported by the SDK.
- Export dialog is configured to close after export when supported.
- Save Exported GLB directly saves to `hm_avatar_profiles` through `save_avatar_model`.

Note: MetaPerson's own iframe may still show provider-controlled dialogs or controls; those cannot be fully removed from outside if the SDK does not honor the UI flags.
