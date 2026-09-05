# Skill Memory

Persistent memory for universal improvements to the `unity-game-agent` skill itself.

Use this file for repeatable lessons that should improve future Unity game-agent work across projects. Do not store project-specific decisions here; put those in the project's `Docs/AGENT_MEMORY.md`.

## Active Learnings

<!--
Append entries in this format:

### YYYY-MM-DD - category
- Trigger: What the agent noticed.
- Learning: Universal rule, approach, or anti-pattern.
- Apply when: When future agents should use it.
- Evidence: Verification, project context, or repeated observation.
- Skill impact: Which skill section/tool/template this improves.

Allowed categories: workflow, verification, reuse, unity-mcp, docs, qa, architecture, tools, anti-pattern.
-->


### 2026-05-27 - tools
- Trigger: setup_project.bat failed smoke tests despite static validation
- Learning: Windows batch scripts in the skill must keep CRLF line endings, escape parentheses inside IF blocks, and be smoke-tested for idempotency on a temp Unity-like project.
- Apply when: Adding or editing .bat/.cmd scripts or project bootstrap tooling
- Evidence: setup_project.bat initially failed in cmd.exe, then passed two-run bootstrap smoke test after CRLF, escaped parentheses, delayed expansion, and idempotent iteration-log fixes.
- Skill impact: Script validation and Windows bootstrap reliability

### 2026-07-16 - anti-pattern
- Trigger: Renaming Unity sprite texture files (png + meta) that use Sprite Mode Multiple
- Learning: Sliced sprite names live inside the .png.meta (internalIDToNameTable 'second:' and sprites[].name), so renaming the file keeps stale sprite names and silently breaks name-based lookups and parsers. Rewrite both meta fields to the new base name while preserving internalID. Cyrillic sprite names are stored as quoted \uXXXX escape strings - match the whole quoted line, not the extracted value.
- Apply when: Any file-only sprite rename or convention migration in a Unity project, before relying on sprite.name at runtime or in editor tooling.
- Evidence: PokerClub 2026-07-16: 52 card sprites renamed to suit_NN; auto-fill by sprite.name would have failed because all sliced sprites kept names like '2-2_0' until metas were rewritten.
- Skill impact: Rename workflows must always audit internalIDToNameTable after moving sprite files.

### 2026-08-06 - qa
- Trigger: Every UI acceptance screenshot looked correct while the shipped layout was wrong on device.
- Learning: A capture harness must never force `canvas.scaleFactor`, render at its own resolution, or super-size. Capture through the Device Simulator so `Screen.safeArea` is real, and verify each PNG by parsing IHDR for the resolution actually written. Custom `.device` assets are not loaded by `DeviceLoader.LoadDevices()`; clone a `DeviceInfoAsset` in memory instead, restore the device list afterwards, and state that a synthetic profile has no insets so nobody counts those frames as notch proof.
- Apply when: Producing any UI evidence for acceptance, QA, or a mockup comparison.
- Evidence: TropicMania 2026-08-06: forced `scaleFactor = 2` hid that startup pages occupied 34% of screen width instead of 86% - the defect survived weeks of "verified" screenshots.
- Skill impact: tools/ui-screenshot-truth.md; Play Mode QA screenshot evidence policy.

### 2026-08-06 - qa
- Trigger: Two visual defects reported from looking at screenshots turned out to be wrong.
- Learning: Never report a visual defect without a number. Sample pixels, measure screen rects, or measure glyph bounds (`ForceMeshUpdate` + `textBounds`, not the RectTransform). Normalise the mockup to the capture width before comparing - a 390-wide export against a 1170-wide frame is the most common source of bogus findings.
- Apply when: Any "looks wrong / looks too big / looks not dimmed" claim about UI.
- Evidence: TropicMania 2026-08-06: "button is not dimmed" was false (measured channel ratios 0.72/0.76 = the configured disabled tint); "handle is 2x too large" was really 15% (81 px mockup vs 95 px build).
- Skill impact: tools/ui-screenshot-truth.md; QA reporting discipline.

