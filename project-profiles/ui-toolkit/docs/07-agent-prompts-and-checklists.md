# 07 — Инструкции агенту и чеклисты

## Системная установка для агента

Когда пишешь Unity UI Toolkit 6.5 runtime UI:

1. Предполагай `PanelRenderer`, если пользователь не сказал обратное.
2. Не используй старый `UIDocument.rootVisualElement` в новых runtime примерах.
3. Всегда делай reload-safe binding через `RegisterUIReloadCallback`.
4. Делай UXML/USS/C# split.
5. Состояния оформляй classes, а не scattered inline styles.
6. USS transitions — default для visual state animation.
7. C# animation — только для сценария, динамических значений и сложной синхронизации.
8. Для shaders различай `-unity-material` и `filter`.
9. Для больших списков предлагай `ListView`/виртуализацию.
10. **Прежде чем утверждать сигнатуру API или наличие свойства — проверь** (рефлексия через
    Unity MCP `unity_reflect`, доки 6000.5, или существующий компилирующийся код проекта). Не
    полагайся на память: например, у `RegisterUIReloadCallback` **два** overload'а — 2-арг
    `UIReloadCallback` и 3-арг `VersionedUIReloadCallback` с `int version`; оба валидны.
11. В конце ответа давай ссылки на официальные docs, но не заставляй пользователя читать docs для базовой реализации.

## Шаблон ответа на задачу “сделай экран”

```text
1. Коротко: архитектура и файлы.
2. UXML.
3. USS.
4. Presenter C#.
5. Как подключить PanelRenderer в Inspector.
6. Best practices / ловушки.
7. Документация.
```

## Шаблон ответа на задачу “сделай custom control”

```text
1. Когда этот control оправдан.
2. C# VisualElement с [UxmlElement] и [UxmlAttribute].
3. UXML usage с namespace.
4. USS styling.
5. Public API methods.
6. Ограничения и performance.
7. Docs links.
```

## Шаблон ответа на задачу “анимация”

```text
1. Выбор: USS или C#.
2. USS states/classes.
3. C# только переключает classes.
4. Если нужно — schedule/tween.
5. Performance notes: transform/opacity, no layout animation.
6. Docs links.
```

## Шаблон ответа на задачу “шейдер/эффект”

```text
1. Это material effect или subtree post-effect?
2. Если material: UI Shader Graph + -unity-material.
3. Если post-effect: USS filter/custom filter.
4. USS пример.
5. Shader/material setup checklist.
6. Performance caveats.
7. Docs links.
```

## Code review checklist

### Panel lifecycle

- [ ] `PanelRenderer` используется в runtime Unity 6.5.
- [ ] `RegisterUIReloadCallback` — выбран корректный overload (2-арг `UIReloadCallback` по умолчанию; 3-арг `VersionedUIReloadCallback` только если нужен dedup по version).
- [ ] `UnregisterUIReloadCallback` есть (симметрично, тот же метод-обработчик).
- [ ] `Unwire()` снимает callbacks и вызывается в начале каждого reload (идемпотентность).
- [ ] Reload-бойлерплейт не продублирован в каждом экране (вынесен в базовый класс/binder).

### UXML/USS

- [ ] UXML не содержит много inline style.
- [ ] Элементы имеют стабильные `name` для C#.
- [ ] Classes семантические.
- [ ] Templates не пытаются override `class/name/style`.
- [ ] Custom controls имеют namespace.

### Animations

- [ ] Transitions заданы на базовом class.
- [ ] Нет `transition-property: all`.
- [ ] Для enter animation не используется только `display: none`.
- [ ] Не анимируются layout-свойства в loops/large lists.

### Shaders/filters

- [ ] `-unity-material` не применился случайно ко всем children.
- [ ] Filters не стоят на огромном root без нужды.
- [ ] Filter transition functions совпадают по типу и порядку.
- [ ] Custom filter имеет margins, если эффект выходит за bounds.

### Performance

- [ ] Нет per-frame `Q(...)`.
- [ ] Нет массового создания elements каждый frame.
- [ ] Lists виртуализированы.
- [ ] Scheduled tasks не висят после removal.
- [ ] Profiling markers проверены для спорных мест.
