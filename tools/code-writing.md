# C# / Написание кода — рекомендации

Рекомендации по написанию кода для Unity-игр. Стиль, паттерны и строгость зависят от [режима разработки](../MODE_CHOICE.md).

---

## Общие правила (для всех режимов)

### Именование

- **Не использовать уникальные названия игры/проекта** в скриптах, классах, SO и именах файлов (например `TotalWar`, `MyGame`, `SuperPuzzle`). Использовать **ролевые/общие имена**: `GameManager`, `MainMenuController`, `RewardPanel`, `UiData`, `ShopItemView` — так код и ассеты остаются переносимыми и не привязаны к названию игры.

| Элемент | Стиль | Пример |
|---------|-------|--------|
| Классы, структуры | PascalCase | `PlayerController`, `EnemyData` |
| Публичные методы | PascalCase | `TakeDamage()`, `Initialize()` |
| Публичные свойства | PascalCase | `MaxHealth`, `MoveSpeed` |
| Приватные поля | camelCase с _ | `_currentHealth`, `_moveDirection` |
| Локальные переменные | camelCase | `spawnPosition`, `enemyCount` |
| Константы | UPPER_SNAKE или PascalCase | `MAX_ENEMIES` или `MaxEnemies` |
| SO ассеты | PascalCase с суффиксом | `PlayerData`, `EnemyData_Goblin` |

### ScriptableObject (обязательно во всех режимах)

**Все настройки и данные — в SO.** Не хардкодить в MonoBehaviour.

