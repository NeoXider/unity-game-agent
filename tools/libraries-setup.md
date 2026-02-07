# Настройка библиотек — как добавить агенту

Инструкции для агента: как добавить в Unity-проект часто используемые библиотеки. **Полный список установки** — пошагово ниже.

---

## Установить перед началом разработки

**Агент обязан перед началом реализации** (после подтверждения плана, до первой фичи) установить библиотеки по этому файлу. Не переходить к реализации, пока не установлено.

**Устанавливать по умолчанию (все проекты):**
- **UniTask** — async/await.
- **DOTween** — твины (если нет доступа к Asset Store — зафиксировать в DEV_STATE и использовать встроенный Animator/код там, где нужны твины).
- **Newtonsoft.Json** — JSON (сохранения, конфиги, API); пакет Unity `com.unity.nuget.newtonsoft-json`.

**По необходимости (по задаче / GAME_DESIGN / DEV_CONFIG):**
- **Unity Localization** — только если нужна поддержка нескольких языков.
- Остальное (VContainer, Cinemachine, Input System) — только если явно требуется.

Проверять **Packages/manifest.json** и **Assets**: если пакет уже есть — не дублировать. После установки зафиксировать в `Docs/DEV_LOG/` или `Docs/AGENT_MEMORY.md`.

---

## UniTask (Cysharp)

**Назначение:** async/await для Unity без аллокаций, отмена, await для AsyncOperation и корутин. Рекомендуется для задержек, загрузки сцен, цепочек операций.

### Как добавить в проект

**Способ 1: Package Manager (рекомендуется)**

1. В Unity: **Window → Package Manager**.
2. Кнопка **+** (Add) → **Add package from git URL...**.
3. Вставить URL:
   ```
   https://github.com/Cysharp/UniTask.git?path=src/UniTask/Assets/Plugins/UniTask
   ```
4. **Add**. Дождаться импорта.

**Способ 2: manifest.json (если агент редактирует файлы напрямую)**

Файл `Packages/manifest.json`. В блок `dependencies` добавить строку (с запятой после предыдущей записи):

```json
"com.cysharp.unitask": "git+https://github.com/Cysharp/UniTask.git?path=src/UniTask/Assets/Plugins/UniTask"
```

Сохранить файл; Unity подтянет пакет при следующей перезагрузке/обновлении.

**Требования:** Git установлен в системе (Unity использует его для загрузки). Unity 2018.4+.

**Проверка:** после добавления в коде доступен `using Cysharp.Threading.Tasks;` и типы `UniTask`, `UniTaskVoid` и т.д.

**Документация:** [UniTask GitHub](https://github.com/Cysharp/UniTask#readme).

---

## DOTween (Demigiant)

**Назначение:** твины для transform, UI, произвольных значений. Быстрая настройка анимаций без Animator.

### Как добавить в проект

Официально DOTween распространяется через **Asset Store** и сайт разработчика; UPM-пакета от Demigiant нет.

**Способ 1: Asset Store**

1. [DOTween (HOTween v2) в Asset Store](https://assetstore.unity.com/packages/tools/animation/dotween-hotween-v2-27676).
2. Добавить в корзину / получить (есть бесплатная версия).
3. В Unity: **Window → Package Manager** → вкладка **My Assets** (или **Asset Store**) → найти DOTween → **Download** / **Import**.
4. Импортировать в проект.
5. После первого импорта: в меню **Tools → Demigiant → DOTween Utility Panel** выполнить **Setup** (выбрать нужные модули: Unity, TextMeshPro, 2D и т.д.) и применить.

**Способ 2: Сайт разработчика**

1. Перейти на [dotween.demigiant.com](https://dotween.demigiant.com/download.php).
2. Скачать актуальный **DOTween*.unitypackage**.
3. В Unity: **Assets → Import Package → Custom Package** → выбрать скачанный .unitypackage → **Import**.
4. После импорта: **Tools → Demigiant → DOTween Utility Panel** → **Setup** (выбрать модули) → **Apply**.

**Проверка:** в сцене или коде доступны расширения, например `transform.DOMove(...)`, после `using DG.Tweening;`.

**Документация:** [DOTween Documentation](https://dotween.demigiant.com/documentation.php).

---

## Newtonsoft.Json (Json.NET)

**Назначение:** сериализация/десериализация JSON — сохранения, загрузка конфигов, ответы API. Во многих проектах уже есть или нужен с первой же фичи сохранений.

### Как добавить в проект

**Unity 2022+ (официальный пакет Unity)**

1. **Window → Package Manager**.
2. **+** → **Add package by name...**.
3. Имя пакета: `com.unity.nuget.newtonsoft-json`.
4. **Add**.

**manifest.json:** в `dependencies` добавить:
```json
"com.unity.nuget.newtonsoft-json": "3.2.2"
```
(или актуальную версию из списка пакетов Unity.)

**Проверка:** в коде доступен `using Newtonsoft.Json;` (например, `JsonConvert.SerializeObject`, `JsonConvert.DeserializeObject`).

---

## Unity Localization

**Назначение:** локализация — таблицы строк, ключи, подмена текстов по языку. Встроенный пакет Unity.

### Как добавить в проект

1. **Window → Package Manager**.
2. **+** → **Add package by name...**.
3. Имя: `com.unity.localization`.
4. **Add**.

Дальше: создать таблицы (Tables), ключи, назначить локали. Документация: [Unity Localization](https://docs.unity3d.com/Packages/com.unity.localization@1.0/manual/index.html). Добавлять только если в GAME_DESIGN или запросе пользователя указана поддержка нескольких языков.

---

## Остальное (по необходимости)

- **VContainer / Zenject** — DI для крупных проектов (режим Профи). Устанавливать только если архитектура явно требует IoC. VContainer: UPM/Git; Zenject (Extenject): Asset Store или [GitHub](https://github.com/Mathijs-Bakker/Extenject).
- **Cinemachine** — камера (следование, виртуальные камеры). Встроенный пакет: `com.unity.cinemachine`. Добавлять при необходимости сложной камеры.
- **Input System** — новый ввод. Встроенный пакет: `com.unity.inputsystem`. Нужен, если в настройках выбран новый Input System.

---

## Общее для агента

- Перед добавлением библиотеки проверить **Packages/manifest.json** и папку **Assets** — пакет может быть уже установлен.
- После добавления любой библиотеки из этого файла зафиксировать в файле итерации (`Docs/DEV_LOG/`) или в `Docs/AGENT_MEMORY.md`, чтобы не добавлять повторно.
- Добавлять только под задачу (сохранения → Newtonsoft; твины → DOTween; несколько языков → Localization). Если пользователь явно попросил другую библиотеку или способ установки — следовать запросу.
