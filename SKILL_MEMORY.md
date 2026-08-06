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
