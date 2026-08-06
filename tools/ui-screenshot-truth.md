# UI Screenshot Evidence That Does Not Lie

Screenshots are the main evidence for `ScreenshotOnly` and for every UI acceptance round. A capture
harness that quietly changes rendering conditions produces evidence that is worse than none: it looks
like proof while hiding the defect. This file is the canon for capturing and for reading UI evidence.

## The failure this prevents

A capture harness forced `canvas.scaleFactor` and rendered at its own resolution. Every acceptance
screenshot looked correct for weeks. On device, the startup pages occupied **34 % of screen width
instead of 86 %** — they had been authored in a mockup-sized reference resolution, and the forced
scale factor masked it in every single screenshot.

**Rule: never force `scaleFactor`, never render at a resolution the player never sees, never
super-size.** Capture exactly what the player gets.

## Capture method

Use the **Device Simulator**, not the plain Game view — only the simulator applies a real
`Screen.safeArea`, and safe-area bugs are invisible without it.

- `UnityEditor.PlayModeWindow.SetViewType(PlayModeWindow.PlayModeViewTypes.SimulatorView)` is public
  API and switches the view.
- Selecting the device needs reflection: `SimulatorWindow` → `m_Main` → `deviceIndex`.
- `ScreenCapture.CaptureScreenshot` / `ReadPixels` read the render target, so the cosmetic device
  bezel is **not** in the image. A frameless capture is correct, not a mistake.
- Verify each written file by parsing the PNG `IHDR` for real width/height. A file that exists is not
  a file at the resolution you asked for.

### Resolutions

Shoot the primary device plus the extremes of the aspect range. For portrait mobile: a notched phone
(e.g. `1170 x 2532`, top inset 141, bottom 102), the plain portrait reference (`1080 x 1920`), and a
tablet (`1536 x 2048`) — tablets break adaptive layouts far more often than phones.

### When a profile does not exist

There may be no built-in 16:9 profile, and custom `.device` assets are **not** picked up by
`DeviceLoader.LoadDevices()` in current Unity versions — a hand-written `.device` file parses into an
empty `DeviceInfo`. Workaround: clone an existing `DeviceInfoAsset` **in memory**, override
`width` / `height` / `safeArea`, and inject it into the simulator's device list (the `devices`
property is read-only; assign the private backing field).

Two obligations follow:

1. Restore the real list afterwards (`DeviceLoader.LoadDevices()`) and reset the device index.
2. **State in the report that the synthetic profile has no insets**, so nobody believes those frames
   proved notch safety. They did not.

## Reading the evidence

Visual claims must be measured, not eyeballed. Two concrete misreadings from one session:

- "The disabled button looks just as bright as the enabled one." Pixel sampling showed channel ratios
  of `0.72 / 0.76` — exactly the configured disabled tint. The claim was false.
- "The slider handle is twice the mockup size." Measured: mockup ≈ 81 px, build ≈ 95 px — a 15 %
  difference, and the fix magnitude derived from the wrong claim would have been wrong too.

Before reporting a visual defect, produce a number: sampled pixel values, measured screen rects, or
glyph bounds. Compare against the mockup **scaled to the same width** — comparing a `390`-wide export
to a `1170`-wide capture without normalising is the most common source of bogus findings.

## Agents and screenshots

- **Never read PNGs back into an agent's context.** A capture agent that loads its own screenshots
  stalls and dies; the coordinator reads images, the capture agent writes files and reports numbers.
- A capture agent that cannot see pixels must say so, and must not claim mockup similarity it could
  not check. Instrumental measurements and visual comparison are different evidence.

## One editor, one driver

A Unity editor is a single-writer resource. Two agents driving it will switch scenes and toggle Play
Mode under each other, and every screenshot taken during the overlap is of an unknown state.

- Serialise editor work: one agent at a time, batched by page group.
- Scene mutation and `SaveScene` **fail during Play Mode** ("cannot be used during play mode"), and
  edits applied in Play Mode are discarded on exit. Read the editor state before editing.
- Require every editor agent to exit Play Mode and restore any device/profile it changed. A left-on
  Play Mode blocks the next agent and burns wall-clock time silently.
- Watch progress externally (file count in the output folder, plus a stall signal), so a dead agent is
  noticed in minutes rather than after a timeout.

## Editor side effects to audit afterwards

Builds and editor restarts mutate tracked files on their own. Check `git status` and revert what
nobody asked for:

- `ProjectSettings/UnityConnectSettings.asset` — analytics `m_Enabled` flips `0 → 1`.
- TMP fallback font asset lists getting cleared.
- `EditorSettings.asset` — `m_EnterPlayModeOptions` changing under you.
- New `.slnx` / `.vsconfig` / IDE files — add to `.gitignore` rather than committing.

## Placeholder naming

Objects named `*_Placeholder_MissingArt` that have since received real art cause a false alarm in
every acceptance round. Audit them by resolving the sprite guid, rename once the art lands, and keep
the name in a single const if a builder recreates the object.