```csharp
// SO — данные
[CreateAssetMenu(fileName = "NewEnemyData", menuName = "GameData/EnemyData")]
public class EnemyData : ScriptableObject
{
    [Header("Характеристики")]
    public int health = 50;
    public float speed = 3f;
    public float damage = 10f;

    [Header("Визуал")]
    public Sprite sprite;
    public Color tintColor = Color.white;
}

// MonoBehaviour — логика (ссылается на SO)
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

### Базовые принципы

- **Один скрипт — одна ответственность.** `PlayerMovement` отдельно от `PlayerHealth`.
- **SerializeField вместо public** для полей в Inspector.
- **Не использовать Find/FindObjectOfType в Update** — кешировать в Start/Awake.
- **Null-check** при работе с ссылками на другие объекты.
- **Логирование** — объём зависит от режима (см. ниже).

### Асинхронность и отложенные операции

**Рекомендация для всех режимов:** использовать **UniTask** (Cysharp) для async/await в Unity — zero allocation, работа на PlayerLoop (без потоков, подходит для WebGL), отмена через `CancellationToken`, удобный `UniTask.Delay`, `UniTask.Yield`, await для `AsyncOperation` и корутин.

- **Если UniTask уже в проекте** — применять для задержек, загрузки сцен/ассетов, цепочек операций, отменяемых таймеров. Не дублировать логику корутинами без причины.
- **Если UniTask не установлен** — перед реализацией асинхронной фичи проверить, не проще ли добавить пакет (UPM: `com.cysharp.unitasks` или [GitHub](https://github.com/Cysharp/UniTask)). Документация: [UniTask](https://github.com/Cysharp/UniTask#readme).
- **Корутины** — допустимы для простых пошаговых задержек (одна цепочка `WaitForSeconds`), если UniTask не используется. Для сложных сценариев (отмена, несколько ожиданий, async-цепочки) предпочтительнее UniTask.

```csharp
// С UniTask (предпочтительно)
await UniTask.Delay(TimeSpan.FromSeconds(1), cancellationToken: cts.Token);
await sceneLoader.LoadSceneAsync("Game").ToUniTask();
```

### Часто используемые пакеты

Перед реализацией фичи проверять: (1) встроенные возможности Unity; (2) уже установленные пакеты в проекте; (3) при необходимости — **поиск на GitHub** (unity, механика, library, UPM) и **в интернете** (готовые механики, туториалы, форумы Unity, Asset Store, статьи). Ниже — пакеты, которые часто используют в Unity-проектах; при выборе «искать готовое» учитывать их.

| Назначение | Пакет | Кратко |
|------------|--------|--------|
| **Async/await** | **UniTask** (Cysharp) | Асинхронность без аллокаций, отмена, await для AsyncOperation. UPM: `com.cysharp.unitasks` или Git. Рекомендуется для всех режимов. |
| **Твины и анимации** | **DOTween** (Demigiant) | Быстрые твины для transform, UI, значений. Asset Store или [dotween.demigiant.com](https://dotween.demigiant.com/). Альтернатива: встроенный Animator / Animation для сложных клипов. |
| **JSON** | **Newtonsoft.Json** (Json.NET) | Сериализация/десериализация. В Unity часто уже есть (Unity 2022+ встроен частично). NuGet или UPM. |
| **DI / IoC** | **VContainer**, **Zenject** | Внедрение зависимостей для больших проектов (Профи). Не обязательны для прототипа и малых игр. |
| **Локализация** | **Unity Localization** | Пакет `com.unity.localization` — таблицы, ключи, подмена текстов. Встроенный вариант. |

Не устанавливать пакеты «на всякий случай» — только под задачу. Если пользователь явно попросил конкретную библиотеку — следовать запросу. **Как добавить** UniTask, DOTween, Newtonsoft.Json, Unity Localization (и при необходимости VContainer, Cinemachine, Input System) — пошагово в [libraries-setup.md](libraries-setup.md).

**Где искать готовое:** GitHub (по запросам вроде `unity 2d movement`, `unity inventory system`, `unity ui toolkit`; репозитории с открытым кодом и UPM); поиск в интернете — туториалы, [Unity Forums](https://forum.unity.com/), [Asset Store](https://assetstore.unity.com/), статьи и примеры механик.

### Unity UI (создание в runtime)

По скиллу **весь UI только через UI Builder** (UXML/USS, UIDocument), см. [ui-builder.md](ui-builder.md). Динамические элементы — через UI Toolkit API (добавление/удаление VisualElement в коде). Ниже — **исключительно для legacy** (например, версия Unity без UI Builder): создание UI программно на Canvas. В обычной разработке Canvas не использовать.

При создании UI программно на Canvas (только в исключительных случаях) обязательно:

- **EventSystem:** в сцене должен быть объект с `EventSystem` и `StandaloneInputModule` (или `InputSystemUIInputModule` при новом Input System). Если UI создаётся из кода при старте — проверять наличие EventSystem и при отсутствии создавать программно.
- **Кнопки:** у GameObject кнопки должны быть компоненты `Image` (или другой Graphic) и `Button`. Не забывать добавлять `Button` перед подпиской на `onClick`.

---

## Код по режимам

### Прототип

**Цель:** работает = ок. Минимум абстракций, максимум скорости.

**Допустимо:**
- Вся логика в одном скрипте (если < 100 строк).
- Прямые ссылки через `[SerializeField]` без архитектуры.
- `GetComponent<>()` в Start без кеширования (если объектов мало).
- Магические числа — **кроме настроек** (те в SO).
- Без XML-документации (кроме неочевидных мест).
- **Singleton для менеджеров** — свободно (`GameManager.Instance`, `AudioManager.Instance` и т.д.).

**Не допустимо:**
- Хардкод настроек (скорость, урон) — **только в SO**.
- `Update` без проверок (бесконечные вычисления без смысла).

**Пример (Прототип):**

```csharp
public class PlayerController : MonoBehaviour
{
    [SerializeField] private PlayerSettings _settings;

    private Rigidbody2D _rb;

    private void Start()
    {
        _rb = GetComponent<Rigidbody2D>();
    }

    private void Update()
    {
        float h = Input.GetAxisRaw("Horizontal");
        _rb.velocity = new Vector2(h * _settings.speed, _rb.velocity.y);

        if (Input.GetKeyDown(KeyCode.Space))
            _rb.AddForce(Vector2.up * _settings.jumpForce, ForceMode2D.Impulse);
    }
}
```

---

### Стандартный

**Цель:** чистый, читаемый код с разумным разделением.

**Обязательно:**
- Отдельные скрипты по ответственности: `PlayerMovement`, `PlayerHealth`, `PlayerCombat`.
- `[SerializeField]` для всех полей в Inspector.
- Кеширование компонентов в `Awake`/`Start`.
- Данные — в SO, ссылки на SO через `[SerializeField]`.
- Prefabs для повторяемых объектов.
- XML-документация для публичных методов.

**Рекомендуется:**
- Events / UnityEvents для связи между системами.
- UniTask для асинхронности и задержек (см. «Асинхронность и отложенные операции»); при отсутствии UniTask — корутины для простых тайм-зависимых операций.
- `[Header]`, `[Tooltip]`, `[Range]` в SO для удобства Inspector.

**Пример (Стандартный):**

```csharp
/// <summary>
/// Управление передвижением игрока. Настройки в PlayerData SO.
/// </summary>
public class PlayerMovement : MonoBehaviour
{
    [SerializeField] private PlayerData _data;

