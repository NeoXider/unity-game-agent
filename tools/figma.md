# Figma — рекомендации по использованию

**ПОКА временно доступно только получение готового дизайна игры** — чтение макетов из Figma и экспорт картинок. Создание макетов в Figma через MCP не поддерживается.

**Правило:** при работе с макетами Figma агент **запрашивает у пользователя ссылку на файл/фрейм Figma**, если она не указана в `DEV_CONFIG.md` (поле «Ссылка на Figma»).

**Дизайн может быть и с сайта:** если пользователь даёт ссылку на сайт-референс, опираться на него; Figma MCP тогда опционален.

---

## Что доступно сейчас

- **Получить данные макета** — по ссылке на файл/фрейм Figma: структура, узлы, размеры, стили, заливки (для кода/Unity UI).
- **Скачать изображения** — экспорт выбранных узлов (иконки, кнопки, фоны) в PNG/SVG в папку проекта (например `Assets/_source/UI`).

**Ссылку на Figma** агент берёт из `DEV_CONFIG.md` (поле «Ссылка на Figma») или **запрашивает у пользователя**, если при работе с макетами она не указана.

Редактирование файлов в Figma через MCP недоступно.

---

## _Figma MCP (подключение)

### Вариант 1: figma-developer-mcp (рекомендуется без Dev Mode)

**Dev Mode в Figma доступен только на плане Professional+.** Если при переключении в Dev Mode Figma показывает «Upgrade to work in Dev Mode» — используйте этот вариант (токен, без Dev Mode).

В `.cursor/mcp.json` настроен **figma-developer-mcp** ([Framelink](https://github.com/framelink/figma-developer-mcp)): работает по **Personal Access Token**, без OAuth и без Dev Mode.

**Что сделать один раз:**

1. **Создать токен Figma:** [figma.com](https://www.figma.com) → профиль (аватар) → **Settings** → вкладка **Security** → блок **Personal access tokens** → **Generate new token**. Скопировать токен.
2. В **`.cursor/mcp.json`** в секции `figma` → `env` → **`FIGMA_API_KEY`** вписать свой токен вместо `ЗАМЕНИТЕ_НА_ВАШ_ТОКЕН`.
3. Перезапустить Cursor. MCP подхватит конфиг; в чате можно вставлять ссылку на фрейм/файл Figma и просить реализовать дизайн.

Токен даёт доступ к файлам, к которым у вас есть доступ в Figma (в т.ч. в команде NeoXider). Подробнее: [Manage personal access tokens](https://help.figma.com/hc/en-us/articles/8085703771159-Manage-personal-access-tokens).

---

### Вариант 2: официальный Desktop MCP (нужен Dev Mode)

Если у вас **Professional / Organization / Enterprise** и Dev Mode доступен:

- В **Figma Desktop**: открыть файл → **Shift+D** (Dev Mode) → справа в Inspect блок **MCP server** → **Enable desktop MCP server**.
- В `mcp.json` указать: `"figma": { "url": "http://127.0.0.1:3845/mcp" }`. Авторизация не нужна.

### Вариант 3: официальный Remote MCP (OAuth)

В конфиге: `"figma": { "url": "https://mcp.figma.com/mcp" }`. В Cursor нажать Connect и войти через браузер. Если страница входа не открывается — типичная проблема Cursor; тогда использовать вариант 1 (токен).

Подробнее: [Figma Developer Docs — MCP Server](https://developers.figma.com/docs/figma-mcp-server).

---

## _Зачем Figma в пайплайне

- **Макеты UI** — нарисовать экраны (меню, HUD, инвентарь) до реализации в Unity (UI Builder / UXML).
- **Стиль-гайд** — зафиксировать цвета, шрифты, размеры элементов.
- **Прототип навигации** — показать переходы между экранами (flow).
- **Экспорт ассетов** — иконки, кнопки, фоны UI можно экспортировать из Figma в PNG/SVG.

---

## _Типовой воркфлоу

```
1. Набросок экранов в Figma (фреймы по разрешению: 1920x1080, 1080x1920 и т.д.)
2. Базовый стиль: цвета, шрифты, кнопки
3. Макеты экранов: MainMenu, Gameplay HUD, Pause, Settings, GameOver
4. Прототип: связать экраны стрелками (flow)
5. Экспорт: иконки и элементы → Assets/Art/UI/
6. Реализация в Unity (UI Builder, UXML) по макетам
```

---

## _Использование по режимам

### Прототип

- **Не нужен.** UI делать прямо в Unity — быстрые кнопки, текст, без дизайна.
- Цвета и шрифты — дефолтные.
- Не тратить время на макеты.

### Стандартный

- **По желанию.** Если в игре 2–3 экрана — можно быстро набросать в Figma.
- Основная польза: определить расположение элементов HUD до реализации.
- Минимальный стиль-гайд: 2–3 цвета, один шрифт, размеры кнопок.
- **Момент:** перед этапом «UI» в плане разработки.

### Быстрый

- **Не нужен.** UI делать в Unity напрямую — скорость важнее.
- Если сложный UI (5+ экранов) — можно быстрый скетч на бумаге или в любом редакторе.
- Figma overhead не оправдан для этого режима.

### Профи

- **Рекомендуется.** Полноценные макеты всех экранов.
- Обязательно:
  - **Стиль-гайд:** цвета (primary, secondary, accent, background, text), шрифты (heading, body), размеры (кнопки, отступы).
  - **Макеты всех экранов** с реальными размерами.
  - **Flow-прототип:** переходы между экранами.
  - **Экспорт ассетов:** иконки, кнопки, фоны.
- Макеты хранить в `Docs/Design/` или ссылкой на Figma-проект в DEV_STATE.
- **Момент:** после наброска, перед началом реализации UI.

---

## _Рекомендации по Figma для Unity UI

### Разрешения фреймов

| Платформа | Разрешение |
|-----------|------------|
| PC (16:9) | 1920 × 1080 |
| Mobile Portrait | 1080 × 1920 |
| Mobile Landscape | 1920 × 1080 |
| Tablet | 2048 × 1536 |

### Именование слоёв

Называть элементы в Figma так же, как в Unity:
- `Panel_MainMenu`, `Button_Play`, `Text_Score`, `Icon_Health`.
- Это упростит перенос в Unity (UI Builder, UXML).

### Экспорт

- **Иконки:** PNG, 2x размер (для чёткости на Retina). Например, иконка 48x48 → экспортировать 96x96.
- **Фоны UI:** PNG или JPEG (если без прозрачности).
- **Кнопки (9-slice):** экспортировать с запасом, настроить 9-slice в Unity (Sprite Editor → Border).

### Цвета → Unity

Записывать hex-коды цветов из Figma в ScriptableObject `UiData`:

```csharp
[CreateAssetMenu(fileName = "UiData", menuName = "GameData/UiData")]
public class UiData : ScriptableObject
{
    [Header("Цвета")]
    public Color primaryColor;
    public Color secondaryColor;
    public Color accentColor;
    public Color backgroundColor;
    public Color textColor;

    [Header("Размеры")]
    public float buttonHeight = 60f;
    public float padding = 16f;
    public int headingFontSize = 36;
    public int bodyFontSize = 18;
}
```

---

## _Альтернативы (если нет Figma)

| Инструмент | Когда использовать |
|------------|-------------------|
| **Бумага / whiteboard** | Прототип: быстрый скетч |
| **Excalidraw** | Быстрые wireframe бесплатно |
| **Unity Editor** | Прототип/Быстрый: UI через UI Builder в Unity |
| **ComfyUI** | Генерация UI-элементов (иконки, фоны) |
