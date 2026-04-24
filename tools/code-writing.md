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

**Usage:** fast — freely. standard — OK. pro — prefer DI/ServiceLocator.

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

## No Obvious Comments — Use Debug.Log Instead

**No obvious `//` comments.** Code must be self-documenting. Use `Debug.Log` to explain logic at runtime.

- ✅ Allowed: **XML docs** (`/// <summary>`), `// TODO:`, `// HACK:`, `// WORKAROUND:`
- ❌ Banned: `// calculate damage`, `// increment counter`, `// get component`

Pattern: `Debug.Log($"[Feature.Class.Method] description with params")`

```csharp
Debug.Log($"[Spawn.WaveSpawner.StartNextWave] Wave {wave}: {count} enemies");
Debug.LogError($"[Save.SaveSystem.Load] File not found: {path}");
Debug.LogWarning($"[Combat.Health.TakeDamage] Damage={amount} but HP already 0");
```

**Only allowed:** `// TODO:`, `// HACK:`, `// WORKAROUND:` (temporary markers).

| Mode | Debug.Log volume |
|------|-------------------|
| fast | Key events only |
| standard | Plenty — key events, state changes |
| pro | Plenty — key events, params, state changes |

---

## Code Quality by Mode

| Check | fast | standard | pro |
|-------|------|----------|-----|
| Settings in SO | ✅ | ✅ | ✅ |
| Single responsibility | — | ✅ | ✅ |
| XML docs | — | Public methods | All public |
| `//` comments | **No** | **No** | **No** |
| Debug.Log | Key events | Plenty | Plenty + params |
| [SerializeField] | OK | ✅ | ✅ |
| Cache components | — | ✅ | ✅ |
| Interfaces | — | — | ✅ |
| Namespaces | — | — | ✅ |
| Tests | — | — | ✅ |
| Singleton | ✅ | OK | DI |
| Events | Optional | ✅ | ✅ |
| Object Pool | — | If needed | ✅ |
| TextMeshPro (never legacy) | ✅ | ✅ | ✅ |
