# Policy Matrix — Modes at a Glance

Single source of truth for mode-specific cadences. No ambiguity.

---

## Cadences

| Policy | fast | standard | pro |
|--------|------|----------|-----|
| **Compile check** | After changed C# batch | After changed C# feature | After meaningful changed C# checkpoint |
| **read_console** | After changed C# batch | After changed C# feature | After meaningful changed C# checkpoint |
| **Play Mode test** | After runtime/player-visible batch | After runtime/player-visible feature | After runtime/player-visible or high-risk checkpoint |
| **Before closing task** | Compile + console; Play Mode when cadence/visual change requires it | Play Mode + console during play + changed behavior checked | Play Mode + console during play + changed behavior checked + relevant tests |
| **Screenshot** | After batch | After every feature | After every feature |
| **Review screenshot** | After batch | After every feature | After every feature |
| **DEV_STATE update** | After meaningful batch | After meaningful feature checkpoint | After meaningful verified checkpoint |
| **DEV_LOG entry** | After meaningful batch | After meaningful feature checkpoint | After meaningful verified checkpoint |
| **Scene save** | When scene state changed | When scene state changed | When scene state changed and was verified |
| **Lead planning pass** | Optional brief | Required | Required |
| **Role subskills** | Optional | Required | Required |
| **Real subagents when available** | Optional | Required | Required |
| **User approval (plan)** | Auto (skip if auto_mode) | Only if ambiguous/high-impact | Only if ambiguous/high-impact |
| **User approval (feature)** | Never | Only if unclear/blocker | Only if unclear/blocker |
| **Auto-advance after Agent QA** | Yes | Yes, after QA + QA_AGENT pass or degraded report with follow-up task | Yes, after QA + QA_AGENT pass or degraded report with follow-up task |
| **QA retry limit** | Best effort | 2 attempts, then degraded report and continue | 2 attempts, then degraded report and continue |
| **Autotests** | Only for a named high-risk regression | Per task Test Value Gate | Risk-based focused tests; broader suite at milestones |
| **Profiler check** | Never (unless visible lag) | VERIFY phase (quick FPS) | After major systems + VERIFY |
| **Performance gate** | No | No | Yes (Mobile/WebGL: mandatory) |

---

## Code Quality

| Rule | fast | standard | pro |
|------|------|----------|-----|
| Namespaces | New project scripts stay in global namespace | New project scripts stay in global namespace | Follow existing project; for new projects use product/feature namespaces when useful |
| XML docs | Only public/non-obvious contracts | Only public/non-obvious contracts | Only public/non-obvious contracts |
| `//` comments | Explain non-obvious why only | Explain non-obvious why only | Explain non-obvious why only |
| Debug.Log | Actionable diagnostics only | Actionable diagnostics only | Actionable diagnostics only |
| Singleton | Follow existing architecture; add no new global by default | Same | Same |
| Interfaces | Only for a real boundary or multiple implementations | Same | Same |
| Tests | Named high-risk regression only | Per Test Value Gate | Risk-based, no quota |
| Events | Optional | Yes | Yes |
| Null-safe UI | Yes | Yes | Yes |
| TextMeshPro (never legacy) | Yes | Yes | Yes |
| SO for settings | Yes | Yes | Yes |
| SerializeField | Yes | Yes | Yes |
| Object Pool | When lifecycle frequency/profiling justifies it | Same | Same |
| Project structure | Required | Required | Required |
| Editor builders | Forbidden | Forbidden | Forbidden |

---

## Docs Requirements

| Doc file | fast | standard | pro |
|----------|------|----------|-----|
| DEV_CONFIG.md | REQUIRED | REQUIRED | REQUIRED |
| DEV_STATE.md | REQUIRED (brief) | REQUIRED (full) | REQUIRED (full) |
| DEV_PLAN.md | OPTIONAL | REQUIRED | REQUIRED |
| DEV_LOG/ | REQUIRED (brief) | REQUIRED | REQUIRED |
| AGENT_MEMORY.md | REQUIRED | REQUIRED | REQUIRED |
| GAME_DESIGN.md | OPTIONAL | REQUIRED | REQUIRED |
| ARCHITECTURE.md | No | OPTIONAL | REQUIRED |
| DEV_PROFILE.json | REQUIRED | REQUIRED | REQUIRED |
| Screenshots/ | REQUIRED | REQUIRED | REQUIRED |
| Features/FEAT-*.md | OPTIONAL | Required for tracked nontrivial features | Required for tracked nontrivial features |
| Tasks/TASK-*.md | OPTIONAL | One per meaningful implementation slice | One per meaningful implementation slice |
| QA/FEAT-*-qa.md | OPTIONAL | Required for tracked/risky features | Required for tracked/risky features |
| QA_AGENT/FEAT-*-qa.md | OPTIONAL | Only when an independent QA pass is used | Only when an independent QA pass is used |

---

## Feature Decomposition

| Mode | Features | Granularity | Example |
|------|----------|-------------|---------|
| fast | 2-4 | Big (1 feature = multiple mechanics) | "Player + movement", "Level + enemies" |
| standard | 4-8 | Medium (1 feature = 1 mechanic) | "Player movement", "Shooting", "Enemy AI" |
| pro | As needed | Small shippable behaviors, not artificial document count | "Combat → TurnSystem, Abilities, Effects" |

---

## Architecture

| Aspect | fast | standard | pro |
|--------|------|----------|-----|
| Entry style | Smallest project-fitting design | Feature-first when useful | Same architecture, stronger evidence |
| Communication | Direct references/events as needed | Same | Same; no mode-driven abstraction |
| Managers | Reuse existing ownership model | Same | Same |
| Data flow | SO/serialized data where authoring benefits | Same | Same |
| Project folders | Feature-owned typed structure | Feature-owned typed structure | Feature-owned typed structure |
| Input System | Preserve project stack | Preserve project stack | Preserve project stack |

`pro` is a verification and risk-management mode. It never authorizes Clean Architecture, DI,
ServiceLocator, mandatory interfaces, extra managers, or deeper folder layers without a concrete
project need.

---

## Priority Levels Used in SKILL.md

| Label | Meaning |
|-------|---------|
| `REQUIRED` | Must always be done. No exceptions. Failure = broken pipeline. |
| `DEFAULT` | Done by default. Agent can override with user consent. |
| `OPTIONAL` | Agent decides based on context. Skip if not needed. |
