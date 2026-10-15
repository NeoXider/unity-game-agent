# Play Mode QA Automation

Read the sections needed for the task's driver, evidence and retry decision. A Play Mode launch plus
screenshot cannot pass interaction: drive the action through a test/scenario/input/UI path and observe
the result, or record actual human verification. Unexecuted required checks stay blocked.

## Verification Ladder

Select the smallest practical driver that proves the contract; these are capabilities, not a ladder
to climb for every task. Reuse existing drivers before adding a narrow missing seam.

| Level | Driver | Use for | Pass requires |
|---|---|---|---|
| 0 | `CompileConsole` | file-only/script sanity | compile/import complete and no new console errors |
| 1 | `PassivePlayMode` | lifecycle, startup, passive scene checks | Play Mode enters, console checked during/after |
| 2 | `ScreenshotOnly` | static visual/layout checks | screenshot reviewed by vision/agent; not enough for interactive mechanics |
| 3 | `EditModeTest` | pure logic | nonempty expected test selection runs and assertions prove the contract |
| 4 | `PlayModeTest` | runtime behavior | nonempty expected selection drives the changed runtime contract |
| 5 | `ScenarioRunner` | multi-step gameplay/UI flows | runner drives steps, asserts state, captures evidence |
| 6 | `InputInjection` | player controls/clicks | input/UI events are simulated and asserted |
| 7 | `BuildOrBrowserE2E` | WebGL/build/platform flows | built target or browser flow is exercised |
| 8 | `ManualOnly` | truly unautomatable checks | actual human verification recorded; otherwise blocked/degraded |

## Required Task Decisions

The canonical work brief declares only relevant checks once:

- `Verification Driver`: one or more ladder drivers.
- `Tests Required`: `EditMode`, `PlayMode`, `Both`, or `Not Needed`.
- `Screenshot Required`: `yes`, `no`, or `on-failure`.
- `Automation Gap`: `none` or the missing hook/test/driver and owner/action.

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

Developer runs relevant compile/check before source-final handoff, not a mandatory full runtime
self-QA round. Independent QA drives changed player outcomes. One assigned operator **per workspace**
serializes MCP/import/play/test/assets. Separate [isolated workspaces](parallel-editors.md) can run in
parallel. Prefer headless tests and validation builds; the specific workspace must have no interactive
Editor open, even when other workspaces have Editors running. Each process owns a separate Library
and exits after its run. Shared-source clones are test-only: never edit or save their junctioned assets.
Current scoped compile/test receipts may be cited rather than run twice. Unavailable/empty/unsupported
required selections mean blocked/degraded, not pass.

## Transient State Cannot Be Screenshotted Afterwards

A screenshot taken after a tween, particle burst, flash, or timed popup has finished proves nothing —
it shows the resting state, which looks identical whether the effect ran, ran wrongly, or never ran.
Do one of these instead:

- **Hold the state:** pause (`EditorApplication.isPaused`) or set `Time.timeScale = 0` at the moment
  of interest, capture, then resume; or drive the tween to a fixed normalised time.
- **Read the value:** assert the actual number in code (`tween.Elapsed()`, the eased position, the
  `fillAmount`, the emitted particle count, the colour channel) and report the number.

A capture whose timing is not controlled must be reported as "not verified", not as evidence.

### One-frame flashes of authoring state

A scene is saved the way it was authored: every building lit, every badge and pin on, every popup's sample
text. Code that "refreshes on open" runs after the page is already active, and a path that skips the
refresh (a first-visit card, an early return) leaves the authored state visible, sometimes only for a frame
or two, which is exactly what an owner reports as "I saw it flash". Check by reading the state
**synchronously in the same call that opens the page** (count the lit buildings, the active pins and
badges through the same eval), not by looking at a later screenshot, and paint the true state before the
page appears, not after.

## Evidence Validity And Affected Rechecks

Each result links source revision (commit plus dirty-file hashes when needed), checked scope, relevant
environment/driver and evidence. No new manifest/report framework is required; brief rows suffice.

- QA independently drives changed player outcomes; Developer's success claim is not independent proof.
- After a fix, rerun failed/affected checks and their dependencies. A changed input module invalidates
  the affected click/Back checks; an unrelated text correction need not rerun save/reward regression.
- Cite unchanged valid evidence with its original revision/scope/environment and why the current diff
  cannot invalidate it. Package/scene/data/environment changes or uncertainty require affected reruns.
- Broad suites/builds/full-game passes need architecture/protocol/package/scene/data/platform blast
  radius, release/integration context or an explicit request. Docs-only changes invoke no Unity.
- State any required checks still unverified. Existing/empty test infrastructure is not a pass.

## The QA Loop With a Tester Agent

Default: one Developer -> second independent QA -> same Developer correction -> affected QA recheck.
Use the same brief's owner sections, not duplicate QA/QA_AGENT/checklist/log trees. On failure give
one reproduction, expected/actual, revision/evidence and next owner/action. Optional Game Designer
alignment follows QA and maps the existing requirements to results; it does not rewrite the GDD.

When a release-wide pass is requested or release risk warrants it, QA covers relevant screens and
controls through real taps, complete modes, replay/persistence, reward idempotency and the applicable
[resolution matrix](../project-profiles/plain-ugui.md). Keep outstanding severity/owner questions and
evidence in the canonical record or the project's already established report. Corrections still rerun
failed/affected checks; required Critical/Major defects cannot be reported as a finished release.

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
- A game with a single save slot has no separate QA profile: **export the editor's PlayerPrefs store
  before QA that mutates the profile and import it back afterwards** (on Windows the key under
  `HKCU\Software\Unity\UnityEditor\<company>\<product>`; `reg export` / `reg delete` / `reg import`).
  QA that "lights the whole city" or completes 35 levels is otherwise left in the owner's save.
