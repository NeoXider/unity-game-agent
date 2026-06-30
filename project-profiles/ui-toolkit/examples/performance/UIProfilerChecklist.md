# UI Toolkit profiler checklist

## What to watch

- `UpdateStyle`: classes/styles change often, or complex selectors.
- `UpdateLayout`: layout recalculates; check width/height/flex/top/left animations.
- `UpdateAnimation`: many transitions.
- `UpdateRenderData`: mesh/textures/text/materials/masks change.
- `DrawChain`: batching/render cost.
- `UpdateRuntimeBindings`: binding updates too much.

## Typical causes of spikes

| Spike | Possible cause | Fix |
|---|---|---|
| UpdateLayout | Animating `width/height/flex` | Switch to `scale/translate` |
| UpdateStyle | Frequently toggling a class on the root | Toggle lower in the tree |
| UpdateRenderData | Changing text every frame | Update only on change |
| DrawChain | Many masks/materials/filters | Simplify the subtree, combine effects |
| Memory | Callbacks/schedules not removed | `Unwire`, cancel tasks, reset pools |
