# Project architecture

Key decisions. Agent follows this when implementing.

---

## Systems

| System | Description | Key classes |
|--------|-------------|-------------|
| Core | Managers, scene load | GameManager, SceneLoader |
| Combat | Combat | BattleManager, HealthComponent |
| UI | Interface | UIManager, HUDController |
| Data | ScriptableObject data | PlayerData, EnemyData |

---

## Dependencies

```
Core → Combat, UI
Combat → Data
UI → Combat, Core (events)
```

---

## Key decisions

| Decision | Choice | Why |
|----------|--------|-----|
| Manager access | [Singleton / ServiceLocator / DI] | [reason] |
| System coupling | [Events / Observer / Direct] | [reason] |
| Asset loading | [Resources / Addressables / Direct] | [reason] |
| Saves | [JSON + persistentDataPath / ...] | [reason] |

---

## Folder structure

```
Assets/
├── _source/
│   ├── Scripts/ (Core, Combat, UI)
│   ├── Data/
│   ├── Prefabs/
│   ├── Scenes/
│   └── Art/
└── ... (packages)
```

---

## Notes

[Limitations, tech debt, refactor plans.]
