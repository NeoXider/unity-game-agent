# Game design doc

Approved game outline. Agent uses this for implementation.

---

## General

| Param | Value |
|-------|--------|
| Name | [game name] |
| Genre | [genre] |
| Goal | [1-2 sentences] |
| Platform(s) | [PC / Mobile / ...] |
| Orientation | [portrait / landscape] |
| Style | [pixel / cartoon / ...] |

---

## Mechanics

1. [Mechanic 1] - [short desc]
2. [Mechanic 2] - [short desc]

---

## Screens / Scenes

| Screen | Description | Elements |
|--------|-------------|----------|
| MainMenu | Main menu | Play, Settings, Exit |
| Gameplay | Core gameplay | Player, enemies, HUD |
| GameOver | Game over | Score, Restart |

> **UI:** Follow `Docs/DEV_CONFIG.md` and existing project UI stack. Prefer UI Toolkit for new projects, uGUI + TextMeshPro for uGUI projects, or `no_ui` when the game does not need UI.

---

## Data (ScriptableObject)

| SO | Purpose | Key fields |
|----|---------|------------|
| PlayerData | Player params | speed, maxHealth, jumpForce |
| EnemyData | Enemies | health, speed, damage |
| GameSettings | Global | difficulty, ... |

---

## Dev stages

1. **Stage 1:** [name] - [what to do]
2. **Stage 2:** [name] - [what to do]

---

## Notes

[Constraints, future ideas.]
