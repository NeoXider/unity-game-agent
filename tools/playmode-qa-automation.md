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

`ExecuteEvents` bypasses the input module. To prove that real input reaches the UI (after switching
to the Input System, for drag/scroll axes, for the Back key), drive virtual Input System devices
through the real `InputSystemUIInputModule` — recipe and the two focus traps in
[input-system.md](input-system.md) "Driving the Input System from QA".

Before any tap, prove the target is hit: `EventSystem.RaycastAll` at the control's screen centre must
return the control (or a child) first. During an entrance animation an invisible control must *not*
be hit.

Developer must run the required tests through MCP (`run_tests` + `get_test_job`) when available. If MCP is unavailable, use Unity CLI batchmode when practical. If neither works, mark verification `degraded`, not `pass`.

## Transient State Cannot Be Screenshotted Afterwards

A screenshot taken after a tween, particle burst, flash, or timed popup has finished proves nothing —
it shows the resting state, which looks identical whether the effect ran, ran wrongly, or never ran.
Do one of these instead:

- **Hold the state:** pause (`EditorApplication.isPaused`) or set `Time.timeScale = 0` at the moment
  of interest, capture, then resume; or drive the tween to a fixed normalised time.
- **Read the value:** assert the actual number in code (`tween.Elapsed()`, the eased position, the
  `fillAmount`, the emitted particle count, the colour channel) and report the number.

A capture whose timing is not controlled must be reported as "not verified", not as evidence.

## QA Re-Runs After Every Fix Batch

One QA pass at the start of a session is worthless: in a real session it was followed by dozens of
edits, none of them covered by it.

- Re-run the affected QA checks after **each significant batch of fixes**, not once per session.
- A check's result is only valid for the build state it was taken in; record which change set it
  covers.
- The final report must state explicitly **what was not re-verified after the last change and why**.
  "Everything works" without that list is a false claim.

## The QA Loop With a Tester Agent

For a game heading to the owner, run numbered rounds until nothing Critical or Major remains:

1. **Tester pass** (a QA subagent acting as a player, not a code reviewer): every screen and every
   button through real taps, every mode start to finish, replays, persistence across an app restart,
   economy consistency (balance before/after each reward, no double pay, collected items stay
   collected), the resolution matrix from
   [../project-profiles/plain-ugui.md](../project-profiles/plain-ugui.md), and targeted crops for
   anything drawn over art. Output: `Docs/QA/qaN/report.md` with Critical / Major / Minor / Cosmetic,
   each item with numbers and a screenshot or crop, a status table for the previous round's items,
   what was *not* checked, and open owner questions.
2. **Fix pass** by the orchestrator, one commit per round.
3. **Next round** re-checks the previous items first, then looks for regressions.

The owner receives the final round's report, with accepted items and owner questions listed
separately. Items the owner already decided are not re-reported.

### Editor hygiene during QA (all learned the hard way)

- **Never run QA while the owner is playing in the editor.** The tester drives the same editor and
  the same save: the owner saw coins "come back" because the tester's session loaded over theirs.
  Ask, or wait until the editor is idle.
- **Use a separate save profile** for QA (a distinct PlayerPrefs/save key) and delete it afterwards;
  never write to the owner's save.
- **Never leave a scene dirty** before tests, Play Mode, or the end of a step. Opening another scene,
  entering Play Mode, or running tests with a dirty scene raises a modal "Save changes?" dialog; the
  editor's main thread blocks, and every MCP call then times out. An MCP timeout right after a scene
  edit means that dialog — the owner has to click it. Save and check `scene.isDirty == false`.
- `ScreenCapture.CaptureScreenshot` writes one file per frame; capturing twice in one eval keeps only
  the last. Space captures across frames.
- Restore what you changed for the session: Game view resolution, input settings, time scale, test
  devices, opened scenes.

### Boot and smoke harnesses

A boot test that reports "0 errors" can be lying: startup code may mute logging, and teardown can throw
after the XML result is written. Restore the logging channel in the harness, run only the intended test
assembly, assert that at least one interaction was actually driven, and scan the full editor log for
exceptions after the run.

### UI acceptance document for a human reviewer

Mockup beside the build frame, one comment field and one approve checkbox per page, and only the owner
ticks approve. Copy the mockups into the document's own screenshots folder (relative links into the art
folder do not preview). Keep intentional deviations in their own section. When a new round supersedes an
old file, carry the reviewer's comments over verbatim with their resolution before deleting it.

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
