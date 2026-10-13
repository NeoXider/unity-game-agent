# Mode: Standard

**For:** A complete small game or scoped feature with independent player QA and proportionate tracking.
Mode changes verification depth, not architecture complexity or document count.

## INTAKE / PLAN

- Reuse a sufficient existing TZ/GDD/UI brief. Game Designer/Designer/Lead run only for unresolved
  design, visual or planning gaps. Ask only about material ambiguity.
- One concise work brief names requirements, scope/files, acceptance, reuse decision, driver/tests,
  capture needs and risk. Existing plans can link it; no compulsory new spec/log/checklist tree.
- Before nontrivial work, pass the [reuse gate](../tools/external-solution-reuse.md): project/built-ins
  -> installed NeoTools -> compatible licensed libraries/assets -> allowed ready-project slices.
  Stop at a fit. Custom requires demonstrated gap/poor fit and narrower/faster rationale, or explicit
  from-scratch intent. Tiny glue needs local discovery, not a broad web search.

## BUILD / QA LOOP

1. One Developer subagent implements the scoped brief, preserves current contracts, and hands off
   source-final files after relevant compile/import/console and the smallest useful selfcheck.
2. A second independent QA subagent checks actual reuse integration and drives the changed player
   outcome/contracts. Do not repeat a full Developer runtime QA round before handoff.
3. QA writes its own pass/fail/blocked section in the same brief. A defect includes one reproduction,
   expected/actual, evidence/revision and next owner/action; Developer fixes and hands back to QA.
4. Rerun failed/affected checks only. Cite unaffected evidence with source revision/scope/environment
   and why the diff cannot invalidate it; stale affected evidence and uncertainty require a recheck.
5. At most two genuine failed attempts per path, with a concrete correction before retry. Return the
   concise blocker to Developer/operator; unrelated safe work can continue, the blocked feature is
   not done. No competing harness/framework or metadata-audit loop.
6. Optional GDD alignment follows QA, checks the existing requirements against evidence and does not
   regenerate the spec. Orchestrator closes/updates links at meaningful checkpoints after required checks pass.

One operator owns Unity/import/scene/assets/play/tests; code writers have disjoint scopes and freeze
source before its single batch compile. If delegation is unavailable/prohibited, disclose local role
switching and missing independent QA. Preserve the same outcome gates.

## Verification

- Docs-only work invokes no Unity. Changed C#/assets need relevant compile/import + console comparison.
- Changed runtime/player behavior needs an actual driven Play Mode scenario; console is checked
  during/after it. Interactive input/UI/collision/spawn/pause/restart cannot pass from screenshots alone.
- Visual/runtime-visible changes need reviewed, correctly timed captures. Changed controls must be
  reachable through the real hit/input path and produce an observable state change.
- Apply the Test Value Gate in [Play Mode QA](../tools/playmode-qa-automation.md); no coverage quota,
  empty test pass, reflection/source checks as player proof, or tests that mutate authored content.
- Broader suites, builds, large manifests, profiler or full-game walkthroughs need actual affected
  architecture/protocol/package/scene/data/platform risk, release/integration context or user request.
- Native-input/network/platform claims require their actual target path; engine/unit checks alone
  cannot prove them. Save only changed scenes through the operator.

## Docs

One existing/new Feature or Task brief is the default acceptance/reuse/evidence record. Keep existing
DEV_STATE/DEV_PLAN/DEV_LOG/AGENT_MEMORY links current where useful; do not copy results into all of them.
Separate Task/QA/QA_AGENT records are explicit expanded tracking (`-DetailedTracking`, or legacy
`-CreateIndependentQa` for a requested duplicate). Preserve existing profiles/docs without migration.

## Code Style

- Clear responsibility separation; MonoBehaviours for scene behavior, SO for useful authored data.
- Private `[SerializeField]` Inspector fields, cached components, explicit prefab references.
- Direct typed references/events or UnityEvents where they fit existing composition.
- New project scripts stay in the global namespace; preserve existing namespaces when editing.
  No collateral namespace migration. XML docs only for public/non-obvious contracts.
- Comments explain non-obvious intent. Logs are actionable lifecycle/state diagnostics, not per-frame
  spam or a quality quota. Use error/warning levels for actionable failures/recoverable state.

## Architecture / Input

Preserve project architecture and input stack. Feature-owned typed folders remain required in all
modes; follow [project-structure.md](../tools/project-structure.md). Editor builders are forbidden;
author scenes/prefabs through the single Unity/MCP operator. No extra infrastructure or DI merely
because the mode is standard. Keep TextMeshPro/null-safe UI rules from the main skill.

## Final Gate

Required changed-behavior/risk checks pass, reuse is proved, and the brief links valid evidence and
remaining risk. Missing/unsupported required checks mean blocked/unverified, not passed. A full-game
release pass is warranted for release work; it is not mandatory for each reversible feature edit.
