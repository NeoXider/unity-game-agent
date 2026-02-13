# Project Profile: NeoxiderPages + NeoxiderTools

Use this preset only if corresponding packages/frameworks are detected in the project.

## Detection hints
- `NeoxiderPages` package/assets found.
- `Neo.*` namespaces/components are used in project code.

## Default decisions
- UI stack: existing `uGUI + NeoxiderPages` (no forced migration).
- Reuse-first priority:
  1. existing Neo frameworks/components,
  2. Unity built-in,
  3. additional packages if still needed.
- Scene/page flow should integrate with existing page manager/events.

## Mandatory checks before custom code
- Confirm feature cannot be solved by existing Neo components.
- Record reuse decision in plan/docs (Reuse Decision Matrix).

## Notes
- This is project-specific behavior and must not be applied globally.
