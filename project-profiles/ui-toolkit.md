# Project Profile: UI Toolkit

Use this preset when project already uses UI Toolkit or user explicitly chooses it.

## Detection hints
- UXML/USS assets present.
- `UIDocument` components and UI Toolkit runtime code in project.

## Default decisions
- UI stack: `UI Toolkit`.
- Prefer UI Builder for layout authoring.
- Keep reusable templates/components for repeated blocks.

## Mandatory checks before custom code
- Verify existing UXML/USS structure can be extended.
- Record reuse decision in plan/docs (Reuse Decision Matrix).
