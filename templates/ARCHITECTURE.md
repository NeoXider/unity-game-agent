# Project architecture

Record only decisions that constrain implementation. Development mode controls verification rigor;
it does not select an architecture style.

---

## Architecture boundaries

- Style: [existing project style / pragmatic feature-first]
- Explicitly not introduced: [Clean layers / DI / ServiceLocator / CQRS / universal event bus unless justified]
- Scene composition: [direct Unity/MCP authoring; no tracked Editor builders]
- Runtime ownership: [feature controllers/components and their responsibilities]
- Cross-feature communication: [typed references / C# events / existing project mechanism]

---

## Feature dependency map

| Feature/system | Owns | Depends on | Must not depend on |
|----------------|------|------------|--------------------|
| [Feature] | [runtime state/config/view] | [narrow dependencies] | [forbidden coupling] |

Add asmdefs only at meaningful dependency or compile boundaries.

---

## Project structure

Follow `tools/project-structure.md`. For a new project:

```text
Assets/_source/
|-- Scripts/<Feature>/<CodeArea>/
|-- Editor/<Feature>/
|-- Scripts/Tests/<Feature>/EditMode|PlayMode/
|-- Prefabs/<Feature>/
|-- Settings/<Feature>/
|-- Sprites/<FeatureOrScreen>/
|-- Materials/ Animations/ Audio/ Models/ Textures/ Fonts/
|-- Scenes/
`-- Docs/
```

`Core`, `Runtime`, `Lifecycle`, and `Presentation` are pragmatic responsibility folders inside a
feature, not Clean Architecture layers. Use only those the feature needs.

---

## Data, saves, and lifecycle

| Decision | Choice | Why / invariant |
|----------|--------|-----------------|
| Authored configuration | [ScriptableObject / serialized fields] | [reason] |
| Save ownership | [per feature / existing service] | [keys, versioning, idempotency] |
| Scene lifecycle | [entry scenes, persistent objects] | [reason] |
| Reset/restart/reload | [behavior] | [recovery contract] |

---

## Test and verification strategy

- Named high-risk invariants/regressions: [list]
- Focused EditMode tests: [list or Not Needed]
- PlayMode/scenario drivers: [list]
- Visual evidence: [screens/resolutions]
- Build/platform gates: [list]
- Structural validation: read-only audit/CI; never an Editor builder or project-mutating Unity test.

---

## Architecture escalation decisions

Record an interface, service, DI container, global manager, event bus, pooling layer, or new package
only when a concrete problem requires it:

| Proposed mechanism | Concrete problem | Simpler alternatives rejected | Cost/risk | Rollback |
|--------------------|------------------|------------------------------|-----------|----------|
| [none] | | | | |