### 2026-08-06 - workflow
- Trigger: A capture subagent stalled for 600 s and left the editor sitting in Play Mode unnoticed.
- Learning: The Unity editor is a single-writer resource - serialise agent work, one driver at a time, batched into small page groups. Forbid agents from reading PNGs back into context (it stalls them), require an explicit Play Mode exit and profile restore, and watch progress externally (output-file count plus a stall signal) so a dead agent is caught in minutes. Scene mutation and `SaveScene` fail during Play Mode, and edits made in Play Mode are discarded on exit - read editor state before editing.
- Apply when: Orchestrating any multi-agent Unity work, especially screenshot or scene passes.
- Evidence: TropicMania 2026-08-06: parallel-capable plan reduced to sequential batches after the first agent died silently; second and third batches completed with per-file progress events.
- Skill impact: tools/ui-screenshot-truth.md ("One editor, one driver"); orchestration guidance.

### 2026-08-06 - architecture
- Trigger: Adaptive layout regressions kept reappearing across scenes and prefabs.
- Learning: Fix one project-wide `CanvasScaler` contract - `Scale With Screen Size`, one reference resolution, `Screen Match Mode = Expand` - and guard it with a test that walks every scaler in scenes and prefabs. `Expand` is the only mode that never crops. Top UI keeps a hard inset (100 px with a top pivot/anchor, 150 px otherwise; a real notch inset is ~141 px), built from anchors and `Screen.safeArea` rather than absolute coordinates. The resulting gap versus the mockup is an accepted deviation, recorded once, not re-reported every round.
- Apply when: Any mobile uGUI project, at scene setup and at every QA round.
- Evidence: TropicMania 2026-08-06: scalers silently flipped to `Shrink` in a scene and via a prefab override; mockups placed the top HUD row at y=34, under the cutout.
- Skill impact: project-profiles/plain-ugui.md.

### 2026-08-06 - anti-pattern
- Trigger: A builder script regenerated a hand-authored scene and destroyed manual work.
- Learning: Editor builders must never own a hand-authored scene. Keep `EditorSceneManager.SaveScene` out of `Scripts/` entirely and grep for it as a guard; make targeted edits through MCP instead of regenerating. Objects named `*_Placeholder_MissingArt` that later received real art must be renamed (resolve the sprite guid to check) - otherwise they raise a false alarm in every acceptance round, and the name usually lives in a builder const that recreates it.
- Apply when: Any project where an editor builder and hand authoring touch the same scene.
- Evidence: TropicMania 2026-08-06: the startup-scene builder was deleted from the project after it overwrote `Loading.unity`; 20 objects carried stale placeholder names while holding real sprites.
- Skill impact: project-profiles/plain-ugui.md; builder/scene-ownership rules.

### 2026-08-06 - verification
- Trigger: Switching Active Input Handling to the Input System package broke the Android Back button.
- Learning: Under "Input System Package (New)" every legacy `Input` call throws at runtime, so port `Update` paths behind `#if ENABLE_INPUT_SYSTEM` / `#if ENABLE_LEGACY_INPUT_MANAGER`. Unity has acknowledged that the Input System does not surface Android `KEYCODE_BACK`, so pair `Keyboard.escapeKey` (iterate `InputSystem.devices` - `Keyboard.current` is null on handsets) with `Application.wantsToQuit` as a backend-independent channel. Guard against both channels firing in one frame by caching the handled result for that frame and replaying it - returning "not handled" to the second channel quits the app right after it navigated.
- Apply when: Changing Active Input Handling, or handling Back/Escape on Android.
- Evidence: TropicMania 2026-08-06: IL of the compiled method confirmed the legacy branch was stripped; the frame-guard inversion would have closed the app on every in-game Back press.
- Skill impact: tools/code-writing.md input handling; platform verification checklist.

### 2026-08-06 - anti-pattern
- Trigger: A delegated task brief contained a factual claim about the project that was wrong.
- Learning: Verify the factual premises of a task prompt against the repository before delegating. A brief that asserted both scenes used `StandaloneInputModule` was contradicted by grep (`standalone=0`, `newmodule=1`); executing it would have disabled UI input across the whole game. Symmetrically, treat agent findings as leads: re-check anything that would change product behaviour, and state plainly which of your own earlier claims the re-check overturned.
- Apply when: Writing any subagent prompt, and when reading any subagent report.
- Evidence: TropicMania 2026-08-06: the input-handling brief was wrong; separately, three reported "missing art" defects were false - the objects held real sprites under placeholder names, settled by a guid lookup.
- Skill impact: tools/playmode-qa-automation.md ("Delegated Work: Verify Before You Believe").

