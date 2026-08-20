# External Solution Reuse Gate

Use this gate after project-local, Unity built-in/package, and NeoxiderTools discovery fails to
provide a suitable solution.

## When Internet Search Is Required

Search the internet before implementing a custom solution when the task is both:

- a common/reusable Unity problem rather than unique game rules or project-specific glue; and
- nontrivial enough that a maintained package, GitHub repository, official sample, or proven
  implementation could materially reduce code, defects, or maintenance.

Typical examples include save systems, pooling, pathfinding, dialogue, inventory, localization,
input helpers, procedural generation, tweening, serialization, networking, navigation, behavior
trees, editor tooling, shaders, complex UI controls, and platform integrations.

Internet search may be skipped for an obviously tiny implementation, a narrow adapter around an
existing project API, simple data mapping/formatting, or behavior genuinely specific to this game's
rules. State the exception briefly when it is not self-evident.

## Search Order

1. Official Unity documentation, package documentation, and official samples.
2. Maintained GitHub/UPM repositories and their releases, issues, examples, and licenses.
3. Unity Asset Store or other reputable package sources when free/open options do not fit.
4. Credible technical articles, talks, and shipped/open game implementations as reference-only
   evidence.

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

WHY this is a numbered step and not advice: on a real project the agent correctly worked out that
`SpriteRenderer.color` multiplies the texture and therefore cannot whiten a sprite — and then wrote
its own flash shader, while a shader package sitting in `Assets/` had exactly that feature behind a
toggle. The analysis was right; the inventory never happened.

## Candidate Gate

Before importing, copying, or depending on a candidate, check:

- Unity version, render pipeline, input stack, scripting backend, build target, and platform fit;
- maintenance state, recent releases/commits, unresolved critical issues, and community adoption;
- license and attribution obligations; reject missing, unclear, or incompatible licenses for direct
  reuse;
- dependency footprint, editor/build hooks, security/supply-chain risk, mobile performance, and
  removal/rollback cost;
- whether a smaller adapter or reference-only implementation is safer than importing the package.

Classify each serious candidate as `direct reuse`, `adapt`, `reference-only`, or `reject`, and record
the reason in the task/reference table or final report. Do not add a package merely because one
exists.

## Custom-Code Exit

Write the smallest custom solution only after:

- no suitable ready option was found;
- candidates were rejected for concrete compatibility, license, quality, dependency, performance,
  or scope reasons; or
- the task qualifies for the tiny/project-specific exception.

Keep useful external implementations as design and edge-case references even when their code cannot
be imported.
