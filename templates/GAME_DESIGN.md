# Game design doc

Approved game outline. Agent uses this for implementation.

---

## General

| Param | Value |
|-------|--------|
| Name | [game name] |
| Genre | [genre] |
| Goal | [1–2 sentences] |
| Platform(s) | [PC / Mobile / ...] |
| Orientation | [portrait / landscape] |
| Style | [pixel / cartoon / ...] |

---

## Mechanics

1. [Mechanic 1] — [short desc]
2. [Mechanic 2] — [short desc]

---

## Screens / Scenes

| Screen | Description | Elements |
|--------|-------------|----------|
| MainMenu | Main menu | Play, Settings, Exit |
| Gameplay | Core gameplay | Player, enemies, HUD |
| GameOver | Game over | Score, Restart |

> **UI:** UI Builder only (UI Toolkit, UIDocument + UXML/USS). No Canvas/uGUI. See [tools/ui-builder.md](tools/ui-builder.md).

---

## Data (ScriptableObject)

| SO | Purpose | Key fields |
|----|---------|------------|
| PlayerData | Player params | speed, maxHealth, jumpForce |
| EnemyData | Enemies | health, speed, damage |
| GameSettings | Global | difficulty, ... |

---

## Dev stages

1. **Stage 1:** [name] — [what to do]
2. **Stage 2:** [name] — [what to do]

---

## Notes

[Constraints, future ideas.]