### 2026-08-06 - verification
- Trigger: Particle and animation defects passed code review and failed on screen.
- Learning: Effects need visual capture across their lifetime, not code review. Real defects found only by looking: a prewarm that silently did not apply (particles reached only the top quarter of the screen), an authored lifetime too short for the travel distance (effect died mid-screen), and leftover emitters from the previous round still visible during the next one because the interrupt path stopped gracefully instead of immediately. When a video reference exists, densities and timings become checkable numbers.
- Apply when: Any VFX, animation, or "game feel" task.
- Evidence: TropicMania 2026-08-06: money-rain VFX passed review three times; each defect surfaced only from captured frames compared against the reference video.
- Skill impact: tools/playmode-qa-automation.md ("Effects and Feel Need Visual Capture").

### 2026-08-06 - architecture
- Trigger: Jackpot seeding tuned in absolute currency inverted the intended economy at the bottom of the bet ladder.
- Learning: Express progressive seeds, contributions, and thresholds as multipliers of the current bet, never absolute currency - absolute values consumed over 7% of turnover at the low end while behaving at the high end. Before tuning, confirm what the displayed unit actually is: a config in "coins" that an adapter treats as display dollars silently turns a documented ladder into a different one.
- Apply when: Tuning any bet-scaled economy - jackpots, progressive pots, thresholds, payout tables.
- Evidence: TropicMania 2026-08-06: contribution was 7.2% at the ladder bottom; the documented $10-$1000 ladder did not match the config until the adapter's unit was checked.
- Skill impact: tools/playmode-qa-automation.md ("Economy Values Belong in Bet Multipliers"); tools/core-mechanics.md.

### 2026-08-06 - workflow
- Trigger: Removing a feature left the project compiling but the scenes dirty with orphaned data.
- Learning: Deleting a feature is not finished when the code is gone. Sweep the scene/prefab YAML for dangling serialized overrides pointing at the removed members, and remove the objects the feature owned. Keep test assemblies out of player builds with `defineConstraints: ["UNITY_INCLUDE_TESTS"]` in the test asmdef, and check third-party demo content before shipping - vendored sample scenes and textures dominated build size (20.3 MB of 28.2 MB of user textures).
- Apply when: Removing a feature, or preparing a first real build.
- Evidence: TropicMania 2026-08-06: a removed column-frame feature left 7 dangling YAML overrides; the first Android build shipped with AutoRotation enabled on a portrait-only game until player settings were audited.
- Skill impact: Feature-removal checklist; build-preparation checklist.

### 2026-08-06 - qa
- Trigger: The acceptance document needed to survive several review rounds without losing history.
- Learning: Structure a UI acceptance document as: mockup beside the build frame, one comment field and one approve checkbox per page, and a rule that only the user ticks approve. Duplicate the mockups into the document's own screenshots folder - relative links into the art folder do not render a preview in Markdown. Keep the intentional deviations in their own section so the reviewer skips them, and when superseding an older acceptance file, migrate the reviewer's verbatim comments into the new one before deleting it.
- Apply when: Any multi-round UI acceptance with a human reviewer.
- Evidence: TropicMania 2026-08-06: second acceptance round carried every first-round comment forward with its resolution, so closed items stayed auditable after the old file was deleted.
- Skill impact: templates/QA_CHECKLIST.md; acceptance-document conventions.

### 2026-08-06 - anti-pattern
- Trigger: Two icon buttons with identical boxes, offsets and scale still rendered at different sizes.
- Learning: Import every standalone sprite as Sprite Mode = Single; keep Multiple only for real sprite sheets and atlases. A single-image texture imported as Multiple gets a sub-rect trimmed to its opaque content, so two icons drawn on the same canvas arrive with different sprite rects and different internal padding - with preserveAspect the fitted size then follows the sprite aspect, not the box, and identical transforms render unequal. The cause is invisible in the Inspector's transform values, so it burns hours of layout debugging. Audit with `grep -rl "spriteMode: 2" --include=*.png.meta`.
- Apply when: Importing art, and first thing when two elements that measure equal look unequal.
- Evidence: TropicMania 2026-08-06: menu Settings/Collection icons, both in a 255x255 box at mirrored offsets, rendered 255x238.7 and 255x255 because the sliced rects were 94x88 and 92x92; 56 of 61 project sprites were Multiple.
- Skill impact: project-profiles/plain-ugui.md ("Sprite import mode: Single, always").

