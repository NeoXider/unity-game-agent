# Meta progress map: a path of stops drawn over painted art

For "city / world map" meta progression: a painted page per district, a dotted path of progress
stops along its road, buildings that light up at thresholds, coin pins to collect. The hard part is
not code — it is putting 30 markers **on the road, off the decorations, and out from under the HUD**.
Automated placement from colour masks failed repeatedly; this procedure worked.

## Product rules to confirm with the owner

- Is the map a **progress display** or a **level launcher**? (Commonly: display only; levels start
  from the main Story button. Then stops are not buttons and have no press animation.)
- What animates? (Commonly: only newly reached stops — a hop plus the building's lit layer fading in
  when the map opens; everything already reached is static.)
- Unlock level for the map, what a pin grants, and whether pins stay collected (they must).
- Keep a debug toggle in a settings ScriptableObject (tap a stop to toggle its building) and ship it
  **off**.

## Placing the path

Work in painting pixels (e.g. 1290×2796, y down) with a small script next to the project
(`Docs/.../tools/`), output JSON, then apply to the scene.

1. **Trace the road centre by hand** on a 100 px grid overlay — 30–45 points per page from the bottom
   of the painting to the top — and smooth with Catmull-Rom (passes through every point). Do not
   derive the route from colour masks: lit walls, plazas, and water reflections share the road's
   colours.
2. **Obstacles:** HUD rects (header, coin pill, side arrows + their coins, with extra margin for
   16:9) and coin-pin rects. A stop must not intersect any of them.
3. **Place stops by dynamic programming** along the arc length: N stops, minimum gap between
   consecutive stops (≥ stop diameter + margin), maximise free space, reject positions hitting
   obstacles. Pin the order so stop k is always further along than k-1.
4. **Manual overrides per stop** (`STOP_AT[district][k] = (x, y)`) snapped to the nearest route point,
   for plazas, and for spots where the automatic choice sits on a lamp, planter, or table. When the
   decoration leaves no clean spot, nudge the route itself through the open cobbles and move the
   neighbouring stop to keep the gap.
5. **Hidden stretches:** where the road passes under a tree crown or through an arch, pause the dotted
   line (`HIDDEN = [(p0, p1)]`) instead of drawing dots over the art.
6. Dots between stops: fixed spacing (~30–45 px), none inside a stop's radius, no gap larger than
   ~2 spacings.

## Verifying placement

- Render **crops** of every stop and segment with the painting underneath, the route, the stop rings
  at their real rendered radius, and a coordinate grid; review each crop. Automatic "on road"
  checks from colour are as unreliable as mask routing.
- Classify each stop in the QA report: on road / on the edge / off road / touches decoration.
  Iterate until off-road is zero; edge cases go to the owner with crops.
- Check in-game at the resolution matrix (see
  [../project-profiles/plain-ugui.md](../project-profiles/plain-ugui.md)): stops under HUD at 16:9,
  arrows over pins on tablets.

## Applying to the scene

Apply the JSON through one editor eval: set each stop's `anchorMin = anchorMax` to the painting
fraction, rebuild segment dots from one template child, then **save the scene and confirm it is not
dirty** — an unsaved scene makes the next MCP call hang behind a modal save dialog.
