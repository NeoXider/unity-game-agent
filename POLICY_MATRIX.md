# Policy Matrix — Modes at a Glance

Single source of truth for mode-specific cadences. No ambiguity.

---

## Cadences

| Policy | fast | standard | pro |
|--------|------|----------|-----|
| **Compile check** | After every feature | After every feature | After every task |
| **read_console** | After every feature | After every feature | After every task |
| **Play Mode test** | After batch (2-4 features) | After every feature | After every task + feature |
| **Screenshot** | After batch | After every feature | After every feature |
| **Review screenshot** | After batch | After every feature | After every feature |
| **DEV_STATE update** | After batch | After every feature | After every task |
| **DEV_LOG entry** | After batch | After every feature | After every task |
| **Scene save** | After every feature | After every feature | After every task |
| **User approval (plan)** | Auto (skip if auto_mode) | Required | Required |
| **User approval (feature)** | Never | If unclear | If unclear |
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
