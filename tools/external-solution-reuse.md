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
