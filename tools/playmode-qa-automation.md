# Play Mode QA Automation

Use this reference whenever a feature needs runtime verification. A Play Mode launch plus screenshot is not enough for interactive gameplay unless the player action was driven by a test, scenario runner, input injection, UI automation, or an explicit manual/degraded exception.

## Verification Ladder

Use the strongest practical level:

| Level | Driver | Use for | Pass requires |
|---|---|---|---|
| 0 | `CompileConsole` | file-only/script sanity | compile/import complete and no new console errors |
| 1 | `PassivePlayMode` | lifecycle, startup, passive scene checks | Play Mode enters, console checked during/after |
| 2 | `ScreenshotOnly` | static visual/layout checks | screenshot reviewed by vision/agent; not enough for interactive mechanics |
| 3 | `EditModeTest` | pure logic | EditMode tests written and run |
| 4 | `PlayModeTest` | runtime behavior | PlayMode tests written and run |
| 5 | `ScenarioRunner` | multi-step gameplay/UI flows | runner drives steps, asserts state, captures evidence |
| 6 | `InputInjection` | player controls/clicks | input/UI events are simulated and asserted |
| 7 | `BuildOrBrowserE2E` | WebGL/build/platform flows | built target or browser flow is exercised |
| 8 | `ManualOnly` | truly unautomatable checks | marked degraded unless user manually verifies |

## Required Lead Decisions

Every standard/pro Feature and Task must declare:

- `Verification Driver`: one or more ladder drivers.
- `Tests Required`: `EditMode`, `PlayMode`, `Both`, or `Not Needed`.
- `Screenshot Required`: `yes`, `no`, or `on-failure`.
- `Automation Gap`: `none` or the missing hook/test/driver task.

If a feature requires player input, UI clicks, collision, spawning, scene transitions, pause, restart, or runtime state changes, `ScreenshotOnly` is not sufficient.

## Developer Responsibilities

When tests or automation are required, Developer must add the smallest test seam needed:

- `IInputProvider`, fake service, test prefab, test scene, deterministic seed, test-only harness, or Editor-only QA hook.
- EditMode tests for pure logic.
- PlayMode tests for scene/runtime behavior.
- Scenario runner or custom MCP tool for multi-step flows when PlayMode tests are awkward but runtime driving is needed.

Developer must run the required tests through MCP (`run_tests` + `get_test_job`) when available. If MCP is unavailable, use Unity CLI batchmode when practical. If neither works, mark verification `degraded`, not `pass`.

## Bounded QA Attempts

QA must not get stuck repeating the same failed verification path.

- Max QA Attempts: 2 serious attempts per required verification item, driver, test run, or screenshot capture.
- Attempt 1: run the declared driver/test/screenshot path and record evidence or the exact failure.
- Attempt 2: retry only after one practical corrective action inside QA scope, such as waiting for compile/import, reloading the scene, clearing stale Play Mode state, rerunning the test job, or using the approved CLI fallback.
- After attempt 2 fails or remains unavailable, mark the item `degraded`, not `pass`, and continue with the rest of QA.
- Degraded Report must include: attempted commands/tools, failure reason, skipped checks, available evidence, player risk, and the follow-up defect/automation-gap task.
- Do not ask the user only because the retry limit was reached. Ask only for missing assets/credentials, destructive decisions, or product choices that cannot be inferred.

## Screenshot Evidence

For visual/UI/camera/gameplay-visible features:

1. Capture screenshot during or after the driven scenario.
2. Store it under `Docs/Screenshots/iter-NN/`.
3. Review it for nonblank output, correct scene/camera, readable UI, expected state, and no incoherent overlap.
4. Link the screenshot in Task, Feature, QA, QA_AGENT, and DEV_STATE when relevant.

Tests that exercise visible runtime behavior should capture or trigger screenshot evidence when tooling supports it. If the test cannot capture screenshots, pair it with MCP screenshot after the same scenario or record why screenshot evidence is unavailable.

## QA Rules

- QA must not mark interactive behavior `pass` from `ScreenshotOnly`.
- QA must run or verify the declared driver and required tests.
- QA must check console before, during, and after Play Mode.
- QA must create/reopen a defect task when a feature lacks the required automation hook.
- QA may use vision to judge screenshots, but vision does not replace runtime input/test execution.
- QA must stop after two failed/unavailable attempts for the same check, write the degraded report, and continue.
