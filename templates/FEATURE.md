# Feature: [FEAT-NNN Name]

**Status:** planned | in_progress | qa | done | blocked  
**Mode:** standard | pro  
**Epic:** [Epic name]  
**SubEpic:** [SubEpic name or none]  
**Created:** YYYY-MM-DD HH:MM  
**Updated:** YYYY-MM-DD HH:MM

---

## Purpose

[Why this feature exists and what player/user behavior it enables.]

## Player/User Behavior

- [Expected visible behavior]
- [Important interaction path]
- [Failure/edge behavior]

## Scope

**Included**
- [Behavior/system]

**Excluded**
- [Out of scope behavior/system]

## Reuse And References

| Candidate | Source | Reuse mode | Decision | Notes |
|-----------|--------|------------|----------|-------|
| [Built-in/package/sample/game reference] | [path/link] | direct reuse/adapt/reference-only | use/skip | [reason] |

## Affected Systems/Files

- [Assets/...]
- [Packages/...]
- [ProjectSettings/...]

## Tasks

- [ ] [TASK-NNN-name](../Tasks/TASK-NNN-name.md) - [short purpose]

## Acceptance Criteria

- [ ] [Concrete behavior is true]
- [ ] [Reset/restart/lifecycle behavior is handled]
- [ ] [Pause/time scale handled if relevant]
- [ ] [No new console errors]

## Verification Plan

- Verification Driver: CompileConsole | PassivePlayMode | ScreenshotOnly | EditModeTest | PlayModeTest | ScenarioRunner | InputInjection | BuildOrBrowserE2E | ManualOnly
- Tests Required: EditMode | PlayMode | Both | Not Needed
- Regression/contract protected by tests: [named behavior and realistic failure] | Not Needed
- Test Value Gate: pass | rejected; reason: [why each test is worth maintaining]
- Screenshot Required: yes | no | on-failure
- Automation Gap: none | [missing hook/test/driver task]
- Max QA Attempts: 2 before degraded report and continue
- [ ] Compile/import check
- [ ] Console baseline/current comparison
- [ ] Play Mode scenario: [scenario]
- [ ] Screenshot/visual check: [required or skipped reason]
- [ ] Tests/build validation: [required or skipped reason]
- [ ] Project structure audit and Editor Builder ban

## QA

- Agent checklist: [Docs/QA/FEAT-NNN-name-qa.md](../QA/FEAT-NNN-name-qa.md)
- Independent QA: not planned | [QA_AGENT checklist link, only when an independent pass is scheduled]

## Rollback Risk

[Low/medium/high and what would need reverting.]

## Done Evidence

- Tasks complete: 0 / N
- Last Play Mode result: pending
- Last console result: pending
- Verification driver result: pending
- Screenshot(s): pending
- Tests/build: pending
