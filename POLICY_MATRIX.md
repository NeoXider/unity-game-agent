# Policy Matrix — Modes at a Glance

Single source of truth for mode-specific cadences. No ambiguity.

---

## Cadences

| Policy | fast | standard | pro |
|--------|------|----------|-----|
| **Compile check** | After every feature | After every feature | After every task |
| **read_console** | After every feature | After every feature | After every task |
| **Play Mode test** | After batch (2-4 features) | After every feature | After every task + feature |
| **Before closing task** | Compile + console; Play Mode when cadence/visual change requires it | Play Mode + console during play + changed behavior checked | Play Mode + console during play + changed behavior checked + relevant tests |
| **Screenshot** | After batch | After every feature | After every feature |
| **Review screenshot** | After batch | After every feature | After every feature |
| **DEV_STATE update** | After batch | After every feature | After every task |
| **DEV_LOG entry** | After batch | After every feature | After every task |
| **Scene save** | After every feature | After every feature | After every task |
| **Lead planning pass** | Optional brief | Required | Required |
| **Role subskills** | Optional | Required | Required |
| **Real subagents when available** | Optional | Required | Required |
| **User approval (plan)** | Auto (skip if auto_mode) | Only if ambiguous/high-impact | Only if ambiguous/high-impact |
| **User approval (feature)** | Never | Only if unclear/blocker | Only if unclear/blocker |
| **Auto-advance after Agent QA** | Yes | Yes, after QA + QA_AGENT pass or degraded report with follow-up task | Yes, after QA + QA_AGENT pass or degraded report with follow-up task |
| **QA retry limit** | Best effort | 2 attempts, then degraded report and continue | 2 attempts, then degraded report and continue |
| **Autotests** | No | No | Yes (after feature) |
| **Profiler check** | Never (unless visible lag) | VERIFY phase (quick FPS) | After major systems + VERIFY |
| **Performance gate** | No | No | Yes (Mobile/WebGL: mandatory) |

---

## Code Quality

| Rule | fast | standard | pro |
|------|------|----------|-----|
| Namespaces | No | No | Yes |
| XML docs | No | Public methods | All public |
| `//` comments | No obvious | No obvious | No obvious |
| Debug.Log | Key events | Plenty | Plenty + params |
| Singleton | OK | OK | DI / ServiceLocator |
| Interfaces | No | No | Yes |
| Tests | No | No | Yes (auto) |
| Events | Optional | Yes | Yes |
| Null-safe UI | Yes | Yes | Yes |
| TextMeshPro (never legacy) | Yes | Yes | Yes |
| SO for settings | Yes | Yes | Yes |
| SerializeField | Yes | Yes | Yes |
| Object Pool | No | If needed | Yes |

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
| Features/FEAT-*.md | OPTIONAL | REQUIRED | REQUIRED |
| Tasks/TASK-*.md | OPTIONAL | REQUIRED | REQUIRED |
| QA/FEAT-*-qa.md | OPTIONAL | REQUIRED | REQUIRED |
| QA_AGENT/FEAT-*-qa.md | OPTIONAL | REQUIRED | REQUIRED |

---

## Feature Decomposition

| Mode | Features | Granularity | Example |
|------|----------|-------------|---------|
| fast | 2-4 | Big (1 feature = multiple mechanics) | "Player + movement", "Level + enemies" |
| standard | 4-8 | Medium (1 feature = 1 mechanic) | "Player movement", "Shooting", "Enemy AI" |
| pro | 8+ | Small (1 feature = 1 task, grouped) | "Combat → TurnSystem, Abilities, Effects" |

---

## Architecture

| Aspect | fast | standard | pro |
|--------|------|----------|-----|
| Entry style | MonoBehaviour-first | Feature components | Services + DI |
| Communication | Direct references | Events / UnityEvents | Interfaces + Events |
| Managers | Singleton | Singleton OK | DI / ServiceLocator |
| Data flow | SO → SerializeField | SO → Events | SO → Services → Interfaces |
| Scene hierarchy | Flat groups | Feature nodes | Feature nodes + Runtime |
| Input System | Old / Both | Old / Both | New Input System |

---

## Priority Levels Used in SKILL.md

| Label | Meaning |
|-------|---------|
| `REQUIRED` | Must always be done. No exceptions. Failure = broken pipeline. |
| `DEFAULT` | Done by default. Agent can override with user consent. |
| `OPTIONAL` | Agent decides based on context. Skip if not needed. |
