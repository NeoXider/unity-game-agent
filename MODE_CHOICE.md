# Choose dev mode

When starting a game from scratch the agent asks for **settings** (including the mode below) and **game design**; planning is done in **Plan mode**.

Mode affects outline size, stage detail, code style, when checks run, and state files (DEV_STATE / DEV_PLAN / DEV_LOG). **In all modes settings live in ScriptableObject** (NpcData, GameFightData, UiData, etc.) so you can change parameters without touching scene and code.

**Before choosing:** mode comparison, descriptions, and workflow diagrams — [MODE_DETAILS.md](MODE_DETAILS.md).

## Mode comparison

| Mode | Goal | Code style | Clarifying questions | Checks | Workflow |
|------|------|------------|----------------------|--------|----------|
| **Prototype** | Validate idea in a couple of hours | Hardcode, settings in SO | Before plan (min.) | At the end | Minimal outline → 2–3 big stages → files optional |
| **Standard** | Small complete game | Moderate | Before plan + before feature | Per feature | Short outline → short stages with checklist → STATE/PLAN/LOG |
| **Fast** | Quick to playable build | Components | Before plan (min.) | At the end | Outline + stages → big stages → STATE/PLAN brief |
| **Pro** | Long project with foundation | Architecture, tests | Before plan + before feature | Per task and feature; autotests default | Full outline → detailed stages → full STATE/PLAN/LOG |

## Mode details

- **Prototype** — [details](modes/prototype.md): minimal planning, checks at end, files optional.
- **Standard** — [details](modes/standard.md): small game, check per feature, moderate code style.
- **Fast** — [details](modes/fast.md): faster to result, several features per pass, checks at end.
- **Pro** — [details](modes/pro.md): full plan, checks per task and feature, autotests by default.

Each mode has **complexity limits** (screens/mechanics/scenes/iteration size) — see `modes/*`.

---

QA checklists depend on `Docs/DEV_CONFIG.md`: **QA per feature** and **final QA checklist** are configured separately.

**Tool recommendations** (Unity MCP, ComfyUI, UI Builder, code) depend on mode — [tools/index.md](tools/index.md).

---

**Reply with the mode name: Prototype, Standard, Fast, or Pro — to start.**
