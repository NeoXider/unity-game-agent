# C# / Code — recommendations

Recommendations for writing Unity game code. Style, patterns, and strictness depend on [dev mode](../MODE_CHOICE.md).

---

## General rules (all modes)

### Naming

- **Do not use game/project-specific names** in scripts, classes, SO, or file names (e.g. `TotalWar`, `MyGame`, `SuperPuzzle`). Use **role-based names**: `GameManager`, `MainMenuController`, `RewardPanel`, `UiData`, `ShopItemView` — so code and assets stay portable.
- **Namespaces:** do not use C# `namespace` (keep default/global scope) in **Prototype, Standard, Fast**. Use namespaces **only in Pro mode** — by system, e.g. `Game.Combat`, `Game.Inventory`, `Game.UI`. See [Code by mode](#code-by-mode) below.

| Element | Style | Example |
|---------|-------|--------|
| Classes, structs | PascalCase | `PlayerController`, `EnemyData` |
| Public methods | PascalCase | `TakeDamage()`, `Initialize()` |
| Public properties | PascalCase | `MaxHealth`, `MoveSpeed` |
| Private fields | camelCase with _ | `_currentHealth`, `_moveDirection` |
| Local variables | camelCase | `spawnPosition`, `enemyCount` |
| Constants | UPPER_SNAKE or PascalCase | `MAX_ENEMIES` or `MaxEnemies` |
| SO assets | PascalCase with suffix | `PlayerData`, `EnemyData_Goblin` |

### ScriptableObject (required in all modes)

**All settings and data in SO.** No hardcoding in MonoBehaviour.

```csharp
// SO — data
[CreateAssetMenu(fileName = "NewEnemyData", menuName = "GameData/EnemyData")]
public class EnemyData : ScriptableObject
{
    [Header("Stats")]
    public int health = 50;
    public float speed = 3f;
    public float damage = 10f;

    [Header("Visual")]
    public Sprite sprite;
    public Color tintColor = Color.white;
}

// MonoBehaviour — logic (references SO)
public class Enemy : MonoBehaviour
{
    [SerializeField] private EnemyData _data;

    private int _currentHealth;

    private void Start()
    {
        _currentHealth = _data.health;
        GetComponent<SpriteRenderer>().sprite = _data.sprite;
    }
}
```

### Basics

- **One script — one responsibility.** `PlayerMovement` separate from `PlayerHealth`.
- **SerializeField instead of public** for Inspector fields.
- **No Find/FindObjectOfType in Update** — cache in Start/Awake.
- **Null-check** when using references.
- **Logging** — volume depends on mode (see below).

### Async and deferred ops

**Recommendation for all modes:** use **UniTask** (Cysharp) for async/await in Unity — zero allocation, runs on PlayerLoop (no threads, WebGL ok), cancellation via `CancellationToken`, `UniTask.Delay`, `UniTask.Yield`, await for `AsyncOperation` and coroutines.

