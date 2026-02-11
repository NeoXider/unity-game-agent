# Core mechanics — reusability and quick iteration

How to structure core mechanics (movement, health, input, combat) so that changing gameplay or moving to another project does not require rewriting from scratch.

---

## Principles

1. **Data in SO, logic in components** — all numbers, curves, presets in ScriptableObject. Changing balance/mode = different SO set, same code.
2. **One component, one mechanic** — `Movement`, `Health`, `InputProvider` separate. Replacing movement/input = replace one component without touching the rest.
3. **Role-based names, not game name** — `PlayerController`, `CharacterHealth`, not `SuperPuzzleHero`. Code and prefabs stay portable.
4. **Events over hard links** — health dropped → event; UI/other systems subscribe to events, not to a concrete class. Swapping implementation does not break subscribers.
5. **Contracts (interfaces) where variants exist** — input (keyboard/touch/replay), damage (physical/magic), movement (top-down/platformer). One system depends on the interface; plug in the right implementation.

---

## Minimal core (most often reused)

| Domain | Purpose | Change without rewriting |
|--------|---------|---------------------------|
| **Input** | Read input (move, jump, attack, etc.) | Replace `IInputProvider` implementation / component; bindings in SO or Input Action Asset. |
| **Movement** | Movement (top-down, platformer, isometric) | Separate component + SO (speed, jumpForce, gravity). Replace component or SO. |
| **Health** | Current/max health, taking damage, death | Component + SO (maxHealth, invulnTime). Events: `Damaged`, `Died`. Reused for player, enemies, objects. |
| **Combat** | Dealing/receiving damage, zones, projectiles | Separate components: `DamageDealer`, `DamageReceiver` (or shared `Health`). Damage params in SO. |

The rest (progression, abilities, inventory) sits on top of core; changed more often but relies on these layers.

---

## Structure for reusability

```
_source/Scripts/
├── Core/                    # Reusable core
│   ├── Input/
│   │   ├── IInputProvider.cs
│   │   └── InputProviderPlayer.cs (or InputProviderReplay)
│   ├── Movement/
│   │   ├── MovementBase.cs   # abstract or interface
│   │   ├── MovementTopDown.cs
│   │   └── MovementPlatformer.cs
│   ├── Health/
│   │   ├── Health.cs         # + HealthData SO
│   │   └── IDamageReceiver.cs (optional)
│   └── Combat/
│       ├── DamageDealer.cs
│       └── DamageData.cs (SO)
├── Data/                    # SO assets (per-game settings)
│   ├── PlayerMovementData.asset
│   ├── HealthData_Player.asset
│   └── ...
└── Features/                # Game-specific
    ├── Feature_Player/
    ├── Feature_Enemies/
    └── ...
```

Rule: **Core** does not know about Feature_* or game name. Feature scripts use Core and Data.

---

## Patterns for quick iteration

### Input

- **Interface** `IInputProvider` with methods/properties: `Vector2 Move`, `bool Jump`, `bool Attack`, etc.
- Implementations: keyboard+mouse, touch, gamepad, replay — switch by replacing component or SO with binding preset.
- Prefer Unity Input System (Input Action Asset) — rebinding without code.

### Movement

- **One movement component per object**, fed from SO (speed, jumpForce, gravityScale) and from `IInputProvider` (or explicit reference to input component).
- Different movement types — different classes (`MovementTopDown`, `MovementPlatformer`) but shared contract (e.g. `IMovement` with `SetVelocity`, `Teleport`) or base class with virtual methods. Changing type = replace component + change SO.

### Health and damage

- **Health** — component with SO (maxHealth, invulnDuration). Events: `OnDamaged(float, object)`, `OnDied()`.
- **DamageDealer** — collider/trigger or ray; on contact finds `Health` or `IDamageReceiver` and calls `TakeDamage`. Amount/type from SO.
- Changing rules (shield, armor, damage types) — extend SO and optionally Health subclass; no rewrite of movement/input.

### Combat (extend without breaking core)

- Damage zones, projectiles, knockback — separate components that work with `Health`/`IDamageReceiver` and optionally `Rigidbody2D`.
- Params (radius, damage, knockback force) in SO. New attack type = new prefab + new SO, no Core edits.

---

## What not to put in core

- Game-specific logic (combos, skills, inventory) — keep in Feature_*.
- Game name, unique terms — only in config/localization and Feature layer.
- Hard references to specific character/enemy type — rely on interfaces (IDamageReceiver, IMovable) or base components (Health, Movement).

---

## Checklist before a "big rework"

- [ ] Mechanic params in SO? (can you change the game by swapping SO?)
- [ ] Input abstracted? (can you plug another Input without editing movement/combat?)
- [ ] Movement and health separate components? (can you replace one without touching the other?)
- [ ] Systems connected via events or interfaces? (swapping implementation does not break subscribers?)
- [ ] No game names or Feature-specific code in Core? (can you move Core folder to another project?)

If yes — rework is about swapping components, SO, and Feature modules, not rewriting from scratch.
