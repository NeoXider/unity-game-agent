# Mode: Pro

**For:** Long-lived or high-risk Unity work that needs stronger evidence, recovery behavior,
platform/build validation, and durable project tracking.

`pro` changes rigor, not architecture style. It does not imply Clean Architecture, DI,
ServiceLocator, mandatory interfaces/services, more managers, or deeper folders.

## Scope

- Any size project may use `pro` when correctness or release risk justifies it.
- Work on one small shippable behavior or defect at a time.
- Preserve the existing architecture unless a concrete requirement proves it insufficient.

## INTAKE

- Inspect the real project, docs, packages, scenes, console, build target, tests, and current dirty
  worktree before planning.
- Resolve product behavior, platform constraints, save/recovery requirements, verification driver,
  and rollback surface.
- Ask only for decisions that materially change behavior or architecture.

## PLAN

- Break work into meaningful Features and implementation tasks; do not create one document per tiny
  edit merely to satisfy a count.
- Record acceptance criteria, affected ownership boundaries, runtime driver, focused tests (if any),
  screenshot needs, build/platform checks, and rollback risk.
- Reuse sufficient existing TZ/GDD and one work brief; run design/Lead only for real gaps.
- Before nontrivial implementation, pass the [reuse gate](../tools/external-solution-reuse.md) with
  a candidate/license/version/fit decision; handoff must prove actual integration.
- Treat architecture escalation as an explicit decision with evidence, not a mode default.
- When two or more Unity-bound tasks run concurrently, isolated workspaces are **ON by default**.
  Follow [parallel-editors.md](../tools/parallel-editors.md): one worktree/Library/Editor/MCP instance
  per task, one writer each, explicit scene/prefab ownership and QA before orchestrator integration.
  Commit canonical changes needed by the tasks before creating workspaces from their chosen base.

## BUILD

- Follow [../tools/project-structure.md](../tools/project-structure.md) for runtime, Editor, tests,
  Prefabs, Settings, Sprites, and other typed assets.
- Editor builders are forbidden. Author scene/prefab/config state directly through Unity/MCP and use
  read-only validators for repeatable checks.
- Make the smallest change that satisfies the behavior. Preserve serialized names and package code.
- After each meaningful code task: compile/import readiness and console comparison.
- Hand source-final work to a second independent QA subagent after relevant compile/selfcheck;
  QA drives changed runtime behavior, checks console and captures/reviews relevant visual evidence.
- One operator per workspace serializes all Editor/import/assets/play operations; separate workspaces
  run concurrently. Pin MCP to that workspace and pass the RAM/disk gate before another Editor opens.
  Tests and validation builds use a closed workspace headlessly and exit. No repeated full Developer
  runtime self-QA before independent QA; no doc-only Unity calls.
- Update state/log documents at meaningful verified checkpoints, not after every tool call.

## Architecture

- Prefer project-local feature ownership and explicit Unity composition.
- Use MonoBehaviours for scene behavior and plain C# objects for deterministic rules when useful.
- Use ScriptableObjects for authored/shared configuration when they improve authoring or reuse.
- Use direct typed references and C# events when sufficient.
- Add an interface only for a real dependency boundary, multiple implementations, platform adapter,
  or demonstrated test seam. Do not add one merely because a class is called a service.
- Add DI/ServiceLocator only when the existing composition cannot safely manage real lifetimes or
  dependency variation; document the concrete problem, alternatives, cost, and rollback.
- Add an asmdef at a meaningful dependency/compile boundary, not for every folder.
- Add pooling only when spawn/despawn frequency or profiling justifies it.
- Preserve the project's input stack; `pro` does not force migration to the New Input System.

## Code Quality

- Follow existing namespaces; for a new long-lived project, namespace by product and feature.
- Keep serialized fields private with `[SerializeField]` and preserve names where possible.
- Cache required components and keep lifecycle ownership explicit.
- Write XML docs only for public APIs and non-obvious contracts.
- Write comments for non-obvious intent, constraints, and workarounds. Do not replace comments with
  runtime logs.
- Log only actionable failures or diagnostic state; no logging quota and no per-frame spam.

## Testing

- Apply the Test Value Gate in [../tools/playmode-qa-automation.md](../tools/playmode-qa-automation.md).
- Add the smallest focused test only when it protects a named domain invariant, player flow,
  serialization/recovery contract, platform behavior, or observed regression.
- Prefer EditMode for deterministic rules and PlayMode/scenario drivers for actual Unity lifecycle,
  input, UI, physics, scene, or integration behavior.
- Do not add reflection-heavy private-method tests, `DoesNotThrow` tests, source/YAML scans, exact
  layout locks, duplicated model/service/presenter tests, or tests of Unity/package behavior without
  a concrete regression that cannot be verified more directly.
- Structural rules belong in read-only audit/CI scripts, not Unity test assemblies.
- Run focused affected tests after a task. Run broader integration/full suites at milestones,
  release/build gates, dependency changes, or when blast radius justifies them.
- A green suite is supporting evidence, not a substitute for Play Mode/runtime verification.

## VERIFY

- Confirm readiness after compilation/domain reload through that workspace's operator.
- Exercise the changed path and relevant recovery/reset/reload behavior.
- Compare console baseline with current state.
- Review screenshots for visual work and use measurements for layout claims.
- Run focused tests and any justified broader regression suite.
- After corrections, rerun only failed/affected checks. Cite unchanged evidence with source
  revision/scope/environment and why the diff cannot invalidate it; uncertainty requires rechecking.
- Run platform/build validation when settings, serialization, packages, scenes-in-build, native input,
  or release behavior changed.
- Use profiler evidence for performance claims or systems with a plausible performance risk; do not
  profile merely because the mode is `pro`.

## Docs And QA

- Keep `DEV_STATE`, `DEV_PLAN`, `DEV_LOG`, `AGENT_MEMORY`, and `ARCHITECTURE` proportionate and current.
- One existing task/feature brief holds acceptance/reuse decisions, Developer handoff and QA-owned
  result/defects. Independent QA does not require separate QA/QA_AGENT/checklist/log files.
- Expanded tracking is explicit opt-in; old profiles/docs remain readable without migration churn.
- Record evidence, skipped checks, and remaining risk. Do not duplicate the same evidence into every
  document when links are sufficient.
- After two genuine failures of the same path, return a concise fail/blocked reproduction with
  evidence/revision and owner/action. Required unavailable/empty checks remain unverified; only
  unrelated safe work may continue. No competing harness or metadata audit loop.
- Optional GDD alignment follows QA and compares existing requirements with evidence, without
  recreating the specification or rerunning unrelated checks.

## Final Gate

- [ ] Existing architecture preserved or an approved, evidence-backed change is documented
- [ ] Feature-owned project structure passes; no Editor builders or mixed asset/code dumps exist
- [ ] Compile/import ready and no new attributable console errors
- [ ] Changed runtime/player behavior driven and verified in Play Mode when relevant
- [ ] Visual evidence measured/reviewed when relevant
- [ ] Focused valuable tests pass; broader suite/build/profiler checks run only when justified
- [ ] Save/restart/pause/scene reload/platform lifecycle checked where relevant
- [ ] Docs contain current outcome, evidence, skipped checks, rollback surface, and remaining risk