- **If UniTask is in project** — use for delays, scene/asset load, chains, cancellable timers. Do not duplicate with coroutines without reason.
- **If UniTask not installed** — before implementing async feature check if adding the package is simpler (UPM: `com.cysharp.unitasks` or [GitHub](https://github.com/Cysharp/UniTask)). Docs: [UniTask](https://github.com/Cysharp/UniTask#readme).
- **Coroutines** — ok for simple step delays (single `WaitForSeconds` chain) if UniTask not used. For complex (cancellation, multiple waits, async chains) prefer UniTask.

```csharp
// With UniTask (preferred)
await UniTask.Delay(TimeSpan.FromSeconds(1), cancellationToken: cts.Token);
await sceneLoader.LoadSceneAsync("Game").ToUniTask();
```

### Common packages

Before implementing a feature check: (1) Unity built-in; (2) packages already in project; (3) if needed — **search GitHub** (unity, mechanic, library, UPM) and **web** (tutorials, Unity Forums, Asset Store). Below — packages often used in Unity projects.

| Purpose | Package | Brief |
|---------|---------|-------|
| **Async/await** | **UniTask** (Cysharp) | Async, no alloc, cancellation, await AsyncOperation. UPM: `com.cysharp.unitasks` or Git. Recommended all modes. |
| **Tweens** | **DOTween** (Demigiant) | Fast tweens for transform, UI, values. Asset Store or [dotween.demigiant.com](https://dotween.demigiant.com/). Alternative: Animator/Animation. |
| **JSON** | **Newtonsoft.Json** | Serialization. Often already in Unity (2022+). NuGet or UPM. |
| **DI / IoC** | **VContainer**, **Zenject** | DI for large projects (Pro). Not required for prototype/small games. |
| **Localization** | **Unity Localization** | Package `com.unity.localization` — tables, keys, text swap. |

Do not install packages “just in case” — only for a task. **How to add** UniTask, DOTween, Newtonsoft.Json, Unity Localization: [libraries-setup.md](libraries-setup.md).

**Where to find ready-made:** GitHub (e.g. `unity 2d movement`, `unity inventory system`, `unity ui toolkit`); web — tutorials, [Unity Forums](https://forum.unity.com/), [Asset Store](https://assetstore.unity.com/).

### Unity UI (runtime creation)

Per this skill **all UI only via UI Builder** (UXML/USS, UIDocument), see [ui-builder.md](ui-builder.md). Dynamic elements via UI Toolkit API. Below — **legacy only** (e.g. Unity without UI Builder): programmatic Canvas. Do not use Canvas in normal workflow.

When creating UI on Canvas (exceptional cases only):

- **EventSystem:** scene must have `EventSystem` and `StandaloneInputModule` (or `InputSystemUIInputModule` with new Input System). If UI is created from code at start — ensure EventSystem exists or create it.
- **Buttons:** button GameObject must have `Image` (or other Graphic) and `Button`. Add `Button` before subscribing to `onClick`.

---

## Code by mode

### Prototype

**Goal:** it works = ok. Minimal abstraction, max speed.

**Allowed:**
- All logic in one script (if < 100 lines).
- Direct references via `[SerializeField]` without architecture.
- `GetComponent<>()` in Start without caching (if few objects).
- Magic numbers — **except settings** (those in SO).
- No XML docs (except non-obvious).
- **Singleton for managers** — freely (`GameManager.Instance`, `AudioManager.Instance`).

**Not allowed:**
- Hardcoded settings (speed, damage) — **only in SO**.
- `Update` without checks (endless pointless work).
- **Namespaces** — do not use; keep scripts in default (global) scope.

**Example (Prototype):** *(same code block as in original, comments in code can stay)*

### Standard

**Goal:** clean, readable code with sensible separation.

**Required:**
- Separate scripts per responsibility: `PlayerMovement`, `PlayerHealth`, `PlayerCombat`.
- `[SerializeField]` for all Inspector fields.
- Cache components in `Awake`/`Start`.
- Data in SO, references to SO via `[SerializeField]`.
- Prefabs for repeated objects.
- XML docs for public methods.

**Recommended:**
- Events / UnityEvents for cross-system communication.
- UniTask for async and delays; if no UniTask — coroutines for simple time-based ops.
- `[Header]`, `[Tooltip]`, `[Range]` on SO for Inspector.

**Not allowed:**
- **Namespaces** — do not use; keep scripts in default (global) scope.

### Fast

**Goal:** working component code, fast to write, easy to change.

**Required:**
- Components per responsibility (small ones may be combined).
- Data in SO.
- Cache components.

**Allowed:**
- Minimal XML docs (only non-obvious).
- Less strict separation (2 responsibilities in one script if related).
- **Singleton for managers** — freely.

**Not allowed:**
- Hardcoded settings.
- Copy-paste (prefer helper or base class).
- **Namespaces** — do not use; keep scripts in default (global) scope.

### Pro

**Goal:** scalable architecture, testable code, extensibility.

**Required:**
- **Interfaces** for key systems (`IDamageable`, `IInteractable`, `ISaveable`).
- **Services** via ServiceLocator or DI (Zenject / VContainer).
- **Data vs logic:** SO for data, MonoBehaviour for Unity binding, POCO for pure logic.
- **Events / Observer** for cross-system communication.
- **XML docs** for classes, public methods, public fields/properties, interfaces — **required**.
- **Autotests** (if not disabled): EditMode for logic, PlayMode for integration.
- **Namespace** by system (only mode where namespaces are used): e.g. `Game.Combat`, `Game.Inventory`, `Game.UI`.

**Comments — strict:** No plain `//` comments. Code self-documenting. Only allowed: `// TODO:`, `// HACK:` / `// WORKAROUND:`, `// NOTE:` (non-obvious). No “call method”, “increment counter” etc.

**Recommended:**
- State machine for complex behavior (AI, animation).
- Command pattern for actions (undo/redo, replay).
- Object pool for frequent create/destroy.
- Addressables instead of Resources.
- Assembly Definitions for compile speed.

---

## Common Unity patterns

### Singleton (managers)

*(Same code block — GameManager Awake pattern.)*

**Modes:** Prototype/Fast — Singleton freely. Standard — ok. Pro — prefer ServiceLocator/DI.

### Object Pool

*(Same code block — ObjectPool Get/Return.)*

**Modes:** Prototype — not needed. Standard — if objects spawn often. Fast/Pro — recommended.

---

## Logging (Debug.Log)

Volume depends on mode. Logs help debug and understand behavior.

| Mode | Logging | What to log |
|------|---------|-------------|
| **Prototype** | Minimal or none | Only when debugging. No logs is ok. |
| **Fast** | Moderate | Errors (`LogError`), warnings (`LogWarning`). `Log` as needed. |
| **Standard** | **Plenty (when relevant)** | Key events, state changes, errors, warnings. |
| **Pro** | **Plenty (when relevant)** | Key events, state changes, input params, errors, warnings. |

### Log format (all modes)

```
Debug.Log($"[Feature.Class.Method] comment");
```

- **Feature** — system/feature name (`Combat`, `Spawn`, `UI`, `Save`, `Inventory`, `Input`).
- **Class** — class name (`WaveSpawner`, `PlayerCombat`, `SaveSystem`).
- **Method** — method name (`StartNextWave`, `TakeDamage`, `Save`).
- **Comment** — what happened + params.

Use `$"..."` for readability. `Debug.LogError` for errors, `Debug.LogWarning` for warnings. **Do not log every frame in Update** (except when debugging). In Prototype same format, fewer logs (or none).

---

## Code quality checklist

| Check | Prototype | Standard | Fast | Pro |
|-------|-----------|----------|------|-----|
| Settings in SO | ✅ | ✅ | ✅ | ✅ |
| Single responsibility | — | ✅ | ≈ | ✅ |
| XML docs | — | ✅ public | Min | ✅ classes + public |
| Plain `//` comments | Allowed | Allowed | Allowed | ❌ No (except TODO/HACK/NOTE and SO) |
| Logging | Min / none | ✅ Plenty | Moderate | ✅ Plenty |
| SerializeField (not public) | — | ✅ | ✅ | ✅ |
| Cache components | — | ✅ | ✅ | ✅ |
| Interfaces | — | — | — | ✅ |
| Namespace | — | — | — | ✅ |
| Autotests | — | — | — | ✅ |
| Singleton for managers | ✅ Free | Ok | ✅ Free | ServiceLocator/DI |
| Events vs direct refs | — | ✅ | ≈ | ✅ |
| Object Pool (if needed) | — | ≈ | ✅ | ✅ |

### Allowed comments by mode

| Type | Prototype | Standard | Fast | Pro |
|------|-----------|----------|------|-----|
| XML (`/// <summary>`) | — | public methods | Min | Classes + all public |
| Plain `//` | Yes | Yes | Yes | **No** |
| `// TODO:` | Yes | Yes | Yes | Yes |
| `// HACK:` / `// WORKAROUND:` | Yes | Yes | Yes | Yes |
| `// NOTE:` | Yes | Yes | Yes | Yes |
| SO explanations (`[Tooltip]` / `//`) | Yes | Yes | Yes | Yes |
