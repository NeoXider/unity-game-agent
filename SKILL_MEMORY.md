# Skill Memory

Persistent memory for universal improvements to the `unity-game` skill itself.

Use this file for repeatable lessons that should improve future Unity game-agent work across projects. Do not store project-specific decisions here; put those in the project's `Docs/AGENT_MEMORY.md`.

## Active Learnings

<!--
Append entries in this format:

### YYYY-MM-DD - category
- Trigger: What the agent noticed.
- Learning: Universal rule, approach, or anti-pattern.
- Apply when: When future agents should use it.
- Evidence: Verification, project context, or repeated observation.
- Skill impact: Which skill section/tool/template this improves.

Allowed categories: workflow, verification, reuse, unity-mcp, docs, qa, architecture, tools, anti-pattern.
-->


### 2026-05-27 - tools
- Trigger: setup_project.bat failed smoke tests despite static validation
- Learning: Windows batch scripts in the skill must keep CRLF line endings, escape parentheses inside IF blocks, and be smoke-tested for idempotency on a temp Unity-like project.
- Apply when: Adding or editing .bat/.cmd scripts or project bootstrap tooling
- Evidence: setup_project.bat initially failed in cmd.exe, then passed two-run bootstrap smoke test after CRLF, escaped parentheses, delayed expansion, and idempotent iteration-log fixes.
- Skill impact: Script validation and Windows bootstrap reliability
