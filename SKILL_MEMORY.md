# Skill Memory

Persistent memory for universal improvements to the `unity-game-agent` skill itself.

Use this file for repeatable lessons that should improve future Unity game-agent work across projects. Do not store project-specific decisions here; put those in the project's `Docs/AGENT_MEMORY.md`.

## Keeping this file small

Memory is an inbox, not an archive. A lesson belongs in the skill document where agents will read it;
this file only holds what has not been placed yet.

- **Active Learnings** holds lessons not yet written into a skill document. Keep it at **10 entries or
  fewer**; `tools/append-skill-memory.ps1` warns when it grows past that.
- **Compact** when the warning fires, before a skill version release, or when two entries say the same
  thing: move each lesson into its target document (the entry's *Skill impact*), delete the entry, and
  add one line to the index below. Merge duplicates; drop lessons a later one made obsolete.
- An entry with no document to move to after two releases is either not universal (delete it) or needs
  a new document (write it).
- The skill is used on many machines and projects: never store machine paths, drive letters, local
  tool or skill names, keys, or one-project decisions. Describe the capability ("an installed
  generation skill", "ComfyUI with an audio model"), not where it lives on one computer.

## Promoted lessons (index)

Each line: when it was learned → where the rule lives now. Read the document, not this line.

| Learned | Lesson | Lives in |
|---|---|---|
| 2026-05 | `.bat` scripts: CRLF, escaped parentheses in `IF`, idempotency smoke test | `tools/validate-skill.ps1`, `tools/test-scripts.ps1` |
| 2026-07 | Renaming sliced sprites: rewrite `internalIDToNameTable` and `sprites[].name` | `project-profiles/plain-ugui.md` |
| 2026-08 | Capture through Device Simulator, never force `scaleFactor`; check PNG IHDR | `tools/ui-screenshot-truth.md` |
| 2026-08 | No visual defect without a number; normalise the mockup width first | `tools/ui-screenshot-truth.md` |
| 2026-08 | One editor, one driver; agents do not read PNGs back; watch progress externally | `tools/ui-screenshot-truth.md` |
| 2026-08 | One `CanvasScaler` contract (`Expand`) + guard test; top safe-area inset | `project-profiles/plain-ugui.md` |
| 2026-08 | Editor builders never own hand-authored scenes | `SKILL.md`, `tools/project-structure.md` |
| 2026-08 | Verify task-brief premises before delegating; agent findings are leads | `tools/playmode-qa-automation.md` |
| 2026-08 | Effects need captured frames across their lifetime | `tools/playmode-qa-automation.md` |
| 2026-08 | Bet-scaled economy values as multipliers of the bet | `tools/playmode-qa-automation.md` |
| 2026-08 | Removing a feature: sweep dangling overrides and owned objects | `tools/project-structure.md` |
| 2026-08 | UI acceptance document layout for multi-round human review | `tools/playmode-qa-automation.md` |
| 2026-08 | Standalone sprites import as Single | `project-profiles/plain-ugui.md` |
| 2026-08 | Feature-owned folder structure; tests out of player builds | `tools/project-structure.md` |
| 2026-08 | `pro` is evidence, not architecture or test quotas | `SKILL.md` (Test Value Gate), `modes/pro.md` |
| 2026-08 | Search credible external solutions after a local/Neo miss | `SKILL.md`, `tools/external-solution-reuse.md` |
| 2026-08 | Global namespace in `fast`/`standard` | `SKILL.md`, `tools/project-structure.md` |
| 2026-08 | Boot harness: restore logging, assert an interaction ran, scan the full log | `tools/playmode-qa-automation.md` |
| 2026-09 | 9-slice borders from the alpha silhouette (≥ 250), symmetric, per axis | `project-profiles/plain-ugui.md` |
| 2026-09 | Never copy `.dll.meta` across Unity versions (blocks all compilation, looks like an MCP failure) | `tools/libraries-setup.md` |
| 2026-09 | Buttons: raycast at the centre and press, never count listeners | `roles/qa.md` |
| 2026-09 | Audio: generate (skill / ComfyUI / API) → source → ask; never hand-synthesise | `tools/audio.md`, `roles/designer.md` |
| 2026-09 | Input System: legacy `Input` throws; Android Back via every keyboard + `wantsToQuit` | `tools/input-system.md` |
| 2026-09 | Player settings that differ from git are the owner's intent — never restore them | `tools/input-system.md`, `tools/mobile-build-and-size.md` |
| 2026-09 | ETC2 needs multiples of 4 → ASTC; atlases per screen, UV-effect sprites stay out | `tools/mobile-build-and-size.md`, `tools/shaders-and-vfx.md` |
| 2026-09 | Driving Input System input from QA despite editor focus | `tools/input-system.md` |
| 2026-09 | Dirty scene → modal dialog → MCP timeouts; no QA during the owner's play session | `tools/playmode-qa-automation.md` |
| 2026-09 | Map markers along a hand-traced road, verified by crops | `tools/meta-progress-map.md` |
| 2026-09 | Slice designer kits in Unity (Multiple + data provider), keep `spriteID` on rename; cut files only for inefficient sheets | `project-profiles/plain-ugui.md` |

## Active Learnings

<!--
Append entries in this format (tools/append-skill-memory.ps1 does it for you):

### YYYY-MM-DD - category
- Trigger: What the agent noticed.
- Learning: Universal rule, approach, or anti-pattern.
- Apply when: When future agents should use it.
- Evidence: Verification, project context, or repeated observation.
- Skill impact: Which skill section/tool/template this improves.

Allowed categories: workflow, verification, reuse, unity-mcp, docs, qa, architecture, tools, anti-pattern.
-->
