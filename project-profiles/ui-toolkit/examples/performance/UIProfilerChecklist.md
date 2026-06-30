# UI Toolkit profiler checklist

## Что смотреть

- `UpdateStyle`: часто меняются classes/styles или сложные selectors.
- `UpdateLayout`: layout пересчитывается; проверь width/height/flex/top/left animations.
- `UpdateAnimation`: много transitions.
- `UpdateRenderData`: mesh/textures/text/materials/masks меняются.
- `DrawChain`: batching/render cost.
- `UpdateRuntimeBindings`: binding обновляет слишком много.

## Типовые причины spikes

| Spike | Возможная причина | Исправление |
|---|---|---|
| UpdateLayout | Анимируешь `width/height/flex` | Перейти на `scale/translate` |
| UpdateStyle | Часто toggles class на root | Тогглить ниже по tree |
| UpdateRenderData | Меняешь text каждый frame | Обновлять только при изменении |
| DrawChain | Много masks/materials/filters | Упростить subtree, объединить эффекты |
| Memory | Не сняты callbacks/schedules | `Unwire`, cancel tasks, reset pools |
