# Dev settings

Project config. Agent reads this first each session.

---

## Dev mode

**Mode:** [Prototype | Standard | Fast | Pro]

---

## Agent launch mode

**Launch:** [Full skill cycle | Direct task]

---

## Options

| Option | Value | Note |
|--------|--------|------|
| Clarifying questions | [on / off] | Ask before plan/features |
| QA per feature | [on / off] | Agent + QA-agent checklist after each feature |
| Final QA checklist | [on / off] | End-of-stage QA doc |
| Verification driver required | [on / off] | Standard/Pro: every Feature/Task declares runtime driver |
| Tests required | [on / off] | Standard/Pro: write/run EditMode or PlayMode tests when feature needs them |
| Screenshot evidence | [on / off] | Capture and review screenshot evidence for visual/runtime-visible checks |
| Interactive screenshot-only pass | [blocked / allowed] | Default blocked: interactive features need tests/scenario/input driver |
| QA retry limit | 2 | After 2 failed/unavailable attempts, write degraded report and continue |
| Auto mode (save time) | [on / off] | Agent decides more; questions batched at end |
| Autotests | [on / off / —] | Pro mode |
| Active Input Handling | [Old / Both / New] | Prototype/Standard: Old or Both; Fast/Pro: New |
| Search ready solutions | [on / off] | Check Unity + packages + GitHub/web before coding |
| Lead/Dev/QA workflow | [on / off] | Standard/Pro: Lead creates feature/task/QA pages before implementation |
| Task pages | [on / off] | Standard/Pro: one Docs/Tasks page per implementation task |
| QA agent duplicate | [on / off] | Standard/Pro: duplicate feature QA checklist under Docs/QA_AGENT |
| Auto-advance after self QA | [on / off] | Continue after pass, or after degraded QA report + follow-up task; ask only on blockers/ambiguity |
| Role subskills | [on / off] | Use GD/Designer/Lead/Developer/QA role files |
| Mandatory subagents | [on / off] | Standard/Pro: use real subagents when tools are available |
| Subagent fallback | [only_when_tools_unavailable / off] | Local role switching only when subagents are unavailable or blocked |
| ComfyUI | [used / not used] | Asset generation |
| UI design ref | [yes / no] | Mockups/screens/guide for UI Builder |
| Design source | [screenshots / site / exported mockup / other] | |
| Design link | [URL or —] | |

---

## Project

| Param | Value |
|-------|--------|
| Platform(s) | [PC / Mobile / WebGL / ...] |
| Orientation | [portrait / landscape] |
| Resolution | [1920x1080 / ...] |
| Art style | [2D pixel / 2D casual / 3D low-poly / ...] |
| Input | [Keyboard+Mouse / Touch / Gamepad / ...] |

---

## Notes

[Extra decisions, agreements.]
