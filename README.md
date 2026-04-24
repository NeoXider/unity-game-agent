# Unity Game Agent

**An autonomous agent that builds Unity games from idea to playable build — with a strict pipeline, MCP integration, and sub-agent architecture.**

> **Repository description:** Cursor skill: autonomous Unity game development. Pipeline: INTAKE → PLAN → BUILD → VERIFY → SHIP. Modes: fast / standard / pro. Full CoplayDev/unity-mcp integration (42+ tools).

---

## What it does

The agent acts as a **game developer** — asks for game design, locks in a plan, implements step by step, verifies in Play Mode, and delivers a tested build.

- **Fast mode** — prototype or playable build in hours
- **Standard mode** — small complete game with quality checks per feature
- **Pro mode** — scalable project with architecture, tests, and full documentation

One pipeline for everything: **INTAKE → PLAN → BUILD → VERIFY → SHIP**.

---

## What's inside

| File | Description |
|------|-------------|
| **SKILL.md** | Main file: pipeline, rules, modes, UI strategy, code rules, sub-agent architecture |
| **mcp-commands.md** | Full catalog of 42+ CoplayDev/unity-mcp tools with examples |
| **reference.md** | Templates for project docs (DEV_STATE, DEV_PLAN, etc.) and doc rules |
| **PROMPTS.md** | Ready-made prompts for common tasks |
| **modes/** | Mode-specific rules: fast.md, standard.md, pro.md |
| **tools/** | Code rules (code-writing.md), core mechanics, library setup |
| **templates/** | Full doc templates for project Docs/ folder |
| **project-profiles/** | Project-specific presets (Neoxider, uGUI, UI Toolkit) |
| **setup_project.bat** | Manual bootstrap: creates Docs/, _source/, all templates |

---

## Key features

- **CoplayDev/unity-mcp** — 42+ MCP tools for full Unity Editor control
- **Sub-agent architecture** — orchestrator delegates to coding/QA/report agents, verifies results
- **Strict pipeline** — compile check, Play Mode test, screenshot review, doc update before proceeding
- **UI strategy** — UI Toolkit (default), uGUI + TextMeshPro, or NoUI (null-safe stubs)
- **Constant reporting** — DEV_STATE and screenshots updated after every feature
- **Reuse-first** — check existing packages/GitHub before coding from scratch

---

## How to use

1. **Add the skill** — copy this folder to `.cursor/skills/` in your project
2. **Install MCP** — `com.coplaydev.unity-mcp` in Unity Package Manager
3. **Start server** — Window → MCP for Unity → Start Server
4. **Tell the agent** — describe your game, pick a mode, and let it build

---

## MCP Package

**Package:** `com.coplaydev.unity-mcp`  
**Install URL:** `https://github.com/CoplayDev/unity-mcp.git?path=/MCPForUnity`

This is the same MCP used in the Neoxider project and provides 42+ tools for scene control, script management, physics, animation, build, profiling, and more.

---

## License

Use in your projects. Improvements welcome via issues and PRs.
