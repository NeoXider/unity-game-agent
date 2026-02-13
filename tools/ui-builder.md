# UI Builder (UI Toolkit) — recommendations

UI Builder is the visual UXML/USS editor for UI Toolkit. Use this guide when project/UI mode is `UI Toolkit`.

**Unity docs (current):**
- [UI Toolkit](https://docs.unity3d.com/Manual/UIElements.html) — intro, UXML, USS, events, runtime.
- [UI Builder](https://docs.unity3d.com/Manual/UIBuilder.html) — visual UXML/USS editor.
- [Get started with UI Toolkit](https://docs.unity3d.com/Manual/UIE-simple-ui-toolkit-workflow.html) — quick start.

---

## When to use

- **When UI Toolkit stack is selected:** implement UI via UI Builder (UXML, USS, UIDocument).
- **Check:** Unity 2021.1+ — UI Builder built-in (Window → UI Toolkit → UI Builder); 2020.x / 2019.4 — package `com.unity.ui.builder`. If the window opens — use it.
- **Before starting UI:** ask the user for design reference (screenshots, mockup, style guide, exported assets/specs). If none — propose a basic UI shell and agree on screen list.

---

## Structure rules

- **One UXML per screen/panel.** Separate files: MainMenu.uxml, GameHUD.uxml, SettingsPanel.uxml, ShopScreen.uxml. Switch screens by changing UIDocument `sourceAsset`.
- **USS:** shared styles in `common.uss`. Prefer one USS per screen UXML (MainMenu.uxml → MainMenu.uss); for simple screens a single `common.uss` is ok.
- **Repeated elements** (button with text/icon, shop card, list row) — optionally extract to separate UXML+USS and use as Template or clone from code. In small projects duplicating markup in one UXML is acceptable.

---

## Recommendations

- **Images in UI:** in UI Builder use **sprites (Sprite)** for icons, buttons, backgrounds — not raw textures (Texture2D). Sprites give correct UV, slice/9-slice. Import as Texture Type: Sprite (2D and UI), **Sprite Mode: Single** (or Multiple for atlases).
- **Names:** meaningful element names (name or class) for code: `root.Q<Button>("play-button")`, `root.Q<Label>("money-label")`.
- **Data and text:** from ScriptableObject (UiData etc.) when possible — do not hardcode in UXML/USS what changes by settings or localization.
- **Runtime:** attach UXML to UIDocument; logic (clicks, subscriptions) in C# (MonoBehaviour or presenter), not in UXML.
- **Layout:** Flex by default, Absolute if needed. For responsiveness use % or flex-grow, not only fixed pixels.

---

## Performance guardrails (UI Toolkit)

- **`display: none` vs dynamic creation:**  
  Use `display: none` when a panel is opened/closed often (menu, pause, popup) to avoid frequent tree rebuilds.  
  Create dynamically when the element is rare/heavy and keeping it in memory is not worth it.
- **Pooling for repeated elements:** reuse cards, rows, list tiles (no `new` every time); clear callbacks and state before returning to pool.
- **`ListView` for long lists:** inventory/shop/logs with dozens+ items — use `ListView` (virtualization/reuse).
- **Limit visible elements:** keep the number of visible `VisualElement`s low; for large screens and long lists use pagination/virtualization/lazy load.

---

## Patterns

- **One UXML — one screen;** switch screens by changing UIDocument `sourceAsset`.
- **Classes for variants:** shared styles via classes (.button-primary, .panel-modal), reuse across screens.
- **Q() and UQueryBuilder:** get elements by name or class; cache references at init.
- **Events:** subscribe to click/focus in C#, do not put logic in UXML (except simple agreed cases).

---

## Anti-patterns (for UI Toolkit mode)

- **Do not mix stacks unintentionally** — if current scope is UI Toolkit mode, avoid partial Canvas/uGUI unless explicitly required.
- **Do not use raw Texture2D for UI images by default** — for icons, buttons, backgrounds use sprites; import textures as Sprite (2D and UI), Sprite Mode: Single (Multiple for atlases).
- **Do not put multiple screens in one UXML** — one UXML per screen/panel.
- **Do not leave complex UXML without USS** — either screen-specific USS or styles in common.uss.
- **Do not duplicate the same styles** in every USS — move to shared USS.
- **Do not hardcode long texts** in UXML — use SO or localization.
- **Do not find elements by index** in hierarchy — use names/classes and query by them.

---

## Unity versions

| Version  | UI Builder |
|----------|------------|
| 2021.1+  | Built-in (Window → UI Toolkit → UI Builder) |
| 2020.x   | Package in Package Manager |
| 2019.4   | Preview package `com.unity.ui.builder` |

If the version does not support UI Builder — note the reason in DEV_STATE/AGENT_MEMORY.

---

## Links to other tools

- **Design source:** mockups can come from any source (including Figma export), but implementation is always via UI Builder (UXML/USS).
- **MCP:** create/edit UXML and USS via files (IDE); scene, UIDocument — via Unity MCP if needed.
- **ScriptableObject:** texts, colors, sizes from SO (UiData etc.), see [code-writing.md](code-writing.md).
- **UI quality mode:** document depth in `Docs/UI_BRIEF.md` (`quick` / `standard` / `production`).