### 2026-08-08 - architecture
- Trigger: Unity project work in any mode, including fast and Quick Fix
- Learning: Preserve a feature-owned structure: runtime scripts under Scripts/<Feature>/<CodeArea>, editor tooling under Editor/<Feature>, tests under Scripts/Tests/<Feature>/EditMode or PlayMode, and authored assets under typed roots such as Settings, Prefabs, and Sprites. Tracked Editor Builders are forbidden; author state directly and use read-only validators.
- Apply when: Planning, implementing, reviewing, or bootstrapping any Unity level of work
- Evidence: TropicMania audit exposed 10 tracked Editor Builders while its feature-owned runtime/test/asset layout provided the desired baseline.
- Skill impact: workflow, templates, modes, project structure audit

### 2026-08-08 - qa
- Trigger: Choosing architecture and tests in pro mode
- Learning: Pro means stronger risk analysis and evidence, not Clean Architecture, DI, interface quotas, or test-count quotas. Add a test only when it protects a named behavior/contract and can realistically fail; reject tautological, private-reflection, source-text, exact-layout, no-throw, and package re-tests unless a concrete regression justifies them.
- Apply when: Selecting pro mode or planning EditMode/PlayMode coverage
- Evidence: TropicMania contains a broad suite with 38 files flagged for reflection/source-text review, showing that test volume alone is not quality.
- Skill impact: pro mode, test value gate, QA templates

### 2026-08-08 - workflow
- Trigger: A common nontrivial Unity need has no suitable project-local, Unity, or NeoxiderTools implementation
- Learning: Before writing custom code, search official documentation and samples, maintained GitHub/UPM repositories, and reputable package sources. Evaluate compatibility, maintenance, license, dependency footprint, performance, and rollback cost; classify candidates as direct reuse, adapt, reference-only, or reject. Skip internet search only for obviously tiny adapters or genuinely game-specific rules.
- Apply when: Planning or implementing any reusable Unity system after a local or NeoxiderTools miss
- Evidence: User established internet reuse discovery as the required fallback before custom implementation.
- Skill impact: reference discovery, NeoxiderTools fallback, Lead planning, Developer gate

### 2026-08-08 - architecture
- Trigger: Creating or editing project scripts in fast or standard mode
- Learning: New fast and standard project scripts stay in the global namespace. Pro follows the existing project and may use product/feature namespaces. Preserve existing namespace declarations during targeted edits; never perform a collateral namespace migration merely because the selected mode differs.
- Apply when: Selecting namespace style for Unity C# authoring
- Evidence: User explicitly defined fast and standard as namespace-free modes.
- Skill impact: mode policy, code writing, project structure

### 2026-08-24 - qa
- Trigger: A Play Mode boot test reported zero captured errors and passed while startup muted Unity logging and teardown threw after XML results were saved.
- Learning: Boot harnesses should use a reporting helper that restores their logging channel, run only the intended test assembly, assert that at least one interaction was actually driven, and post-scan the complete editor log for exceptions emitted during teardown after test completion.
- Apply when: Building automated Unity startup, smoke, or reconstructed-project Play Mode checks.
- Evidence: A deterministic static-constructor probe exposed the critical dependency; assembly filtering reduced 1777 tests to one; the complete log then revealed four post-result exceptions that XML and the in-test callback could not see.
- Skill impact: Play Mode QA automation and final verification reporting.

