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

## Test Value Gate

Write a test only when all answers are concrete:

1. What player-facing behavior, domain invariant, serialization contract, or previously observed
   defect can regress?
2. What production action is exercised?
3. What observable output/state proves success without repeating the production algorithm?
4. Why is this cheaper and more stable than a focused Play Mode scenario, validator, compile check,
   screenshot measurement, or manual inspection?

If these cannot be answered, set `Tests Required: Not Needed` and use the appropriate verification
driver. `pro` increases evidence quality; it does not create a test quota.

Valuable tests commonly cover deterministic rules, money/reward idempotency, save/reload recovery,
state transitions, platform input, destructive regressions, and critical scene wiring.

Reject or consolidate tests that only:

- assert a class, private field, method name, folder, or default constant exists;
- use reflection to drive private implementation when a public behavior can be exercised;
- assert `DoesNotThrow`, non-null references, or exact serialized values without a meaningful outcome;
- duplicate the same contract across model, service, presenter, scene, and end-to-end fixtures;
- mirror the production algorithm as the expected-value oracle;
- test Unity, a third-party package, or framework behavior owned outside the project;
- scan source text/YAML as a Unity test when a read-only audit script can enforce the rule faster;
- lock exact RectTransform coordinates, object names, or visual composition as a substitute for
  measured multi-resolution visual QA;
- invoke an Editor builder, save/reload a user's open scene, write prefabs/assets, or otherwise mutate
  project content during a test.

Structural hygiene belongs in a read-only project audit/CI script. Visual composition belongs in
measured screenshots or a narrow invariant test (safe-area containment, no overlap, required sprite
assigned), not hundreds of pixel-lock assertions.

## Developer Responsibilities

When tests or automation pass the Test Value Gate, Developer adds the smallest seam needed:

- Existing public APIs, deterministic seed, focused fake, test prefab/scene, scenario runner, or input
  seam. Do not add an interface/service solely to make a low-value test possible.
- EditMode tests for pure logic.
- PlayMode tests for scene/runtime behavior.
- Scenario runner or custom MCP tool for multi-step flows when PlayMode tests are awkward but runtime driving is needed.

Input injection recipe (level 6) via MCP `execute_code`: uGUI buttons whose handler implements
`IPointerClickHandler` (e.g. NeoxiderPages `BtnChangePage`) have zero `onClick` listeners, so
`button.onClick.Invoke()` does nothing — simulate the click instead:

```csharp
var ped = new UnityEngine.EventSystems.PointerEventData(UnityEngine.EventSystems.EventSystem.current);
UnityEngine.EventSystems.ExecuteEvents.Execute(buttonGo, ped, UnityEngine.EventSystems.ExecuteEvents.pointerClickHandler);
```

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

## Delegated Work: Verify Before You Believe

Two failure modes appear as soon as work is split across agents. Both were paid for in production.

**A wrong premise in the task brief propagates.** A delegated task stated that both scenes used
`StandaloneInputModule`; a grep proved the opposite (`standalone=0`, `newmodule=1`). Acting on the
brief would have disabled UI input across the whole game. Verify the factual claims in a task prompt
against the repository *before* delegating, not after the agent reports.

**Agent findings are leads, not conclusions.** In one pass, three of the reported "missing art"
defects were false: the objects carried placeholder names but held real sprites, which a guid lookup
settled in seconds. Re-check any finding that would change product behaviour, and say plainly which
of your own earlier claims a re-check overturned.

## Effects and Feel Need Visual Capture, Not Code Review

Particle and animation defects survive code review because the code is correct in isolation:

- A prewarm that silently did not apply — emitted particles reached only the top quarter of the screen.
- An authored lifetime too short for the distance travelled — the effect died mid-screen.
- Leftover state from a previous round still on screen during the next one, because the interrupt path
  stopped gracefully instead of immediately.

Capture the effect at several points in its lifetime and compare against the video reference. If a
feature has a reference recording, densities and timings are checkable numbers, not opinions.

## Economy Values Belong in Bet Multipliers

Express progressive/jackpot seeding, contributions, and thresholds as multipliers of the current bet,
never as absolute currency. Absolute values invert the intended relationship at the ends of the bet
ladder — a seed tuned at the top of the ladder consumed over 7 % of turnover at the bottom. Also
confirm what the displayed unit actually is before tuning: a config in "coins" that an adapter treats
as display dollars turns a documented ladder into a wrong one.
