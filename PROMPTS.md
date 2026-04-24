# Ready Prompts

Action-oriented prompts for the Unity Game Agent. Replace `[...]` with your values.

---

## Start New Game

```
Create a [genre] game: [short description].
Mechanics: [mechanic 1], [mechanic 2], [mechanic 3].
Platform: [PC / Mobile / WebGL].
Mode: [fast / standard / pro].
```

**Example:**
```
Create a 2D platformer: character runs, collects coins, avoids traps.
Mechanics: run, jump, collect items.
Platform: PC. Mode: standard.
```

---

## Continue Project

```
Continue from where we left off. Read Docs/ and pick next task from DEV_PLAN.
```

---

## Direct Task (skip full cycle)

```
Direct task: [what to do]. No full onboarding needed.
```

**Example:**
```
Direct task: add dash mechanic. On Shift — dash 3 units forward with cooldown.
Settings in ScriptableObject DashSettings.
```

---

## Add Mechanic

```
Add [mechanic]: [behavior].
Settings in ScriptableObject [SOName].
```

---

## Create UI Screen

```
Create UI screen [name]: [elements].
Use [ui_toolkit / ugui]. Data in ScriptableObject UiData.
```

---

## Save System

```
Add save system: [what to save].
Format: JSON (Newtonsoft). Path: Application.persistentDataPath.
```

---

## Debug

```
Read Unity console. Fix errors. Verify in Play Mode. Screenshot.
```

---

## Full Feature Cycle

```
Add feature [name]: [description].
1. Create SO for settings.
2. Implement logic.
3. Create UI (if ui_mode != no_ui).
4. Play Mode test + screenshot.
5. Update DEV_STATE + DEV_LOG.
```

---

## Quick Prototype

```
Quick prototype: [mechanic description].
No UI, no polish. Settings in SO. Verify it works.
Mode: fast.
```

---

## Change Mode

```
Switch mode to [fast / standard / pro]. Update DEV_CONFIG and DEV_PROFILE.json.
```

---

## Agent Memory

```
Remember: [important decision/preference/convention].
Write to Docs/AGENT_MEMORY.md.
```

---

## Run Tests (Pro)

```
Run tests for [system]. Fix failures. Report results.
```

---

## Scene Setup via MCP

```
Setup scene [name]: [objects needed].
Use MCP batch_execute for efficiency.
```

---

## ScriptableObject

```
Create ScriptableObject [name]: [fields with types].
Create asset in [path].
```

**Example:**
```
Create ScriptableObject EnemyData:
  string enemyName, int health, float speed, float attackDamage.
Create asset in Assets/_source/Data/Enemies/.
```

---

> **Tip:** combine prompts for your workflow. Mode defines planning depth and checks.