### 2026-09-04 - tools
- Trigger: Bulk-importing designer PNGs as 9-sliced uGUI sprites with no Unity Editor running; borders had to come from the files themselves.
- Learning: Derive a 9-slice border by measuring corner radius from the alpha silhouette thresholded at alpha>=250, not by scanning for uniform adjacent rows/columns. Modern UI art has gradients and glow, so no two adjacent lines are ever equal and the uniform-middle scan finds almost nothing; loosening its tolerance yields unstable garbage. The high alpha threshold also excludes soft drop shadows, which otherwise smear the edge profile and inflate the border to half the sprite. Force opposing borders symmetric when one exceeds ~2x the other, since asymmetric art (shadow lip, notch) skews a single edge, and zero an axis per-axis rather than globally so a pill-shaped button keeps its horizontal border.
- Apply when: Importing or fixing 9-slice borders on raster UI sprites in bulk, especially file-only with the Editor closed.
- Evidence: Arrows Flow, 2026-09-04: uniform-middle scan set a border on 1 of 30 stretchable sprites; alpha-silhouette method set correct symmetric borders on all 30, verified against sprite dimensions and design references.
- Skill impact: tools/ sprite import guidance; project-profiles/plain-ugui.md 9-slice rules

### 2026-09-04 - anti-pattern
- Trigger: Reusing a purchased plugin (DOTween Pro) by copying its folder from an older donor project into a Unity 6.3 project.
- Learning: Copy plugin DLLs but never their .dll.meta files across projects on different Unity versions. An old PluginImporter serializedVersion (1 vs the 2 Unity 6.3 requires) throws inside GetPrecompiledAssemblies and blocks ALL script compilation project-wide. The symptom is badly misleading: the MCP bridge is itself C#, so it never compiles either, and the failure presents as 'MCP is broken' or 'no Unity instances found' rather than as a stale asset meta. Diagnose by grepping Logs/Editor.log for 'below the supported minimum' rather than trusting the surface symptom; fix by deleting the .dll.meta files and letting Unity regenerate them.
- Apply when: Porting Asset Store plugins, Plugins/ folders, or any precompiled DLL between Unity projects or Unity versions.
- Evidence: Arrows Flow, 2026-09-04: six Demigiant .dll.meta files at serializedVersion 1 blocked compilation on Unity 6000.6.0f1; deleting them let Unity regenerate and Assembly-CSharp plus MCPForUnity.Editor rebuilt with zero errors.
- Skill impact: tools/libraries-setup.md plugin reuse; Error Recovery section for misleading MCP-unavailable symptoms

### 2026-09-05 - qa
- Trigger: A UI audit reported all 28 buttons wired and live, and the client then found that the sound switch and all four theme cards did nothing when tapped.
- Learning: Counting a Button's onClick listeners proves nothing about whether a player can press it. A Button raycasts against Graphics, and three separate conditions silently kill one: no Graphic on the Button's own object, every child Graphic having raycastTarget off (the usual house rule for decorative art), or the only raycast target being inactive or too small and off-centre to cover where the finger lands. Verify by driving EventSystem.RaycastAll at each button's centre with its page actually open and asserting the Button or one of its descendants is in the hit list - then click it and assert observable state changed. An audit that walks components instead of the event system will report a dead control as healthy.
- Apply when: Verifying any uGUI screen, and always before reporting UI work as complete.
- Evidence: Arrows Flow, 2026-09-05: listener-count and component-walk audits both returned "0 dead" while a live raycast at the sound switch hit only the card and the scrim. Its track Graphic was inactive, and the only other raycast target was the ON/OFF label, 150 px wide and parked 48 px off-centre. The same audit missed four theme cards with no Graphic of their own.
- Skill impact: QA role verification checklist; Play Mode UI checks; definition of done for any screen.

### 2026-09-05 - anti-pattern
- Trigger: A game needed sounds and music, the fal.ai generation bridge had no key, and the agent wrote a Python synthesiser to produce the clips from arithmetic.
- Learning: Do not hand-synthesise game audio. Procedural sine-and-noise clips sound like a test tone no matter how carefully the envelopes are shaped, and shipping them quietly lowers the bar on a deliverable the client will judge by ear. When a generation route is blocked, the order is: (1) find another generation route before concluding there is none - fal.ai, a local ComfyUI with an audio model such as ACE-Step or Stable Audio, or whatever the project already uses for images and video; (2) failing that, source ready-made free clips under a licence that permits shipping; (3) only then report the gap and ask. Hand synthesis is not a third option, it is a way of appearing finished.
- Apply when: Any task that calls for sound effects or music.
- Evidence: Arrows Flow, 2026-09-05: the agent shipped eleven synthesised clips and reported audio complete. The client's answer was that generation was available all along through a route the agent had not looked for.
- Skill impact: audio tasks; Designer and Developer asset sourcing; definition of done for audio.
