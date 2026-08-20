# C# / Code — Detailed Reference

Extended code rules. Core rules are in [SKILL.md](../SKILL.md) → "Code Rules". This file has details and examples.

---

## ScriptableObject Patterns

### Basic SO
```csharp
[CreateAssetMenu(fileName = "NewEnemyData", menuName = "GameData/EnemyData")]
public sealed class EnemyData : ScriptableObject
{
    [Header("Stats")]
    public int health = 50;
    public float speed = 3f;
    public float damage = 10f;

    [Header("Visual")]
    public Sprite sprite;
    public Color tintColor = Color.white;
}
```

### MonoBehaviour referencing SO
```csharp
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

---

## Singleton Pattern (fast/standard modes)

```csharp
public class GameManager : MonoBehaviour
{
    public static GameManager Instance { get; private set; }

    private void Awake()
    {
        if (Instance != null && Instance != this) { Destroy(gameObject); return; }
        Instance = this;
        DontDestroyOnLoad(gameObject);
    }
}
```

**Usage:** keep an existing singleton when it is already the project's ownership model. Do not add a
new global casually, and do not replace one with DI/ServiceLocator merely because the mode is `pro`.

---

## Object Pool Pattern

```csharp
public class ObjectPool : MonoBehaviour
{
    [SerializeField] private GameObject _prefab;
    [SerializeField] private int _initialSize = 10;
    private readonly Queue<GameObject> _pool = new();

    private void Start()
    {
        for (int i = 0; i < _initialSize; i++)
        {
            var obj = Instantiate(_prefab, transform);
            obj.SetActive(false);
            _pool.Enqueue(obj);
        }
    }

    public GameObject Get(Vector3 position)
    {
        var obj = _pool.Count > 0 ? _pool.Dequeue() : Instantiate(_prefab, transform);
        obj.transform.position = position;
        obj.SetActive(true);
        return obj;
    }

    public void Return(GameObject obj)
    {
        obj.SetActive(false);
        _pool.Enqueue(obj);
    }
}
```

---

## UniTask Examples

```csharp
using Cysharp.Threading.Tasks;
using System;
using System.Threading;

public class TimerExample : MonoBehaviour
{
    private CancellationTokenSource _cts;

    private async UniTaskVoid StartCountdown()
    {
        _cts = new CancellationTokenSource();
        await UniTask.Delay(TimeSpan.FromSeconds(3), cancellationToken: _cts.Token);
        Debug.Log("[Timer.TimerExample.StartCountdown] Countdown finished");
    }

    private void OnDestroy() => _cts?.Cancel();
}
```

---

## TextMeshPro (MANDATORY — never legacy Text)

### uGUI (Canvas)
```csharp
using TMPro;

public class ScoreDisplay : MonoBehaviour
{
    [SerializeField] private TMP_Text _scoreText;

    public void UpdateScore(int score)
    {
        if (_scoreText != null)
            _scoreText.text = $"Score: {score}";
    }
}
```

### Null-safe stubs (NoUI mode)
```csharp
public class GameHUD : MonoBehaviour
{
    [SerializeField] private TMP_Text _healthText;
    [SerializeField] private TMP_Text _scoreText;

    public void UpdateHealth(int hp)
    {
        if (_healthText != null) _healthText.text = $"HP: {hp}";
    }

    public void UpdateScore(int score)
    {
        if (_scoreText != null) _scoreText.text = $"Score: {score}";
    }
}
```

---

## Comments And Logging

Code should not narrate obvious operations. Comments are appropriate for non-obvious intent,
constraints, platform quirks, algorithms, and workarounds. Runtime logs are not comments and must not
be added to explain code.

Use logs only when the information is actionable during play, QA, or diagnosis:

```csharp
Debug.Log($"[Spawn.WaveSpawner.StartNextWave] Wave {wave}: {count} enemies");
Debug.LogError($"[Save.SaveSystem.Load] File not found: {path}");
Debug.LogWarning($"[Combat.Health.TakeDamage] Damage={amount} but HP already 0");
```

- `Debug.LogError` for failures requiring action;
- `Debug.LogWarning` for recoverable suspicious state;
- `Debug.Log` only for intentional diagnostics that are not emitted every frame.

Never use log volume as a quality target.

---

## Serialized-Data Traps

Each of these compiles, reads correctly, and is wrong at runtime.

### Changing a field's default does not change existing data

Serialized values live in the scene, prefab, and asset files. Editing the initializer in C# affects
only objects created **after** the change. Rescaling a range (`intensity` from `0..5` to `0..1`) or
changing a default colour therefore leaves every already-authored asset on the old value — a flash
effect kept an intensity of `3` and a pink tint long after the code said otherwise.

**Rule: any change to a field's meaning, unit, range, or default needs an explicit migration pass over
the existing scenes/prefabs/SO assets, plus a report of how many assets were touched.** If migration
is out of scope, keep the old range and add a new field instead.

### `Ease` value `0` is `Ease.Unset`, not `Ease.Linear`

A serialized `Ease` field defaults to `0`, and `0` is `Ease.Unset` — DOTween silently substitutes its
own global default (`OutQuad`). Every "constant speed" level asset was actually easing. Same class of
bug for any enum whose zero entry is a sentinel: **give serialized enum fields an explicit default in
the field initializer** (`private Ease _ease = Ease.Linear;`) and verify the value stored in the asset,
not the value in code.

### `SpriteRenderer.color` / `Image.color` multiplies, it does not replace

Tint is a per-pixel multiply against the texture. Setting `color = Color.white` cannot brighten a dark
sprite, and no colour can make it lighter than the source pixels. A "flash the sprite white" effect
needs a material/shader that lerps towards the target colour (or a second, pre-whitened sprite), never
a colour tween.

---

## Code Quality by Mode

| Check | fast | standard | pro |
|-------|------|----------|-----|
| Settings in SO | ✅ | ✅ | ✅ |
| Single responsibility | — | ✅ | ✅ |
| XML docs | Public/non-obvious contracts only | Same | Same |
| `//` comments | Non-obvious why/constraint only | Same | Same |
| Debug.Log | Actionable diagnostics only | Same | Same |
| [SerializeField] | OK | ✅ | ✅ |
| Cache components | — | ✅ | ✅ |
| Interfaces | Real boundary only | Same | Same |
| Namespaces | Global namespace for new project scripts | Global namespace for new project scripts | Follow project; use product/feature namespaces in new projects when useful |
| Tests | Test Value Gate | Test Value Gate | Risk-based Test Value Gate |
| Singleton | Follow project ownership | Same | Same |
| Events | Optional | ✅ | ✅ |
| Object Pool | When justified | When justified | When justified |
| TextMeshPro (never legacy) | ✅ | ✅ | ✅ |
