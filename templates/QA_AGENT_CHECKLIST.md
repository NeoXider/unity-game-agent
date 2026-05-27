# QA Agent Checklist: [FEAT-NNN Name]

**Feature:** [../Features/FEAT-NNN-name.md](../Features/FEAT-NNN-name.md)  
**Source checklist:** [../QA/FEAT-NNN-name-qa.md](../QA/FEAT-NNN-name-qa.md)  
**Mode:** standard | pro  
**Created:** YYYY-MM-DD HH:MM  
**Updated:** YYYY-MM-DD HH:MM

---

## QA Agent Rules

- Verify only player/user-facing behavior and checklist expectations.
- Do not rely on implementation assumptions from the developer pass.
- Reproduce each step independently when tooling allows.
- Record evidence for every pass/fail.
- If a check fails, create or request a defect task page under `Docs/Tasks/`.
- Do not retry the same blocked check more than twice. After attempt 2, write a degraded report, create a follow-up task, and continue.

## Preconditions

- [ ] Unity compile/import is idle.
- [ ] Console baseline is recorded.
- [ ] Required scene is loaded.
- [ ] Feature tasks are marked done.
- [ ] Verification Driver is declared in the Feature/Task.
- [ ] Required EditMode/PlayMode tests have results or explicit skipped reasons.
- [ ] Screenshot requirement is declared.

## Verification Driver

- Driver: CompileConsole | PassivePlayMode | ScreenshotOnly | EditModeTest | PlayModeTest | ScenarioRunner | InputInjection | BuildOrBrowserE2E | ManualOnly
- Tests Required: EditMode | PlayMode | Both | Not Needed
- Screenshot Required: yes | no | on-failure
- Automation Gap: none | [missing hook/test/driver task]
- Interactive behavior: yes | no
- Max QA Attempts: 2

## Independent Checks

| # | Step | Expected | QA-agent result | Evidence |
|---|------|----------|-----------------|----------|
| 1 | [Player action or setup] | [Expected result] | pending | [driver/test/screenshot/log] |

## Edge And Regression Checks

| # | Step/Area | Expected | QA-agent result | Evidence |
|---|-----------|----------|-----------------|----------|
| E1 | [Reset/restart/pause/lifecycle/related behavior] | [Expected result] | pending | [screenshot/log/test] |

## QA Agent Summary

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
