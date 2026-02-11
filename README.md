# Unity Game Agent

**An agent that drives Unity game development from idea to playable build — without chaos, with a clear plan and checks.**

> **Repository description (GitHub/GitLab):** Cursor skill: agent-driven Unity game development in stages (sketch → plan → implement → verify). Modes: prototype, standard, fast, pro.

---

## Why this exists

Want the AI to act like a developer — ask for settings and game design, lock in a plan, implement step by step, and report back — instead of just dumping code?  
**Unity Game Agent** is a Cursor skill that turns the agent into a predictable partner for making games: with stages, modes, and a single project “memory” (DEV_CONFIG, GAME_DESIGN, DEV_PLAN, DEV_STATE, iteration logs).

- **Prototype in a couple of hours** — minimal planning, quick idea validation.  
- **A small, coherent game** — standard mode with checks on every feature.  
- **Fast to a playable build** — big milestones, checks at the end.  
- **Serious project** — full plan, tests, architecture.

One loop for everything: **sketch → plan → implement → verify → report**. Planning happens in Plan mode so you see and approve the plan before any code.

---

## What’s inside

| Part | Description |
|------|-------------|
| **SKILL.md** | Main skill file: cycle, rules, links to the rest. |
| **reference.md** | Templates for DEV_CONFIG, GAME_DESIGN, UI_BRIEF, DEV_STATE, DEV_PLAN and rules for project “memory”. |
| **MODE_CHOICE.md** / **MODE_DETAILS.md** | Mode selection (Prototype / Standard / Fast / Pro) and details. |
| **modes/** | Rules per mode: plan depth, code style, checks. |
| **tools/** | Unity MCP, ComfyUI, UI Builder, architecture-by-mode, code, editor — when to use what. |
| **PROMPTS.md** | Ready-made prompts: start game, features, continue, QA. |
| **setup_source_folders.bat** | Project folder structure automation. |

Settings and data live in **ScriptableObjects**. On start the agent asks for **settings** (mode, platform, orientation, style, design references, ComfyUI, etc.) and **game design**. If MCP aren’t available, it asks: help set up or start without them.

---

## How to use

1. **Add the skill** in Cursor (e.g. copy this folder into your project’s `.cursor/skills/` or point to this repo).  
2. **Open your Unity project** and, if needed, configure MCP (Unity MCP, ComfyUI) in `.cursor/mcp.json`.  
3. **Tell the agent** you want to make a game — it will ask for settings and game design, then propose a plan in Plan mode. After you confirm, implementation runs by stages.

Detailed setup and scenarios: [SKILL.md](SKILL.md) and [PROMPTS.md](PROMPTS.md).

---

## Who it’s for

- **Indies and jam participants** — quick prototype or workflow for a small game.  
- **Teams** — shared cycle and state files (DEV_*, logs) so the agent and humans stay on the same page.  
- **Learning** — clear stages and modes instead of “write everything at once”.

---

## License and contributing

Use it in your projects. Improvements and ideas welcome via issues and pull requests.

**Unity Game Agent** — so the agent keeps the thread and you keep control over how the game is made.
