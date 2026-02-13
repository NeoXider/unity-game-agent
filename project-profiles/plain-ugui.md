# Project Profile: Plain uGUI

Use this preset when project uses Unity Canvas/uGUI and no external page framework is mandatory.

## Detection hints
- `Canvas`, `GraphicRaycaster`, `EventSystem` usage is primary.
- No hard dependency on third-party UI page managers.

## Default decisions
- UI stack: `uGUI`.
- Keep UI architecture simple: screen controllers + explicit references.
- Reuse Unity built-in components first.

## Mandatory checks before custom code
- Verify Unity built-in UI flow covers requirements.
- Record if/why extra package is required.
