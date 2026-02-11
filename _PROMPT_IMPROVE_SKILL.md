# Prompt: skill improvement (current project)

**Temporary file** — used when configuring and refining the skill. After stabilization can be removed or moved to docs.

---

## Current project goal

Provide **MCP set, ready prompts, skills, automation (bat) and ComfyUI** for **creating autonomous Unity games with AI**.

The agent should be able to **autonomously** run game development: outline → plan → implementation → check → report, with minimal manual intervention. Everything that can be automated (folder creation, routine steps, checklists) should be prepared in the skill and scripts.

---

## What to improve: skill directory (SKILL_DIR)

**SKILL_DIR** = `c:\Git\AutoUnity\.cursor\skills\unity-game-agent\`

Improve the contents of this directory **as much as possible**:

1. **Rules and instructions** — so the agent with a clean context knows what to do, in what order, which files to read/update.
2. **Automation** — put routine work in `.bat` / scripts / checklists (folder creation is already in `setup_source_folders.bat`; add other routines).
3. **Reduce duplication and context** — do not repeat the same in multiple files; pull details via links (`reference.md`, `tools/*`, `modes/*`).
4. **Clear tool split:**
   - files/folders/code — via IDE/file tools or `.bat`;
   - Unity Editor (scene, objects, PlayMode, screenshots, console) — via Unity MCP.
5. **Dev modes** — choose mode before start, explicit workflow and checks per mode (prototype / standard / fast / pro).
6. **Project memory** — DEV_CONFIG, DEV_STATE, DEV_PLAN, AGENT_MEMORY, iteration logs; read order at start and update rules without overload.
7. **Ready prompts** — in PROMPTS.md and if needed separate files for typical scenarios (start game, continue, one feature, QA, etc.).

---

## Request to the agent

When working with this file:

1. **Restate and fix the goal** (MCP set + prompts + skills + automation + ComfyUI → autonomous Unity games).
2. **Review the whole skill directory** (`SKILL.md`, `reference.md`, `MODE_*.md`, `modes/*`, `tools/*`, `PROMPTS.md`, `setup_source_folders.bat`).
3. **Suggest improvements** per the points above:
   - what to add (new rules, steps, automation, prompts);
   - what to remove or shorten (duplicates, extra context);
   - what to restructure for clarity and token economy.
4. **Implement** improvements that do not require user decisions; put the rest in a “for approval” list.

Priority: so the agent with a **clean context** can immediately understand goal, mode, work order and state file updates, and so routine is automated where possible.
