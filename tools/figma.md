# Figma (export source only)

This file is a reference for input materials.  
**Direct Figma interaction via MCP is not used in this skill.**

## Rule

- UI in the project is done only via **UI Builder** (UXML/USS + UIDocument).
- If the user has design in Figma, the agent asks for **exported materials**:
  - screen screenshots,
  - icons/images (PNG/SVG),
  - sizes, spacing, typography, palette,
  - if available — code snippet from Dev Mode.
- Without exported materials the agent uses a basic UI Builder template and asks for minimal screen requirements.

## Minimum to request

1. Screen list (MainMenu, GameplayHUD, Pause, Settings, GameOver).
2. Size/orientation (e.g. 1920x1080 or 1080x1920).
3. Colors and fonts.
4. Button states (normal/hover/pressed/disabled) if important.
5. UI assets (icons, backgrounds, logo).

## What to bring into Unity

- Screen layout: UXML.
- Visual styles: USS.
- Theme params (colors, sizes, texts): ScriptableObject (`UiData`).

## When this is enough

- **Prototype/Fast:** 1–2 refs + base style.
- **Standard:** key screen mockups and consistent theme.
- **Pro:** full mockup/state set and UI kit.