    private Rigidbody2D _rb;
    private bool _isGrounded;

    private void Awake()
    {
        _rb = GetComponent<Rigidbody2D>();
    }

    private void Update()
    {
        HandleMovement();
        HandleJump();
    }

    private void HandleMovement()
    {
        float horizontal = Input.GetAxisRaw("Horizontal");
        _rb.velocity = new Vector2(horizontal * _data.moveSpeed, _rb.velocity.y);
    }

    private void HandleJump()
    {
        if (Input.GetKeyDown(KeyCode.Space) && _isGrounded)
        {
            _rb.AddForce(Vector2.up * _data.jumpForce, ForceMode2D.Impulse);
            _isGrounded = false;
        }
    }

    private void OnCollisionEnter2D(Collision2D collision)
    {
        if (collision.gameObject.CompareTag("Ground"))
            _isGrounded = true;
    }
}
```

---

### Быстрый

**Цель:** рабочий компонентный код, быстро писать, легко модифицировать.

**Обязательно:**
- Компоненты по ответственности (но допустимо объединять мелкие).
- Данные в SO.
- Кеширование компонентов.

**Допустимо:**
- Минимум XML-документации (только для неочевидных мест).
- Менее строгое разделение (2 ответственности в одном скрипте если они связаны).
- **Singleton для менеджеров** — свободно (`GameManager.Instance`, `UIManager.Instance`, `SpawnManager.Instance` и т.д.).

**Не допустимо:**
- Хардкод настроек.
- Копипаст кода (лучше быстрый метод / базовый класс).

**Пример (Быстрый):**

```csharp
public class PlayerController : MonoBehaviour
{
    [SerializeField] private PlayerData _data;

    private Rigidbody2D _rb;
    private int _currentHealth;
    private bool _isGrounded;

    private void Awake()
    {
        _rb = GetComponent<Rigidbody2D>();
        _currentHealth = _data.maxHealth;
    }

    private void Update()
    {
        float h = Input.GetAxisRaw("Horizontal");
        _rb.velocity = new Vector2(h * _data.moveSpeed, _rb.velocity.y);

        if (Input.GetKeyDown(KeyCode.Space) && _isGrounded)
            _rb.AddForce(Vector2.up * _data.jumpForce, ForceMode2D.Impulse);
    }

    public void TakeDamage(int amount)
    {
        _currentHealth -= amount;
        if (_currentHealth <= 0)
            GameManager.Instance.GameOver();
    }

    private void OnCollisionEnter2D(Collision2D col)
    {
        if (col.gameObject.CompareTag("Ground"))
            _isGrounded = true;
    }
}
```

---

### Профи

**Цель:** масштабируемая архитектура, тестируемый код, расширяемость.

**Обязательно:**
- **Интерфейсы** для ключевых систем (`IDamageable`, `IInteractable`, `ISaveable`).
- **Сервисы** через ServiceLocator или DI (Zenject / VContainer — по выбору).
- **Разделение данных и логики:** SO для данных, MonoBehaviour для привязки к Unity, POCO-классы для чистой логики.
- **Events / Observer Pattern** для связи между системами.
- **XML-документация (docstring)** для классов, публичных методов, публичных полей/свойств, интерфейсов — **обязательна**.
- **Автотесты** (если не отключены): EditMode тесты для логики, PlayMode для интеграции.
- **Namespace** по системам: `Game.Combat`, `Game.Inventory`, `Game.UI`.

**Комментарии — строгие правила:**
- **Обычных комментариев (`//`) НЕ писать.** Код самодокументируемый. Имена классов, методов, переменных должны объяснять смысл.
- **Разрешены только:**
  - `// TODO:` — задача на будущее, которую нужно не забыть.
  - `// HACK:` / `// WORKAROUND:` — неочевидное решение, которое выглядит странно, но сделано намеренно (пояснить почему).
  - `// NOTE:` — критически неочевидная логика, без пометки будет непонятно следующему разработчику.
  - Комментарии в SO-классах — для пояснения настроек (допустимы `[Tooltip("...")]` или `//` рядом с полем, объясняющие что значит параметр для пользователя).