- **A project open in an editor cannot be opened by a batch-mode editor** (lock file). Drive the open
  editor through MCP, or ask the owner to close it; never kill their editor.
- Eval snippets: some evaluators reject a leading `using` line; fully qualify types and reach private
  fields with reflection. Evaluate in Play Mode and read results in the same call.

### Boot and smoke harnesses

A boot test that reports "0 errors" can be lying: startup code may mute logging, and teardown can throw
after the XML result is written. Restore the logging channel in the harness, run only the intended test
assembly, assert that at least one interaction was actually driven, and scan the full editor log for
exceptions after the run.

### Headless screenshots at any resolution

First look for an existing capture path (the editor MCP's game-view capture, Unity Recorder, the
Test Framework's screenshot helpers, a Device Simulator capture). Only when none can render the page at the
requested size without an editor window, consider a narrow temporary batch capture through the
assigned operator on an isolated/closed project; do not launch a competing Editor when the owner is
playing or after the retry budget is spent. An
`-executeMethod` can enter
Play Mode, switch the overlay canvas to `ScreenSpaceCamera` with the UI camera, render into a
`RenderTexture` of each requested size, call the controller's navigation methods by name, and write PNGs.
Learned the hard way: a headless editor renders only a few frames a second, so entrance tweens look
half-faded in the capture. Raise `Time.maximumDeltaTime`, wait long after navigating (10 s or more), and
navigate through another page first when the first capture of a page comes out dark. Keep the tool out of
the commit: it is scaffolding, delete it before pushing (the owner asked for exactly that).

### Fixing a visual defect: before, fix, after

When the owner points at a visual defect, capture the **before** state first (same sizes, same state,
all the cases they listed), fix, then capture **after** with the identical setup and show both. A fix
without a before capture cannot be told from a lucky frame, and the owner cannot see what changed. Name the
files by case and keep only the sheets (a contact sheet per size), not every frame.

### UI acceptance document for a human reviewer

Mockup beside the build frame, one comment field and one approve checkbox per page, and only the owner
ticks approve. Copy the mockups into the document's own screenshots folder (relative links into the art
folder do not preview). Keep intentional deviations in their own section. When a new round supersedes an
old file, carry the reviewer's comments over verbatim with their resolution before deleting it.

## Bounded QA Attempts

QA must not get stuck repeating the same failed verification path.

- Max QA Attempts: 2 genuine failed attempts on the same required verification path.
- Attempt 1: run the declared driver/test/screenshot path and record evidence or the exact failure.
- Attempt 2: retry only after one practical corrective action inside QA scope, such as waiting for compile/import, reloading the scene, clearing stale Play Mode state, rerunning the test job, or using the approved CLI fallback.
- After attempt 2 fails/remains unavailable, return a concise fail/blocked item to Developer/operator.
  Continue only unrelated safe checks; do not invent another harness or loop metadata audits.
- Degraded Report is the legacy name for blocked verification. In the brief record attempted path,
  failure/reproduction, expected/actual, revision/evidence, unverified scope and next owner/action.
  Link a follow-up task only when existing tracking needs it; no mandatory new defect document.
- A missing/empty/unsupported required check is blocked, never pass or done. A nonapplicable check
  may be skipped with a concrete reason; it is not a failure attempt.
- Do not ask the user only because the retry limit was reached. Ask only for missing assets/credentials, destructive decisions, or product choices that cannot be inferred.

## Screenshot Evidence

For visual/UI/camera/gameplay-visible features:

1. Capture screenshot during or after the driven scenario.
2. Store it under `Docs/Screenshots/iter-NN/`.
3. Review it for nonblank output, correct scene/camera, readable UI, expected state, and no incoherent overlap.
4. Link evidence once from the work brief; existing state/index records can link that brief.

Tests that exercise visible runtime behavior should capture or trigger screenshot evidence when tooling supports it. If the test cannot capture screenshots, pair it with MCP screenshot after the same scenario or record why screenshot evidence is unavailable.

## QA Rules

- QA must not mark interactive behavior `pass` from `ScreenshotOnly`.
- QA must run or verify the declared driver and required tests.
- QA must check console before, during, and after Play Mode.
- QA records a defect/automation gap with owner/action when the required driver is missing.
- QA may use vision to judge screenshots, but vision does not replace runtime input/test execution.
- QA returns a concise blocker after two failed/unavailable attempts; the required check stays unverified.

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

## Tuning a Progression Economy

State the target as a rate a player feels ("a hint every 18 levels", "coins from 15-20 levels buy 1-3
hints"), then derive the prices from it: `levels per hint = hint price / coins per win`. Put every number in
one config asset. A focused test can protect the intended derived rate/idempotency when it passes the
Test Value Gate; mirroring defaults alone is not a meaningful assertion. Record old and new values as a
table with the reason, and check every side income (daily reward, map pins, gift boxes, doubled rewards)
against the same price: a doubled coin gift should stay below one hint, one rewarded video should pay about
one hint. When the owner says "still too generous", change prices and the scarce rewards (hint boxes), not
only the headline income.
