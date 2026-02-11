# Ready prompts for AutoUnity

Request templates for common tasks when building Unity games with AI. Replace `[...]` with your values.

---

## Starting a new project

**Agent behavior from scratch:** first ask for **settings** and **game design**. Create all memory files **in Docs/** (Docs/DEV_CONFIG.md, Docs/GAME_DESIGN.md, Docs/DEV_STATE.md, Docs/DEV_PLAN.md, **Docs/AGENT_MEMORY.md** — required). Iteration log file name includes date and time (iteration-NN-YYYYMMDD-HHMM.md). Do not start without asking for settings and game design (anti-pattern). Do planning in **Plan mode**; after plan confirmation — implementation.

### Create game from scratch

```
Create a [genre] game: [short description].
Main mechanics: [mechanic 1], [mechanic 2], [mechanic 3].
Platform: [PC / Mobile / WebGL].
Art style: [2D pixel / 2D casual / 3D low-poly / ...].
```

**Example:**

```
Create a 2D platformer: character runs through level, collects coins, avoids traps.
Main mechanics: run, jump, collect items.
Platform: PC.
Art style: 2D pixel.
```

### Continue existing project

```
Project is already set up. Check Docs/DEV_CONFIG.md, Docs/DEV_STATE.md, Docs/AGENT_MEMORY.md and Docs/DEV_PLAN.md — continue from where we left off.
```

### Change / clarify mode

```
Switch dev mode to [Prototype / Standard / Fast / Pro]. Update Docs/DEV_CONFIG.md.
```

### Write to agent memory

```
Remember: [important info, preference, decision, convention]. Write to Docs/AGENT_MEMORY.md.
```

---

## Working with features

### Add new mechanic

```
Add mechanic [name]: [behavior description].
Settings (speed, damage, etc.) — in ScriptableObject.
```

**Example:**

```
Add dash mechanic: on Shift press character dashes 3 units forward with cooldown.
Settings (distance, cooldown, speed) — in ScriptableObject DashSettings.
```

### Create UI screen

```
Create UI screen [name]: [element description].
Texts and params — in ScriptableObject UiData.
```

**Example:**

```
Create main menu UI screen: buttons Play, Settings, Exit. Title with game name.
Texts — in ScriptableObject UiData.
```

### Save system

```
Add save system: [what to save].
Format: JSON. Path: Application.persistentDataPath.
```

---

## Asset generation (ComfyUI)

### Character sprite

```
Generate via ComfyUI a sprite [character description].
Style: [pixel / cartoon / realistic].
Size: [64x64 / 128x128 / 256x256].
Background: transparent.
```

**Example:**

```
Generate via ComfyUI a sprite of a knight in blue armor, side view.
Style: pixel. Size: 64x64. Background: transparent.
```

### Background / tiles

```
Generate via ComfyUI [level background / tile set].
Description: [description].
Style: [style]. Size: [size].
```

### UI icons

```
Generate via ComfyUI a set of UI icons: [list icons].
Style: [style]. Size: [32x32 / 48x48 / 64x64].
Background: transparent.
```

---

## Unity Editor (via MCP)

### Check state

```
Show current scene state and take a screenshot. Update Docs/DEV_STATE.md.
```

### Setup scene

```
Setup scene [name]: [what should be in the scene].
Use Unity MCP to create objects.
```

### Debug

```
Read Unity console logs. If there are errors — fix and check again.
```

---

## ScriptableObject

### Create SO for data

```
Create ScriptableObject [name] to store [data description].
Fields: [list fields with types].
Create asset in Assets/_source/Data/.
```

**Example:**

```
Create ScriptableObject EnemyData to store enemy parameters.
Fields: string enemyName, int health, float speed, float attackDamage, float attackCooldown.
Create asset in Assets/_source/Data/Enemies/.
```

### Update balance

```
Update params in SO [name]: [which fields to which values].
```

---

## Refactor and optimization

### Refactor

```
Refactor [file / system]: [what to improve].
Do not change public API without agreement.
```

### Optimize

```
Analyze performance of [system]. Suggest optimizations.
Priority: [draw calls / GC alloc / physics / loading].
```

---

## Useful combinations

### Full feature cycle (Standard mode)

```
Add feature [name]: [description].
1. Create SO for settings.
2. Implement logic.
3. Create UI (if needed).
4. Check in editor, take screenshot.
5. Update Docs/DEV_STATE (micro-plan, 📈 progress, blockers, screenshot) + Docs/DEV_PLAN + current iteration in Docs/DEV_LOG/ (file name with date and time: iteration-NN-YYYYMMDD-HHMM.md).
```

### Quick mechanic prototype

```
Quick prototype of [mechanic]: [description].
No UI, no polish. Settings in SO. Check it works.
```

---

> **Tip:** these prompts are a starting point. Combine and adapt for your project. Dev mode defines planning depth and checks.
