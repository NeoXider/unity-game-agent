# Development Patterns

A **development pattern** is a reusable, opinionated way to build a *kind* of game on top of
the universal Unity Game Agent pipeline (`INTAKE -> PLAN -> BUILD -> VERIFY -> SHIP`). The pipeline
stays the same; a pattern fills it with concrete stack choices, scene skeletons, reuse maps,
golden rules, and anti-patterns for one family of projects.

Think of the orchestrator as the engine and a pattern as a swappable playbook. Patterns are
additive: new ones drop into this folder without touching the pipeline.

## Available patterns

| Pattern | Use for | Stack | File |
|---|---|---|---|
| `casual-neoxider` | Casual / hyper-casual / mobile games: match-3, merge, lotto/bingo, slots, dress-up, idle/clicker, arcade, puzzle | NeoxiderTools (`Neo.*`) + NeoxiderPages + DOTween, driven via Unity MCP | [casual-neoxider/pattern.md](casual-neoxider/pattern.md) |

When no pattern matches, run the universal pipeline directly with the relevant
`project-profiles/` (UI stack) and `tools/` references.

## How a pattern is selected

During Session Routing / INTAKE the orchestrator picks at most one pattern:

1. **Detect** — scan the project for the pattern's signals (packages, namespaces, scene shape,
   existing managers). A confident detection auto-selects the pattern.
2. **Match the request** — if the project is new/empty, match the user's described genre and stack
   against the pattern table above.
3. **Confirm only when ambiguous** — if detection is weak and the request is generic, ask; otherwise
   proceed with the detected/best-fit pattern (or none).

Record the chosen pattern in `Docs/DEV_PROFILE.json` (`"pattern": "<name>"` or `"none"`) and in
`Docs/AGENT_MEMORY.md`. A pattern's defaults override the universal defaults where they conflict;
the universal verification gate, preflight, and QA policy always still apply.

## Adding a new pattern

1. Create `patterns/<name>/pattern.md` as the entry playbook. Keep the entry file self-describing:
   when to use it, detection signals, default decisions, the build loop, golden rules,
   anti-patterns, and links to its own reference files.
2. Put deep references (manager tables, code snippets, scene skeletons) in sibling files under
   `patterns/<name>/`.
3. Add one row to the **Available patterns** table above.
4. Add the pattern to the **Development Patterns** section and Session Routing in `../SKILL.md`.
5. Reuse shared references (`../tools/`, `../project-profiles/`, `../mcp-commands.md`) instead of
   duplicating them; a pattern should encode *decisions and idioms*, not re-document the engine.
