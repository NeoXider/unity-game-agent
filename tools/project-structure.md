# Unity Project Structure

Use this reference for every Unity task and every mode, including `fast` and Quick Fix. Mode changes
delivery cadence, not folder hygiene.

Run the read-only policy check with:

```powershell
& tools/audit-project-structure.ps1 -ProjectRoot <UnityProjectRoot>
```

## Existing Project

Preserve the project's established authoring root and naming. Extend its existing feature layout
instead of imposing a migration. Still enforce these boundaries:

- runtime code, editor-only code, tests, and non-code assets do not share folders;
- new files belong to a named feature/system or screen, never a generic dumping ground;
- third-party/package content stays outside the project-owned authoring root;
- do not move existing files merely to match this reference unless the user approves a migration.

## New Project Default

Use `Assets/_source` as the project-owned authoring root:

```text
Assets/_source/
|-- Scripts/<Feature>/<CodeArea>/
|-- Editor/<Feature>/
|-- Scripts/Tests/<Feature>/EditMode/
|-- Scripts/Tests/<Feature>/PlayMode/
|-- Scenes/
|-- Prefabs/<Feature>/
|-- Settings/<Feature>/
|-- Sprites/<FeatureOrScreen>/
|-- Materials/<Feature>/
|-- Animations/<Feature>/
|-- Audio/<Feature>/
|-- Models/<Feature>/
|-- Textures/<Feature>/
`-- Fonts/
```

Documentation may live at project-root `Docs/` or under the existing authoring root (for example
`Assets/_source/Docs/`). Resolve and reuse the project's current canonical docs root; never create a
second competing docs tree. New-project bootstrap uses project-root `Docs/`.

`CodeArea` is a pragmatic responsibility name such as `Core`, `Runtime`, `Lifecycle`,
`Presentation`, `Input`, `Economy`, or `Result`. These names organize a feature; they do not imply
Clean Architecture layers. Use only the folders the feature needs.

## Hard Rules

- `Scripts/<Feature>` contains runtime C# and runtime asmdefs only.
- Editor-only C# lives under `Editor/<Feature>` with an Editor-only asmdef when an asmdef is used.
- Tests live only under `Scripts/Tests/<Feature>/EditMode|PlayMode`; test asmdefs use
  `defineConstraints: ["UNITY_INCLUDE_TESTS"]` so they cannot enter player builds.
- Prefabs, ScriptableObjects, sprites, materials, animations, audio, models, and textures live in
  their typed roots, then under the owning feature/screen. Do not put them under `Scripts`.
- Do not create redundant roots such as `_source/Features`, `Scripts/<Feature>/Scripts`,
  `Scripts/<Feature>/Prefabs`, or `Scripts/<Feature>/Settings`.
- Do not leave project-owned code or assets loose directly under `Assets`, `_source`, `Scripts`,
  `Editor`, `Prefabs`, `Settings`, or `Sprites`.
- Namespace policy is mode-specific: new `fast` and `standard` project scripts stay in the global
  namespace; `pro` follows the existing project and may use product/feature namespaces. Never strip
  an existing namespace merely to satisfy the selected mode. Create asmdefs only at meaningful
  dependency boundaries, never as a mode-driven quota.

## Editor Builder Ban

Tracked Editor builders are forbidden. Do not add or keep `*Builder.cs`, `*SetupBuilder.cs`, menu
commands, tests, or bootstraps that generate, rebuild, rewire, or save gameplay scenes, prefabs, UI,
or configuration assets.

Why: a builder creates a second source of truth and can overwrite hand-authored scene/prefab work.
Idempotency does not make it safe. A test that proves a builder is idempotent still runs the unsafe
mutation and is not acceptable protection.

Use these alternatives:

- author and wire scenes/prefabs directly through Unity/MCP with Undo and explicit saves;
- create ScriptableObject assets directly through Unity/MCP;
- use read-only validators, inspectors, and audit scripts for repeatable checks;
- for a one-time migration, perform the migration directly, verify the resulting serialized assets,
  and remove the temporary migration code before handoff. Do not commit it as project infrastructure.

Before handoff, scan the project-owned Editor root for builder filenames/classes and scan tests for
scene/prefab/asset writes. Any hit is a blocker until removed or explicitly approved by the user.
