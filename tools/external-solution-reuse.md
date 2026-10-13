# External Solution Reuse Gate

This is the implementation and independent-QA gate for the **Prime Rule** in `SKILL.md`, covering
nontrivial mechanics, models/maps/animations, shaders/VFX/UI and common tools. The work brief holds
the decision; no separate receipt file, manifest or reporting framework is required.

## When Internet Search Is Required

After a relevant project/built-in/installed-Neo miss, external search is mandatory for nontrivial
reusable work. Search only the current capability gap, stopping at a suitable fit. A game-specific
label is not an exception for a common controller, inventory, shader or save subsystem.

Tiny glue/data mapping or a narrow adapter to an already selected system needs local discovery only.
Explicit from-scratch requests can exit reuse after recording that instruction. Existing discovery
can be cited rather than repeated when task scope, candidate version and permissions are unchanged;
refresh affected entries after changes. No whole-internet research for each tiny edit.

## Search Order

1. Project/vendor folders, built-ins, installed packages and official samples/docs.
2. Installed NeoxiderTools source/docs/samples, respecting project stack choices.
3. Compatible licensed libraries/assets: maintained UPM/GitHub, official sources, reputable stores.
4. Allowed ready-project/game slices; public talks/articles/game examples may be reference-only.

Use primary sources for technical decisions whenever possible. Do not rely on a search-result
snippet when the repository, documentation, release notes, or license can be inspected directly.

## Pre-Vetted Shortlists

Some problem areas already have a checked answer in this skill. Consult them before running a generic
search, and record why a listed package was rejected if you do not use it:

- **uGUI visual effects** (particles in a Canvas, soft/shaped masks, shadow/glow/blur/dissolve):
  the three MIT `com.coffee.*` packages in
  [../project-profiles/plain-ugui.md](../project-profiles/plain-ugui.md) → "Ready uGUI effect packages".
- **Casual/mobile gameplay systems** on a NeoxiderTools project: the reuse table in
  [../patterns/casual-neoxider/pattern.md](../patterns/casual-neoxider/pattern.md).
- **Shader-driven effects on any surface** (tint, outline, shadow, glow, dissolve, status effects,
  UV motion, colour grading): **Sprite Shaders Ultimate**, if the project already owns it — one
  shader family covering uGUI, SpriteRenderer, 2D-lit URP, 3D meshes and TextMeshPro. See
  [../project-profiles/plain-ugui.md](../project-profiles/plain-ugui.md) → "Sprite Shaders Ultimate".
- **Common libraries and how to install them**: [libraries-setup.md](libraries-setup.md).

## Inventory Before Searching

Search the project **before** searching the internet. A paid asset or a package installed months ago
already answers a surprising share of "I need a shader / an effect / a UI helper" tasks, and nothing
about the request will tell you it is there.

Check, in this order:

1. third-party folders under `Assets/` (asset-store packages land there, not in `Packages/`);
2. `Packages/manifest.json` and `Library/PackageCache/`;
3. the pattern's reuse table and the shortlists above;
4. only then an external search, and only then custom code.

An installed shader/controller that already meets the behavior must not be replaced by parallel
homemade code because writing it feels easier.

## Candidate Gate

Before importing, copying, or depending on a candidate, check:

- Unity version, render pipeline, input stack, scripting backend, build target, and platform fit;
- relevant maintenance/compatibility risks, dependency footprint and removal cost;
- license, provenance and attribution for both code and each imported asset; unknown/incompatible
  permission blocks import/copy. MIT package code does not grant rights to bundled models;
- task-relevant editor/build hooks, performance, deterministic/network behavior and platform fit;
- whether a smaller adapter or reference-only implementation is safer than importing the package.

Record a compact row in the brief: candidate/source + version, license/asset permission, `direct
reuse` / `adapt` / `reference-only` / `reject`, decision and exact missing capability. Existing project
assets can cite their recorded provenance. A licensed reference is useful even when importing it is
inappropriate, but reference-only study is not proof of integrated reuse.

## Custom-Code Exit

Nontrivial custom work is allowed only after demonstrated misses/poor fit **and** a narrower/faster
cost rationale, or an explicit user from-scratch instruction. Name the rejected capability and
integration/adaptation cost versus custom scope; estimates state assumptions, not invented precision.
"Easier to code", a small line count, cloning a repository or moving the candidate beside the homemade
implementation is not an exit. A genuine unique-rule gap still records the local miss.

## Integration And QA Gate

Before implementation, Developer checks the receipt and stops on missing discovery/permission/fit
evidence. Handoff names the reused API/module or asset and the changed integration/wiring path.
Independent QA inspects the actual diff/import/wiring: cloning/downloading is discovery, and a
parallel homemade motor beside a suitable ready controller fails this gate. Missing receipts, false
integration or unlicensed imports return to Developer before acceptance. A valid adapter/custom exit
then still needs the changed-player outcome checks; reuse does not prove gameplay works.
