# QA Checklist: [FEAT-NNN Name]

**Feature:** [../Features/FEAT-NNN-name.md](../Features/FEAT-NNN-name.md)  
**Mode:** standard | pro  
**Scene/build target:** [scene/platform]  
**Agent owner:** [agent/session]  
**Created:** YYYY-MM-DD HH:MM  
**Updated:** YYYY-MM-DD HH:MM

---

## Preconditions

- [ ] Unity compile/import is idle.
- [ ] Console baseline is recorded.
- [ ] Required scene is loaded.
- [ ] Required test data/assets are present.
- [ ] Verification Driver is declared in the Feature/Task.
- [ ] Required EditMode/PlayMode tests are listed or explicitly marked Not Needed.
- [ ] Screenshot requirement is declared.
- [ ] Max QA Attempts is 2 before degraded report and continue.

## Verification Driver

- Driver: CompileConsole | PassivePlayMode | ScreenshotOnly | EditModeTest | PlayModeTest | ScenarioRunner | InputInjection | BuildOrBrowserE2E | ManualOnly
- Tests Required: EditMode | PlayMode | Both | Not Needed
- Screenshot Required: yes | no | on-failure
- Automation Gap: none | [missing hook/test/driver task]
- Interactive behavior: yes | no
- Max QA Attempts: 2

## Functional Checks

| # | Step | Expected | Agent result | Evidence |
|---|------|----------|--------------|----------|
| 1 | [Player action or setup] | [Expected result] | pending | [driver/test/screenshot/log] |

## Edge Cases

| # | Step | Expected | Agent result | Evidence |
|---|------|----------|--------------|----------|
| E1 | [Reset/restart/pause/lifecycle/invalid input] | [Expected result] | pending | [screenshot/log/test] |

## Regression Checks

| # | Area | Expected | Agent result | Evidence |
|---|------|----------|--------------|----------|
| R1 | [Related existing behavior] | [Still works] | pending | [screenshot/log/test] |

## Agent QA Summary

- Result: pending | pass | fail | degraded
- New console errors: pending | none | [list]
- Play Mode scenario: [summary]
- Verification driver result: [summary]
- EditMode tests: pass | fail | skipped ([reason])
- PlayMode tests: pass | fail | skipped ([reason])
- Screenshot(s): [path]
- Defect task created/reopened: [none or link]

## Degraded Report

- Required when any check cannot be completed after 2 attempts.
- Attempt 1: [command/tool/action + result]
- Attempt 2: [command/tool/action + result]
- Failure reason: [why QA could not complete the check]
- Skipped Checks: [exact checks not verified]
- Available evidence: [logs/screenshots/tests/none]
- Risk: [player/user risk]
- Follow-up task: [Docs/Tasks/TASK-NNN-...md]