- **Запрещено:** `// вызываем метод`, `// увеличиваем счётчик`, `// проверяем условие` и любые очевидные комментарии.

**Рекомендуется:**
- State Machine для сложного поведения (AI, анимации).
- Command Pattern для действий (undo/redo, реплей).
- Object Pool для частого создания/уничтожения.
- Addressables вместо Resources для загрузки ассетов.
- Assembly Definitions для ускорения компиляции.

**Пример (Профи):**

```csharp
namespace Game.Combat
{
    /// <summary>
    /// Компонент здоровья. Реализует IDamageable.
    /// Данные из HealthData SO.
    /// </summary>
    public class HealthComponent : MonoBehaviour, IDamageable
    {
        [SerializeField] private HealthData _data;

        private int _currentHealth;

        /// <summary>Вызывается при изменении HP: (current, max).</summary>
        public event System.Action<int, int> OnHealthChanged;

        /// <summary>Вызывается при смерти (HP <= 0).</summary>
        public event System.Action OnDeath;

        /// <summary>Текущее здоровье.</summary>
        public int CurrentHealth => _currentHealth;

        /// <summary>Максимальное здоровье из SO.</summary>
        public int MaxHealth => _data.maxHealth;

        /// <summary>Жив ли объект.</summary>
        public bool IsAlive => _currentHealth > 0;

        private void Awake()
        {
            _currentHealth = _data.maxHealth;
        }

        /// <summary>
        /// Нанести урон. Если HP падает до 0 — вызывает OnDeath.
        /// </summary>
        /// <param name="amount">Количество урона (положительное).</param>
        public void TakeDamage(int amount)
        {
            if (!IsAlive) return;

            _currentHealth = Mathf.Max(0, _currentHealth - amount);
            OnHealthChanged?.Invoke(_currentHealth, _data.maxHealth);

            if (!IsAlive)
                OnDeath?.Invoke();
        }

        /// <summary>
        /// Восстановить здоровье. Не превышает MaxHealth.
        /// </summary>
        /// <param name="amount">Количество лечения (положительное).</param>
        public void Heal(int amount)
        {
            if (!IsAlive) return;

            // NOTE: лечение мёртвого объекта игнорируется намеренно — воскрешение через отдельный метод
            _currentHealth = Mathf.Min(_data.maxHealth, _currentHealth + amount);
            OnHealthChanged?.Invoke(_currentHealth, _data.maxHealth);
        }
    }

    /// <summary>
    /// Интерфейс для объектов, которым можно нанести урон.
    /// </summary>
    public interface IDamageable
    {
        /// <summary>Нанести урон.</summary>
        void TakeDamage(int amount);

        /// <summary>Жив ли объект.</summary>
        bool IsAlive { get; }
    }
}
```

**Пример SO с пояснениями настроек (допустимые комментарии):**

```csharp
namespace Game.Combat
{
    /// <summary>
    /// Данные здоровья для компонента HealthComponent.
    /// </summary>
    [CreateAssetMenu(fileName = "NewHealthData", menuName = "GameData/HealthData")]
    public class HealthData : ScriptableObject
    {
        [Tooltip("Максимальное здоровье при спавне")]
        public int maxHealth = 100;

        [Tooltip("Время неуязвимости после получения урона (сек)")]
        public float invincibilityDuration = 0.5f;

        // Множитель урона от стихий (1.0 = нормальный, 2.0 = двойной)
        [Tooltip("Множитель входящего урона от стихий")]
        public float elementalDamageMultiplier = 1f;
    }
}
```

**Пример теста (Профи):**

```csharp
namespace Game.Tests
{
    using NUnit.Framework;
    using Game.Combat;

    [TestFixture]
    public class HealthComponentTests
    {
        [Test]
        public void TakeDamage_ReducesHealth()
        {
            // Arrange — создать HealthData SO, установить maxHealth = 100
            // Act — TakeDamage(30)
            // Assert — CurrentHealth == 70
        }

        [Test]
        public void TakeDamage_BelowZero_TriggersOnDeath()
        {
            // Arrange — maxHealth = 50
            // Act — TakeDamage(60)
            // Assert — IsAlive == false, OnDeath вызван
        }
    }
}
```

