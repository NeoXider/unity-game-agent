# UI Brief

Short brief for UI Builder (UXML/USS).

---

## Source

| Field | Value |
|-------|--------|
| Design ref | [yes / no] |
| Source | [screenshots / site / Figma-export / spec / other] |
| Link | [URL or —] |
| UI Quality Mode | [quick / standard / production] |

> Prototype → quick; Standard/Fast → standard; Pro → production.

---

## Screens

| Screen | Goal | Key elements |
|--------|------|--------------|
| MainMenu | Start, nav | PlayButton, SettingsButton |
| GameplayHUD | Game info | ScoreLabel, HpBar, PauseButton |
| Pause | Pause | ResumeButton, ExitButton |

---

## Visual style

- Colors: [primary, secondary, accent, bg, text]
- Typography: [font, sizes]
- Spacing / grid: [rules]
- Radius / borders / shadows: [rules]

---

## Component states

| Component | Normal | Hover | Pressed | Disabled |
|-----------|--------|-------|---------|----------|
| PrimaryButton | [...] | [...] | [...] | [...] |

---

## Interactions

| Screen | Action | Result |
|--------|--------|--------|
| MainMenu | Play | → Gameplay |
| GameplayHUD | Pause | Open Pause |

---

## Assets

| Asset | Type | Source | Path |
|-------|------|--------|------|
| IconCoins | PNG | Figma | Assets/_source/UI/Icons/IconCoins.png |
| ButtonBg | Sprite | Generated | Assets/_source/UI/Sprites/ButtonBg.png |

---

## Fallback (no refs)

- Base UI: MainMenu + GameplayHUD + Pause/GameOver.
- Light text on dark background; default font.
- Document assumptions here before implementation.
