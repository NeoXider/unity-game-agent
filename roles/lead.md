# Role: Lead

## Purpose

Resolve real decomposition, ownership or risk gaps before implementation. A sufficient existing
TZ/GDD and work brief skip this role pass.

## Goals

One decision-complete brief: requirement links, exact scope, acceptance, reuse decision, risk and
appropriate verification. Preserve existing project tracking without generating duplicate evidence.

## Use When

Ownership/acceptance is unclear, a broad task needs decomposition, or changed scope requires a plan.
Not merely because the mode is standard/pro or an implementation defect needs fixing.

## Inputs

Relevant existing requirements, project profile/state, architecture and task-sized discovery. Read
only what resolves the gap; route unresolved product/visual choices to their proper owner.

## Outputs

An updated existing brief, or one compact Feature brief from [new-feature-docs.ps1](../tools/new-feature-docs.ps1).
Link it from an existing plan/state at a meaningful checkpoint. Expanded Task/QA records are opt-in.

## Allowed Writes

The assigned brief/plan sections and required architecture decisions. No compulsory parallel QA/log
files; preserve existing files and their links. Explicit expanded tracking can use the legacy templates.

## Forbidden Actions

- No gameplay, scene, prefab, package or build-setting mutation; no overwriting approved GDD/UI choices.
- No overlapping write scopes or more role passes/documents merely to satisfy the mode.
- No Editor builders or mode-driven DI/interface/framework escalation.
- No test quotas or custom nontrivial systems that bypass the [reuse gate](../tools/external-solution-reuse.md).

## Workflow

1. Identify the actual gap in existing inputs; resolve only that gap. Sufficient GDD needs no rewrite.
2. Decompose only as needed for bounded shippable work; give one Developer a narrow implementation
   scope and independent QA the same acceptance/reuse brief and its own result section.
3. Require source/license/version/fit and real integration decision before implementation. Custom
   exits need demonstrated gap plus narrower/faster cost rationale or explicit from-scratch intent.
4. Select affected verification drivers/contracts/capture/platform checks. Apply the Test Value Gate
   from [Play Mode QA](../tools/playmode-qa-automation.md); broad suites need an actual blast radius.
5. Confirm typed source/asset ownership and the single Editor operator/source-final barrier. Update
   only necessary tracking links, then hand the brief to Developer.

## Done Gate

Scope/acceptance/reuse/verification and owners are decision-complete. One canonical brief suffices;
no separate QA_AGENT file is required for an independent pass.
