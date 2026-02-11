# Architecture by mode

Single reference for architecture level, scene hierarchy, and when bootstrap/DI is acceptable.

## General principles

- **Avoid bootstrap** unless for narrow technical use (diagnostics, hypothesis checks, separate infra scenario).
- For Prototype/Fast/Standard: prefer manual scene setup and explicit inspector references.
- Store all tunable data in ScriptableObject.

## Base hierarchy template (Prototype / Fast / Standard)

```text
SceneRoot
├── GameManager
│   ├── Core
│   ├── Features
│   │   ├── Feature_Player
│   │   ├── Feature_Enemies
│   │   └── Feature_Progression
│   └── UI
├── Environment
└── Runtime
```

Rules:
- Each feature lives under its own `Feature_*` node.
- `Environment` is separate from gameplay logic.
- `Runtime` — temporary objects, pools, spawn.

## Architecture levels by mode

### Prototype

- MonoBehaviour-first, minimal abstraction.
- Direct references between components allowed.
- Do not use ServiceLocator/DI.

### Fast

- Component-based, fewer “kitchen sink” scripts.
- Explicit references and simple composition.
- Do not use global ServiceLocator without clear reason.

### Standard

- Moderate separation into features/subsystems.
- MonoBehaviour + simple service classes, no extra infra.
- DI/LifetimeScope only when it clearly pays off.

### Pro

- Main logic in classes/services.
- MonoBehaviour mainly as view/entry points.
- DI/LifetimeScope allowed when justified.

## Complexity limiters

Before adding DI/ServiceLocator/bootstrap, answer “yes” to all:
1. It reduces complexity over 3+ features, not just the current task.
2. There is a repeated pattern that cannot be handled with components alone.
3. It does not slow prototyping/delivery for the chosen mode.

## Architecture escalation

Escalate in steps:
1. **Simple components** → MonoBehaviour + explicit inspector references.
2. **Service layer** → when repeated domain logic appears across 2+ features.
3. **DI/LifetimeScope** → only when the service layer is insufficient and composition/testability justify it.

Transition conditions:
- 1 → 2: duplicated business logic or hard to keep features coherent;
- 2 → 3: dependency explosion, need for explicit module composition, complex service lifecycle.

Before introducing DI/LifetimeScope/ServiceLocator **document** a short `why` in `Docs/ARCHITECTURE.md`:
- what problem;
- why the previous level was not enough;
- expected benefit;
- risks and maintenance cost.