---

## Общие паттерны Unity

### Singleton (для менеджеров)

```csharp
public class GameManager : MonoBehaviour
{
    public static GameManager Instance { get; private set; }

    private void Awake()
    {
        if (Instance != null && Instance != this)
        {
            Destroy(gameObject);
            return;
        }
        Instance = this;
        DontDestroyOnLoad(gameObject);
    }
}
```

**Режимы:** Прототип/Быстрый — Singleton свободно, основной способ доступа к менеджерам. Стандартный — допустим. Профи — предпочитать ServiceLocator/DI.

### Object Pool

```csharp
public class ObjectPool : MonoBehaviour
{
    [SerializeField] private GameObject _prefab;
    [SerializeField] private int _initialSize = 10;

    private Queue<GameObject> _pool = new Queue<GameObject>();

    private void Start()
    {
        for (int i = 0; i < _initialSize; i++)
            AddToPool(CreateInstance());
    }

    public GameObject Get(Vector3 position)
    {
        var obj = _pool.Count > 0 ? _pool.Dequeue() : CreateInstance();
        obj.transform.position = position;
        obj.SetActive(true);
        return obj;
    }

    public void Return(GameObject obj)
    {
        obj.SetActive(false);
        _pool.Enqueue(obj);
    }

    private GameObject CreateInstance()
    {
        var obj = Instantiate(_prefab, transform);
        obj.SetActive(false);
        return obj;
    }
}
```

**Режимы:** Прототип — не нужен. Стандартный — если объекты спавнятся часто. Быстрый/Профи — рекомендуется.

---

## Логирование (Debug.Log)

Объём логирования зависит от режима. Логи помогают отлаживать и понимать поведение игры.

| Режим | Логирование | Что логировать |
|-------|-------------|----------------|
| **Прототип** | Минимум или без логов | Только при отладке проблемы. Можно без логов. |
| **Быстрый** | Умеренно | Ошибки (`LogError`), предупреждения (`LogWarning`). `Log` — по необходимости. |
| **Стандартный** | **Обильно (уместно)** | Ключевые события, смена состояний, ошибки, предупреждения. |
| **Профи** | **Обильно (уместно)** | Ключевые события, смена состояний, входящие параметры, ошибки, предупреждения. |

### Формат логов (все режимы)

```
Debug.Log($"[Фича.Класс.Метод] комментарий");
```

- **Фича** — название системы/фичи (`Combat`, `Spawn`, `UI`, `Save`, `Inventory`, `Input`).
- **Класс** — имя класса (`WaveSpawner`, `PlayerCombat`, `SaveSystem`).
- **Метод** — имя метода (`StartNextWave`, `TakeDamage`, `Save`).
- **Комментарий** — что произошло + параметры.

### Примеры формата

```csharp
Debug.Log($"[Spawn.WaveSpawner.StartNextWave] Wave {_currentWave}: {count} enemies, interval={interval}s");
Debug.Log($"[Combat.PlayerCombat.TakeDamage] Damage={amount}, HP={_currentHealth}/{_data.maxHealth}");
Debug.Log($"[UI.HUDController.UpdateScore] Score updated: {score}");
Debug.LogError($"[Inventory.Inventory.AddItem] Item {itemId} not found in database");
Debug.LogWarning($"[Save.SaveSystem.Load] Save file corrupted, using defaults");
Debug.Log($"[Data.DataLoader.LoadEnemies] Loaded {count} enemies from SO");
```

### Что логировать (Стандартный и Профи)

- **Инициализация:** `[Spawn.EnemySpawner.SpawnEnemy] Spawned {name} at {pos}`.
- **Смена состояния:** `[Combat.BattleManager.NextTurn] Turn changed: {turn}`.
- **Действия игрока:** `[Combat.PlayerCombat.Attack] Damage={dmg}, target={name}`.
- **Ошибки:** `[Inventory.Inventory.AddItem] Item {id} not found`.
- **Предупреждения:** `[Save.SaveSystem.Load] File corrupted, using defaults`.
- **Загрузка данных:** `[Data.DataLoader.LoadEnemies] Loaded {count} from SO`.

