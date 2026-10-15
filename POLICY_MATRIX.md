# Policy Matrix — Modes at a Glance

Single source of truth for mode-specific cadences. No ambiguity.

---

## Cadences

| Policy | fast | standard | pro |
|--------|------|----------|-----|
| **Compile check** | After changed C# batch | After changed C# feature | After meaningful changed C# checkpoint |
| **read_console** | After changed C# batch | After changed C# feature | After meaningful changed C# checkpoint |
| **Play Mode test** | After runtime/player-visible batch | After runtime/player-visible feature | After runtime/player-visible or high-risk checkpoint |
| **Before closing task** | Relevant compile/console; actual runtime/visual behavior when changed | Independent QA of changed behavior/contracts; runtime drive when changed | Same plus justified platform/integration checks |
| **Screenshot** | Visual/runtime-visible changes | Visual/runtime-visible changes | Visual/runtime-visible changes |
| **Review screenshot** | Each required capture | Each required capture | Each required capture |
| **DEV_STATE update** | After meaningful batch | After meaningful feature checkpoint | After meaningful verified checkpoint |
| **DEV_LOG entry** | After meaningful batch | After meaningful feature checkpoint | After meaningful verified checkpoint |
| **Scene save** | When scene state changed | When scene state changed | When scene state changed and was verified |
| **Lead planning pass** | Only for a planning gap | Only for a planning gap | Only for a planning gap |
| **Role subskills** | Only selected roles | Developer + QA; design/Lead only for gaps | Same |
| **Real subagents when available/allowed** | Optional | One Developer, second independent QA | Same; reuse agents through correction loop |
| **Parallel Unity workspaces** | Off | Opt-in | Default ON when 2+ Unity-bound tasks run concurrently |
| **Unity operator ownership** | One per workspace | One per workspace; independent workspaces may run concurrently | Same |
| **Tests / validation builds in parallel work** | Single workspace | Headless in a closed workspace; exit afterwards | Same; interactive Editors for scene/prefab/MCP authoring |
| **User approval (plan)** | Auto (skip if auto_mode) | Only if ambiguous/high-impact | Only if ambiguous/high-impact |
| **User approval (feature)** | Never | Only if unclear/blocker | Only if unclear/blocker |
| **Auto-advance after Agent QA** | After relevant checks pass | After required independent QA checks pass; blocked work stays unverified | Same |
| **QA retry limit** | At most 2 genuine failures per path | At most 2; concise blocker to Developer/operator | Same; unrelated safe work may continue |
| **Autotests** | Only for a named high-risk regression | Per task Test Value Gate | Risk-based focused tests; broader suite at milestones |
| **Profiler check** | Visible lag/performance task | Performance risk/claim | Performance risk/claim or release requirement |
| **Performance gate** | When required | When required | Actual affected target/release requirement |

---

## Code Quality

Parallel workspace isolation, resource gates, MCP routing and integration rules are in
[tools/parallel-editors.md](tools/parallel-editors.md). Every workspace has its own Library; shared-source
test clones prohibit asset edits/saves. Assign scene/prefab ownership and merge committed work after QA.

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

These are full-pipeline resources, not a bootstrap checklist for every edit. A direct tracked item
uses one existing/new work brief; no new GDD, log tree or duplicate QA records when sufficient inputs
exist. Quick Fix creates none. Preserve explicit project tracking and link existing records.

| Doc file | fast | standard | pro |
|----------|------|----------|-----|
| DEV_CONFIG.md | REQUIRED | REQUIRED | REQUIRED |
| DEV_STATE.md | Brief pipeline state | Brief pipeline state | Brief pipeline state |
| DEV_PLAN.md | OPTIONAL | REQUIRED | REQUIRED |
| DEV_LOG/ | REQUIRED (brief) | REQUIRED | REQUIRED |
| AGENT_MEMORY.md | REQUIRED | REQUIRED | REQUIRED |
| GAME_DESIGN.md | OPTIONAL | REQUIRED | REQUIRED |
| ARCHITECTURE.md | Affected boundary decision only | Same | Same |
| DEV_PROFILE.json | REQUIRED | REQUIRED | REQUIRED |
| Screenshots/ | Required captures only | Required captures only | Required captures only |
| Feature or Task brief | Optional | One canonical brief per work item | Same |
| Separate Tasks/TASK-*.md | Explicit expanded tracking | Explicit expanded tracking | Explicit expanded tracking |
| Separate QA/FEAT-*-qa.md | Explicit expanded tracking | Explicit expanded tracking | Explicit expanded tracking |
| QA_AGENT/FEAT-*-qa.md | Explicit duplicate request only | Independent QA normally owns a brief section | Same |

Developer performs relevant compile/check once before handoff. QA drives changed outcomes. Fixes
rerun failed/affected checks only; cite valid unchanged evidence with source revision/scope/environment.
Docs-only work does not call Unity. Full suite/build/large manifests need demonstrated blast radius,
release/integration context or explicit request; none is a per-edit default.

---

## Feature Decomposition

| Mode | Features | Granularity | Example |
|------|----------|-------------|---------|
| fast | As needed | Useful playable slices | "Player + movement", "Level + enemies" |
| standard | As needed | Shippable behaviors, no document quota | "Player movement", "Shooting", "Enemy AI" |
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