### Правила оформления

- **Формат `[Фича.Класс.Метод]`** — обязателен во всех режимах где есть логи. Позволяет фильтровать в консоли Unity по фиче, классу или методу.
- **Интерполяция строк** `$"..."` — для читаемости.
- `Debug.LogError` — для ошибок (красный в консоли).
- `Debug.LogWarning` — для подозрительных ситуаций (жёлтый).
- `Debug.Log` — для информации.
- **Не логировать в Update каждый кадр** (кроме отладки) — это убивает производительность.
- В **Прототипе** формат тот же, просто логов меньше (или нет).

### Пример (Стандартный / Профи)

```csharp
public class WaveSpawner : MonoBehaviour
{
    [SerializeField] private WaveData _waveData;

    private int _currentWave;

    public void StartNextWave()
    {
        _currentWave++;
        Debug.Log($"[Spawn.WaveSpawner.StartNextWave] Wave {_currentWave}: {_waveData.enemyCount} enemies, interval={_waveData.spawnInterval}s");
        StartCoroutine(SpawnWave());
    }

    private IEnumerator SpawnWave()
    {
        for (int i = 0; i < _waveData.enemyCount; i++)
        {
            SpawnEnemy();
            yield return new WaitForSeconds(_waveData.spawnInterval);
        }
        Debug.Log($"[Spawn.WaveSpawner.SpawnWave] Wave {_currentWave} complete");
    }

    private void SpawnEnemy()
    {
        if (_waveData.enemyPrefab == null)
        {
            Debug.LogError("[Spawn.WaveSpawner.SpawnEnemy] enemyPrefab is null in WaveData!");
            return;
        }
        var enemy = Instantiate(_waveData.enemyPrefab, GetSpawnPosition(), Quaternion.identity);
        Debug.Log($"[Spawn.WaveSpawner.SpawnEnemy] Spawned at {enemy.transform.position}");
    }
}
```

### Пример (Прототип — минимум)

```csharp
public class PlayerController : MonoBehaviour
{
    [SerializeField] private PlayerSettings _settings;

    private void Update()
    {
        float h = Input.GetAxisRaw("Horizontal");
        GetComponent<Rigidbody2D>().velocity = new Vector2(h * _settings.speed, GetComponent<Rigidbody2D>().velocity.y);
    }
}
```

Никаких логов — и это нормально для прототипа.

---

## Чеклист качества кода

| Проверка | Прототип | Стандартный | Быстрый | Профи |
|----------|----------|-------------|---------|-------|
| Настройки в SO | ✅ | ✅ | ✅ | ✅ |
| Одна ответственность | — | ✅ | ≈ | ✅ |
| XML-документация (docstring) | — | ✅ public | Минимум | ✅ классы + public методы/поля |
| Обычные комментарии `//` | Допустимы | Допустимы | Допустимы | ❌ Запрещены (кроме TODO/HACK/NOTE и SO) |
| Логирование (Debug.Log) | Минимум / без | ✅ Обильно | Умеренно | ✅ Обильно |
| SerializeField (не public) | — | ✅ | ✅ | ✅ |
| Кеширование компонентов | — | ✅ | ✅ | ✅ |
| Интерфейсы | — | — | — | ✅ |
| Namespace | — | — | — | ✅ |
| Автотесты | — | — | — | ✅ |
| Singleton для менеджеров | ✅ Свободно | Допустим | ✅ Свободно | ServiceLocator/DI |
| Events вместо прямых ссылок | — | ✅ | ≈ | ✅ |
| Object Pool (если нужен) | — | ≈ | ✅ | ✅ |

### Допустимые комментарии по режимам

| Тип | Прототип | Стандартный | Быстрый | Профи |
|-----|----------|-------------|---------|-------|
| XML-документация (`/// <summary>`) | — | public методы | Минимум | Классы + все public |
| Обычные `//` | Да | Да | Да | **Нет** |
| `// TODO:` | Да | Да | Да | Да |
| `// HACK:` / `// WORKAROUND:` | Да | Да | Да | Да |
| `// NOTE:` (неочевидное место) | Да | Да | Да | Да |
| Пояснения в SO (`[Tooltip]` / `//`) | Да | Да | Да | Да |
