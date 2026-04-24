---
name: unity-game-agent
description: "Unity Game Agent — autonomous game development pipeline: INTAKE → PLAN → BUILD → VERIFY → SHIP. Uses CoplayDev/unity-mcp for full Unity Editor control. Sub-agent architecture: orchestrator + coding agents + QA agent."
---

# Unity Game Agent — Power Pipeline

**Goal:** Autonomously build a complete, tested Unity game — from idea to playable build.
Primary mode: agent builds the game end-to-end. Secondary: collaborative development with user.

### Hardcoded Defaults (DO NOT ask user about these — just use them)

| Question | Default | Override |
|----------|---------|----------|
| **Quick Fix or full pipeline?** | Small request (1-3 files, single fix/addition) = **Quick Fix [D]**. Large request (new system, multiple mechanics) = **full pipeline**. | User says "полный цикл" / "full pipeline" |
| **MCP available?** | **Assume yes.** Try `mcpforunity://editor/state` first. If fails → switch to `file_only` but **tell user**: "MCP не обнаружен — работаю через файлы. Если хочешь полную автоматизацию (сцены, Play Mode, скриншоты) — включи MCP: Window → MCP for Unity → Start Server." | User says "без MCP" / "file only" |
| **Which mode?** | If user doesn't specify: **fast** for prototypes/simple games, **standard** for "сделай игру" / "make a game". Ask only when ambiguous (e.g. "scalable RPG" → ask fast vs pro). | User specifies mode explicitly |
| **UI mode?** | Detect from project: has UXML → `ui_toolkit`, has Canvas → `ugui`, nothing → `ui_toolkit`. | User says "ugui" / "no_ui" |
| **Platform?** | **PC** (unless mobile/webgl clues in request). | User specifies platform |
| **Auto mode?** | **Yes** — work autonomously, batch questions at end. | User says "спрашивай" / "ask me" |

**Rule: When in doubt, DO something — don't ask.** Pick the simpler option and proceed. User will correct if wrong.

---

## CRITICAL: MCP Standard

**Package:** `com.coplaydev.unity-mcp` (CoplayDev/unity-mcp v9.6+)
**Install:** `https://github.com/CoplayDev/unity-mcp.git?path=/MCPForUnity`
**Full command catalog:** [mcp-commands.md](mcp-commands.md) (42+ tools)

**MCP Detection (first thing every session):**
1. Check if MCP tools are available (try reading `mcpforunity://editor/state`)
   - If MCP tools found → `mcp_mode = use` → proceed with steps 2-4
   - If MCP tools NOT found → `mcp_mode = file_only` → see fallback below
2. Read `mcpforunity://custom-tools` → confirm available tools
3. Read `mcpforunity://instances` → select instance if multiple
4. Read `mcpforunity://project/info` → project name, version, packages

**After any scene change via MCP → ALWAYS `manage_scene action=save`.**

### file_only Fallback (when MCP is unavailable)

**`REQUIRED` Agent MUST tell user immediately:**
```
⚠️ MCP not detected. Working in file-only mode.
I can: write scripts, create SO, manage Docs/.
I cannot: create scene objects, run Play Mode, take screenshots, read console.

To enable full automation:
1. Install com.coplaydev.unity-mcp (Package Manager → Add from git URL)
2. Window → MCP for Unity → Start Server
3. Restart this chat or say "retry MCP"
```

**What changes in file_only mode:**

| Operation | mcp_mode=use | mcp_mode=file_only |
|---|---|---|
| Write/edit scripts | File tools | File tools (same) |
| Create scene objects | MCP `manage_gameobject` | **SKIP** — tell user to create manually |
| Add components | MCP `manage_components` | **SKIP** — document in DEV_STATE what to add |
| Compile check | MCP `validate_script` | **SKIP** — tell user to check in Unity |
| Read console | MCP `read_console` | **SKIP** — ask user for errors |
| Play Mode test | MCP `manage_scene action=play` | **SKIP** — ask user to test |
| Screenshot | MCP `manage_scene action=screenshot` | **SKIP** — ask user for screenshot |
| Scene save | MCP `manage_scene action=save` | **SKIP** — remind user to save |
| Install packages | MCP `manage_packages` | **SKIP** — tell user package + install URL |

---

## Sub-Agent Architecture (RECOMMENDED)

The agent **should delegate tasks to sub-agents** when the platform supports it:

### Orchestrator (Main Agent)
- Owns the pipeline and state (`DEV_STATE`, `DEV_PLAN`)
- Assigns tasks to sub-agents
- **VERIFIES every sub-agent output** before accepting
- Makes architectural decisions
- Never trusts sub-agent output blindly — always checks: compile, console, screenshot

### Coding Sub-Agent
- Receives: task description, file paths, SO specs, architecture rules
- Returns: created/modified files, compile status
- Orchestrator verifies: `refresh_unity` → `validate_script` → `read_console`

### QA Sub-Agent
- Receives: feature name, expected behavior, test scenario
- Runs: Play Mode → `read_console` → screenshot → tries to interact
- Returns: pass/fail, screenshot, console output, found issues
- Orchestrator reviews screenshot and report before marking feature done

### Report Sub-Agent
- Receives: completed task info
- Updates: `Docs/DEV_STATE.md`, `Docs/DEV_LOG/iteration-*.md`
- Takes and reviews screenshots
- Orchestrator verifies docs are updated

**If sub-agents are not available:** orchestrator does all roles sequentially, but MUST still follow the verify-after-each-step pattern.

### When to Use Sub-Agents (thresholds)

| Condition | Use sub-agents? |
|---|---|
| Task touches 1-2 files | No — do it yourself |
| Task touches 3+ files across 2+ systems | Yes — delegate coding |
| Feature needs Play Mode QA + screenshot | Yes — delegate QA |
| Docs need update after feature complete | Yes — delegate report |
| Quick Fix (path [D]) | **Never** — always do yourself |

### Orchestrator Verification Checklist (after every sub-agent task)
- [ ] Code compiles (`validate_script` or `refresh_unity` + `read_console`)
- [ ] No new errors in console
- [ ] Feature works in Play Mode (tested)
- [ ] Screenshot taken and reviewed (not blank, shows expected)
- [ ] Docs updated (DEV_STATE, DEV_LOG)

---

## Session Entry — Decision Tree (FIRST THING every session)

**STEP 0: Quick Fix check (BEFORE anything else).**
Read the user's first message. If it's a quick fix → go straight to `[D]`. No mode, no structure check.

```
START
  │
  ├─ 0. Is user request a QUICK FIX?
  │     (triggers: "fix", "почини", "поправь", "исправь", "ошибка",
  │      "error", "bug", "NullReference", specific file + specific change,
  │      "добавь звук к ...", "измени значение / настройку")
  │     │
  │     ├─ YES → go to [D] Quick Fix  (skip everything below)
  │     │
  │     └─ NO → continue ↓
  │
  ├─ 1. Does Docs/DEV_STATE.md exist?
  │     │
  │     ├─ YES → go to [A] Resume
  │     │
  │     └─ NO → Does Assets/ exist?
  │           │
  │           ├─ YES → go to [B] New Agent on Existing Project
  │           │
  │           └─ NO → go to [C] New Project
  │
  ├─ 2. Classify user message:
  │     │
  │     ├─ Game idea / feature → Pipeline Phase 1: INTAKE
  │     │
  │     └─ "Continue" / "продолжай" → [A] Resume
  │
```

### [A] Resume — Project in Progress

```
1. Read Docs/DEV_PROFILE.json → mode, settings (DO NOT re-ask)
2. Read Docs/DEV_CONFIG.md → verify mode, toggles
3. Read Docs/DEV_STATE.md → last context, current task, blockers
4. Read Docs/AGENT_MEMORY.md → decisions, gotchas
5. Read Docs/DEV_PLAN.md → find next unchecked feature
6. MCP Detection (see MCP Standard section)
7. read_console → check for pre-existing errors
8. Create new iteration: Docs/DEV_LOG/iteration-{N+1}-YYYYMMDD-HHMM.md
9. Report to user:
   "📍 Resuming: [last context from DEV_STATE]
    Next feature: [name from DEV_PLAN]
    Proceeding with BUILD."
10. Continue BUILD from next unchecked feature
```

### [B] New Agent on Existing Project

User has a Unity project but no Docs/ structure. **Don't assume they want the full pipeline.**

```
1. Ask user:
   "I see a Unity project but no agent docs (Docs/ folder).
    What do you need?
    
    a) 🎮 Full game development — I'll setup the pipeline and start building
    b) 🔧 Add a feature/mechanic — I'll do it directly, quick setup
    c) 🐛 Fix a bug / quick edit — I'll fix it now, no pipeline needed
    
    Which one?"

2. If (a) → Create Docs/ structure (bootstrap) → go to INTAKE
3. If (b) → Create minimal Docs/DEV_STATE.md + Docs/AGENT_MEMORY.md
           → go to "direct task" mode (skip INTAKE, minimal PLAN)
4. If (c) → go to [D] Quick Fix
```

### [C] New Project

```
1. This is a new or empty project
2. Ask: "Starting a new Unity game project. What's the game idea?"
3. → Go to Pipeline Phase 1: INTAKE (full cycle)
4. Bootstrap Docs/ after INTAKE (before PLAN)
```

### [D] Quick Fix — No Pipeline

For quick fixes, bug fixes, specific edits. **This path has NO mode selection, NO Docs, NO pipeline.**

```
1. DO NOT create Docs/ structure
2. DO NOT ask about mode/platform/ui
3. Read the user's request
4. Fix the issue directly:
   - Read relevant code
   - Make the fix
   - validate_script or refresh_unity
   - read_console → verify clean
   - If MCP available: manage_scene action=save
5. Quick Fix DoD (all REQUIRED):
   ✅ Code compiles clean
   ✅ No new console errors (read_console)
   ✅ Changed files listed in report
   ✅ Brief report to user
6. Done. No state files needed.
```

**Report format for Quick Fix:**
```
✅ Fixed: [what was fixed]
Changed files: [list]
Verified: compiles clean, no new console errors.
```

---

## Minimum Viable Path (by task type)

| Task type | Minimum steps | Docs |
|-----------|---------------|------|
| **Quick Fix [D]** | Fix → compile → read_console → report | None |
| **Direct task** | Implement → compile → Play Mode → screenshot → report | DEV_STATE only |
| **fast mode game** | INTAKE(1msg) → brief PLAN → BUILD(batch) → VERIFY → report | DEV_STATE + brief LOG |
| **standard game** | INTAKE → PLAN → BUILD(per feature) → VERIFY → SHIP | Full docs |
| **pro game** | INTAKE → PLAN → BUILD(per task) → VERIFY+tests → SHIP | Full docs + ARCHITECTURE |

Use POLICY_MATRIX.md for detailed cadences per mode.

---

## Pipeline: 5 Phases

```
INTAKE → PLAN → BUILD → VERIFY → SHIP
```


### Phase 1: INTAKE (fast — 1 message exchange max)

> This phase runs ONLY for full game/feature requests. Quick Fixes skip directly to `[D]`.

**Agent asks ONE structured block:**

```
I need to know:
1. Game idea (genre, core mechanic, brief description)
2. Mode: fast / standard / pro
3. Platform: PC / Mobile / WebGL
4. UI mode: ui_toolkit (default) / ugui / no_ui

Optional (I'll decide if you skip):
- Art style, resolution, orientation
- MCP available? (default: yes)
- Auto mode? (default: yes — I work autonomously, report results)
```

**Rules:**
- `REQUIRED` If user says "direct task" → skip to BUILD, ask only what's needed
- `REQUIRED` If user gives enough info → do NOT ask more questions, start PLAN
- `DEFAULT` Auto mode ON — agent works autonomously, batches questions at end
- `DEFAULT` fast + auto_mode → agent creates plan and starts BUILD without user approval
- `DEFAULT` standard / pro → agent waits for user approval before BUILD
- `REQUIRED` Record in `Docs/DEV_CONFIG.md`

### Phase 2: PLAN (Cursor Plan Mode)

1. **Detect project structure** — scan `Assets/`, `Packages/manifest.json`
   - If existing structure found (e.g. `Assets/Neoxider/`) → use it, do NOT impose `_source/`
   - If empty project → create `Assets/_source/` structure
2. **Library discovery** — check installed packages, search for ready solutions
3. **Create `Docs/GAME_DESIGN.md`** — outline: mechanics, screens, SO data
4. **Create `Docs/DEV_PLAN.md`** — task list with stages
5. **Reuse Decision Matrix** — what exists vs what to build
6. **Get user approval** → proceed to BUILD
7. **Install libraries** — UniTask, DOTween, Newtonsoft.Json as needed

**Pre-Flight Checklist (REQUIRED before BUILD):**
- [ ] Plan approved by user (fast + auto_mode: auto-approved)
- [ ] MCP state checked (`mcpforunity://editor/state` → `ready_for_tools=true`)
- [ ] `read_console` baseline → note pre-existing errors (if any)
- [ ] Docs baseline created (see [reference.md](reference.md))
- [ ] Scene saved (`manage_scene action=save`) — starting clean

### Phase 3: BUILD (main loop)

**Feature decomposition (ALL modes, mandatory):**
Every plan MUST be split into **features** (logical blocks). Each feature = independent deliverable.

| Mode | Feature granularity | Example |
|------|-------------------|---------|
| fast | 2-4 big features | "Player movement", "Level + enemies", "UI + GameOver" |
| standard | 4-8 features | "Player movement", "Shooting", "Enemy waves", "HUD", "Menu", "GameOver" |
| pro | 8+ features with sub-tasks | "Combat system → TurnSystem, Abilities, Effects, Battle UI" |

Architecture differs by mode, but **the decomposition into features is the same pattern everywhere.**

```
FOR EACH feature in DEV_PLAN:
  1. IMPLEMENT
     - Write scripts (files, SO definitions) → create via file tools
     - Create folders via file system (mkdir), NOT MCP
     - Create scene objects via MCP (manage_gameobject, manage_components)
     - Configure via MCP (manage_components action=configure)
     - If mcp_mode=file_only → skip MCP scene ops, user sets up scene manually

  2. COMPILE CHECK (REQUIRED — every feature, every mode, no exceptions)
     - validate_script → quick compile check (use after writing/editing code)
     - refresh_unity → full AssetDatabase refresh (use after creating/moving/deleting assets)
     - read_console → compare with baseline (see Console Baseline below)
     - If NEW errors → fix immediately, re-check

  3. SCENE SAVE (if scene was changed)
     - manage_scene action=save

  4. PLAY MODE TEST (frequency per POLICY_MATRIX.md)
     - fast: after BATCH of 2-4 features
     - standard: after EACH feature
     - pro: after each TASK + after each feature

     Steps:
     - manage_scene action=play
     - read_console during play
     - manage_scene action=screenshot screenshot_file_name="Docs/Screenshots/iter-NN/feature_name"
     - manage_scene action=stop
     - read_console after play
     - REVIEW screenshot (not blank? shows expected?)

  5. UPDATE DOCS (scaled by mode)
     - fast: DEV_STATE only (brief, after batch)
     - standard: DEV_STATE + DEV_LOG (after each feature)
     - pro: DEV_STATE + DEV_LOG + ARCHITECTURE (after each task)

  6. NEXT FEATURE
     Gate (must pass before next feature):
     - Compile clean (REQUIRED all modes)
     - No new console errors (REQUIRED all modes)
     - Play Mode tested (REQUIRED — at batch/feature/task frequency per mode)
     - Screenshot reviewed (DEFAULT — skip only if no visual change)
     - Docs updated (at mode-specific frequency)
```

### Console Baseline Comparison

**How to detect "new" errors:**
```
1. At session start / pre-flight: read_console → save as BASELINE
2. After each compile/play: read_console → save as CURRENT
3. Compare:
   - NEW errors (not in BASELINE) → MUST fix before proceeding
   - NEW warnings (not in BASELINE) → fix if related to current feature, else note in DEV_STATE
   - Pre-existing errors (in BASELINE) → ignore (not your fault)
   - Pre-existing warnings → ignore
4. Update BASELINE after fixing errors
```

**Classification:**
| Console level | New? | Action |
|---|---|---|
| Error | New | **BLOCK** — fix immediately |
| Error | Pre-existing | Note in DEV_STATE, continue |
| Warning | New + related | Fix if easy, else note |
| Warning | New + unrelated | Note, continue |
| Warning | Pre-existing | Ignore |
| Log/Info | Any | Ignore |

### Phase 4: VERIFY (after all features done)

1. Full Play Mode walkthrough — test complete game flow
2. `read_console` — must be completely clean
3. Final screenshot series (all key screens)
4. Review all screenshots
5. Fix any remaining issues
6. Run tests if Pro mode (`run_tests`)

### Phase 5: SHIP

1. Final `manage_scene action=save` (all scenes)
2. Update `Docs/DEV_STATE.md` — mark project done
3. Update `Docs/DEV_LOG/` — final iteration summary
4. Final report to user (**standard format**):

```
## 🚀 Delivery Report

### What was built
- [Feature 1]: [brief description]
- [Feature 2]: ...

### How it was verified
- Compile: ✅ clean
- Console: ✅ no errors
- Play Mode: ✅ tested [N] scenarios
- Tests: ✅ passed / ⬜ not applicable

### Screenshots
- [link to Docs/Screenshots/iter-NN/...]

### Known limitations / risks
- [if any]

### Manual checks recommended
- [what user should test in Unity Editor]
```

---

## Modes (3)

Mode is chosen during INTAKE (not during Quick Fix — Quick Fix has no mode). After choice, read `modes/<mode>.md` for details.

| Aspect | fast | standard | pro |
|--------|------|----------|-----|
| **Goal** | Playable fast | Complete small game | Scalable project |
| **Scope** | 1-4 mechanics, 1-3 scenes | 3-6 mechanics, 2-5 scenes | 6+ mechanics, 5+ scenes |
| **Code style** | Components + SO, singletons OK | Separate scripts, events, SO | Interfaces, namespaces, DI, tests |
| **Play Mode checks** | Batch (after 2-4 features) | Per feature | Per task + per feature |
| **Docs** | Brief DEV_STATE | Full DEV_STATE + PLAN + LOG | Everything + ARCHITECTURE |
| **Questions** | 1-3 before plan, then none | Before plan + before feature if unclear | Detailed + before features |
| **MCP batch** | Yes (batch_execute) | Per feature | Full per task |
| **Namespaces** | No | No | Yes (Game.Combat, etc.) |
| **Tests** | No | No | Yes (auto) |

Details: [modes/fast.md](modes/fast.md) · [modes/standard.md](modes/standard.md) · [modes/pro.md](modes/pro.md)

---

## UI Strategy

### Priority Order
1. **UI Toolkit** (default) — UXML/USS, UIDocument
2. **uGUI (Canvas)** — when project already uses it or user requests
3. **NoUI** — mechanics only, no visual UI

### UI Toolkit Rules
- One UXML per screen (MainMenu.uxml, GameHUD.uxml, etc.)
- Shared styles in `common.uss`, screen-specific in `<Screen>.uss`
- Switch screens by changing UIDocument `sourceAsset`
- Use `display: none/flex` for panel toggling (not create/destroy)
- Cache `Q<T>(name)` references once at init
- Meaningful element names for code queries
- Data from ScriptableObject, not hardcoded in UXML
- Performance: ListView for long lists, pooling for repeated elements

### uGUI (Canvas) Rules
- **NEVER use legacy `Text` — ALWAYS `TextMeshPro` (`TextMeshProUGUI`)**
- `using TMPro;` for all text references
- `TMP_Text` for generic text references
- Scene must have `EventSystem` + `StandaloneInputModule` (or `InputSystemUIInputModule`)
- Buttons: `Image` + `Button` component. Child text `raycastTarget = false`
- `GraphicRaycaster` on Canvas
- **Null-safe pattern (mandatory for uGUI):** ALL `[SerializeField]` UI references must be null-checked before access:
  ```csharp
  public class GameHUD : MonoBehaviour
  {
      [SerializeField] private TMP_Text _scoreText;
      [SerializeField] private TMP_Text _healthText;
      [SerializeField] private Button _pauseButton;

      public void UpdateScore(int score)
      {
          if (_scoreText != null) _scoreText.text = $"Score: {score}";
      }

      public void UpdateHealth(int hp)
      {
          if (_healthText != null) _healthText.text = $"HP: {hp}";
      }

      public void SetPauseInteractable(bool value)
      {
          if (_pauseButton != null) _pauseButton.interactable = value;
      }
  }
  ```
- This prevents NullReferenceException when references are not yet assigned, during tests, or in headless mode

### NoUI Mode
When `ui_mode = no_ui`:
- **Do NOT create any UI screens or layouts**
- **DO create view stubs** — MonoBehaviours with same null-safe pattern as uGUI (see above)
- All public methods check for null before accessing UI elements
- This ensures: code compiles, game runs, nothing breaks, UI can be added later
- Skip UI intake questions, skip UI layout work

### UI Decision Table

| Situation | Agent action |
|---|---|
| Project has UIDocument/UXML | Use UI Toolkit, extend existing |
| Project has Canvas/uGUI | Use uGUI + TMP_Pro, extend existing |
| New project, no preference | Use UI Toolkit (default) |
| User says `no_ui` | Create null-safe stubs only |
| User provides mockup/screenshots | Implement from reference |
| No design reference | Propose basic shell, confirm with user |

### UI Migration (uGUI ↔ UI Toolkit)

When project has one system and user wants the other:

```
1. DO NOT mix systems in the same screen
2. Migrate screen-by-screen (not all at once)
3. Migration order:
   a) Create new screen in target system
   b) Wire same data sources (SO, events)
   c) Test new screen works
   d) Delete old screen
   e) Update references
4. Keep null-safe pattern throughout migration
5. Note in AGENT_MEMORY which screens migrated
```

**When NOT to migrate:**
- Project has 5+ Canvas screens and user just wants "add one more" → stay on uGUI
- Project uses custom uGUI components (ScrollRect, LayoutGroup chains) → stay on uGUI
- Only migrate if user explicitly asks or project is early (1-2 screens)

---

## Performance Profiling Policy

### When to Profile

| Trigger | Action |
|---|---|
| fast mode | **Never** — unless Play Mode visibly lags |
| standard mode | **VERIFY phase only** — quick FPS check |
| pro mode | **After each major system** — profiler snapshot |
| User reports lag | **Immediately** — profiler + frame debugger |
| Mobile/WebGL target | **At VERIFY** — memory + FPS mandatory |

### How to Profile (via MCP)

```
1. manage_profiler action=start areas="CPU,Memory"
2. manage_scene action=play
3. [wait 5-10 seconds of gameplay]
4. manage_profiler action=get_frame_timing
5. manage_profiler action=get_memory_stats
6. manage_scene action=stop
7. manage_profiler action=stop
```

### Performance Thresholds

| Platform | Target FPS | Max frame time | GC per frame |
|----------|-----------|----------------|-------------|
| PC | 60+ | < 16ms | < 1KB |
| Mobile | 30+ | < 33ms | < 512B |
| WebGL | 30+ | < 33ms | < 256B |

**If below target:** note in DEV_STATE as blocker, optimize before SHIP.

---

## ScriptableObject (all modes, mandatory)

**ALL settings and data in ScriptableObject.** No hardcoding in MonoBehaviour.

```csharp
[CreateAssetMenu(fileName = "NewEnemyData", menuName = "GameData/EnemyData")]
public sealed class EnemyData : ScriptableObject
{
    [Header("Stats")]
    public int health = 50;
    public float speed = 3f;
    public float damage = 10f;

    [Header("Visual")]
    public Sprite sprite;
    public Color tintColor = Color.white;
}
```

Create SO assets via MCP: `manage_scriptable_object`.

---

## Code Rules (all modes)

> **Single source of truth:** Core rules are HERE. `tools/code-writing.md` has only EXAMPLES and reference tables (no rule duplication). `modes/*.md` reference cadences only, no code-style duplication.

### Naming
- **Role-based names** — `GameManager`, `PlayerMovement`, `RewardPanel` (NOT `TotalWarManager`, `MyGameHero`)
- Classes: `PascalCase`. Private fields: `_camelCase`. Constants: `UPPER_SNAKE` or `PascalCase`
- SO assets: `PascalCase` with suffix — `EnemyData_Goblin`

### Basics
- One script = one responsibility (`PlayerMovement` ≠ `PlayerHealth`)
- `[SerializeField]` instead of `public` for Inspector fields
- No `Find`/`FindObjectOfType` in `Update` — cache in `Awake`/`Start`
- Null-check references
- **Async:** use UniTask when available (zero alloc, WebGL safe). Coroutines for simple delays only.
- **No obvious comments.** No `// increment counter`, `// get component`, `// call method`. Code must be self-documenting.
  - ✅ Allowed: **XML docs** (`/// <summary>`), `// TODO:`, `// HACK:`, `// WORKAROUND:`
  - ❌ Banned: `// calculate damage`, `// check if dead`, `// set position`
- **Logging (all modes):** `Debug.Log($"[Feature.Class.Method] description")` — use to explain logic at runtime
- **Logging volume:** fast = key events only, standard = plenty, pro = plenty + params

### Code by mode

| Rule | fast | standard | pro |
|------|------|----------|-----|
| Namespaces | No | No | Yes |
| XML docs | No | Public methods | All public |
| `//` comments | **No** | **No** | **No** |
| Debug.Log | Key events | Plenty | Plenty + params |
| Singleton | Yes | OK | DI/ServiceLocator |
| Interfaces | No | No | Yes |
| Tests | No | No | Yes (auto) |
| Events | Optional | Yes | Yes |

### Reuse-First (default, all modes)
Before implementing ANY feature:
1. Check Unity built-in
2. Check installed packages
3. Search GitHub/web for ready solutions
4. Only then code from scratch

Toggle: `DEV_CONFIG.md` → "Search ready solutions".

---

## Architecture by Mode

### fast
- MonoBehaviour-first, minimal abstraction
- Direct `[SerializeField]` references
- Singleton for managers (`GameManager.Instance`)
- No ServiceLocator/DI

### standard
- Separate components per responsibility
- Events / UnityEvents for cross-system communication
- Feature nodes in hierarchy (`Feature_Player`, `Feature_Enemies`)
- No DI unless clearly needed

### pro
- Logic in services/classes, MonoBehaviour as view/entry
- Interfaces for key systems (`IDamageable`, `IInteractable`)
- DI (VContainer/Zenject) when justified
- Document DI decisions in `Docs/ARCHITECTURE.md`

### Scene Hierarchy Template
```
SceneRoot
├── --- Managers ---
│   ├── GameManager
│   └── AudioManager
├── --- Environment ---
│   ├── Ground
│   └── Platforms
├── --- Characters ---
│   ├── Player
│   └── Enemies
├── --- UI ---
│   └── UIDocument (or Canvas)
├── --- Cameras ---
│   └── Main Camera
└── --- Runtime ---
    └── (pools, spawned objects)
```

---

## Screenshots & Reports (CONSTANT updates)

**Agent MUST update docs and take screenshots continuously, not just at the end.**

### Screenshot Rules
- Save in `Docs/Screenshots/iter-NN/`
- After EVERY Play Mode test → screenshot
- **ALWAYS review the screenshot** — open image, check content
- If screenshot is blank/wrong → note issue, retake, fix scene
- Link screenshot in `Docs/DEV_STATE.md`
- Never report "feature done" without reviewed screenshot

### Doc Update Frequency
| Event | Update DEV_STATE | Update DEV_LOG | Screenshot |
|-------|-----------------|----------------|------------|
| Start feature | ✅ (in progress) | ✅ (started) | — |
| Mid-feature checkpoint | ✅ (micro-plan) | — | Optional |
| Feature done | ✅ (progress %) | ✅ (completed) | ✅ Required |
| Stage done | ✅ (next stage) | ✅ (summary) | ✅ Required |
| Error found/fixed | ✅ (blocker) | ✅ (fix) | If relevant |
| End of session | ✅ (context) | ✅ (summary) | ✅ Final |

---

## Input System Policy

| Mode | Default |
|------|---------|
| fast | `Old` or `Both` |
| standard | `Old` or `Both` |
| pro | `New Input System` |
| Legacy project | Keep existing |

---

## Libraries (install before BUILD)

**Install by default (all projects):**
- **UniTask** — `git+https://github.com/Cysharp/UniTask.git?path=src/UniTask/Assets/Plugins/UniTask`
- **DOTween** — Asset Store or developer site (if available)
- **Newtonsoft.Json** — `com.unity.nuget.newtonsoft-json`

**As needed:** Unity Localization, VContainer, Cinemachine, Input System.

Check `Packages/manifest.json` first — don't install what's already there.
Use `manage_packages action=install` via MCP when possible.

Details: [tools/libraries-setup.md](tools/libraries-setup.md)

---

## Project Files (Docs/)

All memory files in `Docs/` folder. NEVER in project root.

| File | Purpose | Size | Update frequency |
|------|---------|------|-----------------|
| `Docs/DEV_CONFIG.md` | Settings, mode, toggles | Small | When settings change |
| `Docs/GAME_DESIGN.md` | Game design, mechanics, screens | Medium | When outline approved |
| `Docs/DEV_STATE.md` | Current state, progress, blockers | **Small (always)** | **Every action** |
| `Docs/AGENT_MEMORY.md` | Long-term memory, decisions | Small-medium | When important |
| `Docs/DEV_PLAN.md` | Full plan, task checkboxes | Medium | When planning |
| `Docs/ARCHITECTURE.md` | Architecture decisions | Medium | When implementing |
| `Docs/DEV_LOG/` | Iteration logs (iteration-NN-YYYYMMDD-HHMM.md) | Each small | On task completion |
| `Docs/Screenshots/` | Screenshots by iteration (iter-01/, iter-02/) | Grows | Every Play Mode test |

**Session start read order:** DEV_CONFIG → GAME_DESIGN → DEV_STATE → AGENT_MEMORY → DEV_PLAN → ARCHITECTURE

Templates: [reference.md](reference.md) and `templates/` folder.

### Agent Bootstrap (create Docs/ directly — do NOT rely on bat scripts)

When starting a new project, the agent **creates all Docs/ files directly** using file tools:

1. Create `Docs/` folder
2. Create `Docs/DEV_CONFIG.md` from template
3. Create `Docs/GAME_DESIGN.md` from template
4. Create `Docs/DEV_STATE.md` from template (with emoji sections)
5. Create `Docs/DEV_PLAN.md` from template
6. Create `Docs/AGENT_MEMORY.md` from template (**never skip**)
7. Create `Docs/ARCHITECTURE.md` from template (standard/pro)
8. Create `Docs/DEV_PROFILE.json` with current settings
9. Create `Docs/DEV_LOG/` folder
10. Create `Docs/DEV_LOG/iteration-01-YYYYMMDD-HHMM.md` (first iteration)
11. Create `Docs/Screenshots/iter-01/` folder

**For manual bootstrap (users without agent):** `setup_project.bat "<project-root>"`

### Machine-readable profile
`Docs/DEV_PROFILE.json` — persistent defaults:
```json
{
  "dev_mode": "standard",
  "ui_mode": "ui_toolkit",
  "mcp_mode": "use",
  "qa_per_feature": true,
  "reuse_first": true,
  "auto_mode": true
}
```

---

## Definition of Done (per feature)

Feature is DONE only when ALL are met:

- [ ] Code compiles clean (`validate_script` or `refresh_unity` + `read_console`)
- [ ] Play Mode smoke test passed (basic scenario works)
- [ ] `read_console` clean — no new errors
- [ ] Scene saved (`manage_scene action=save`)
- [ ] Screenshot taken, reviewed, shows expected result
- [ ] `Docs/DEV_STATE.md` updated (progress, micro-plan)
- [ ] `Docs/DEV_LOG/iteration-*.md` updated (completed entry)

**Do NOT move to next feature until all boxes checked.**

---

## DEV_PLAN Feature Format (example)

DEV_PLAN must ALWAYS use feature decomposition. Example for a 2D platformer (standard mode):

```markdown
# DEV_PLAN — 2D Platformer

## Stage 1: Core

### Feature 1: Player Movement
- [x] Create PlayerData SO (speed, jumpForce, gravity)
- [x] Create PlayerMovement.cs (run, jump, ground check)
- [x] Setup scene: Player GO + Rigidbody2D + Collider + Sprite
- [x] Play Mode test + screenshot

### Feature 2: Level
- [x] Create level layout (platforms, ground, walls)
- [x] Add colliders to all platforms
- [x] Camera follow player
- [ ] Play Mode test + screenshot

### Feature 3: Enemies
- [ ] Create EnemyData SO (speed, damage, health)
- [ ] Create EnemyController.cs (patrol, chase, attack)
- [ ] Spawn 3 enemies in level
- [ ] Play Mode test + screenshot

## Stage 2: Game Loop

### Feature 4: Health & Damage
- [ ] Create HealthComponent.cs (take damage, die)
- [ ] Player-enemy collision → damage
- [ ] Death → GameOver
- [ ] Play Mode test + screenshot

### Feature 5: HUD
- [ ] Create GameHUD (health bar, score)
- [ ] Wire to HealthComponent and ScoreManager
- [ ] Play Mode test + screenshot

### Feature 6: Menu & GameOver
- [ ] MainMenu scene (Play button)
- [ ] GameOver screen (Restart, Quit)
- [ ] Scene transitions
- [ ] Play Mode test + screenshot

## Progress: 1.5 / 6 features (25%)
```

**Key rules:**
- Each feature ends with "Play Mode test + screenshot"
- Tasks within feature are concrete (file names, SO names)
- `[x]` / `[ ]` checkboxes tracked
- Progress % at bottom

---

## Agent First Message (example)

When user says "Сделай 2D платформер" and nothing else, agent responds:

```
🎮 Starting a 2D platformer!

I need a few details:
1. **Mode:** fast (quick playable) / standard (complete game) / pro (scalable)?
   → Default: standard
2. **Platform:** PC / Mobile / WebGL?
   → Default: PC
3. **UI:** ui_toolkit / ugui / no_ui?
   → Default: ui_toolkit

If you skip, I'll use the defaults and start building.
```

When user confirms or says "давай" / "го" / just picks mode:

```
✅ Mode: standard | Platform: PC | UI: ui_toolkit

Starting PLAN phase. Scanning project structure...
[reads manifest.json, checks packages, detects structure]

Creating DEV_PLAN with feature decomposition...
[outputs plan]

Approve the plan? Then I start BUILD.
```

---

## Error Recovery

### Compilation fails
```
Attempt 1: Fix error based on read_console output
Attempt 2: Fix differently (check imports, typos, missing references)
Attempt 3: Revert last change, try simpler approach
Attempt 4: Ask user for help — show error, explain what was tried
```

### Play Mode crash
```
1. manage_scene action=stop (force exit)
2. read_console → find crash cause
3. Fix → recompile → retry Play Mode
4. If same crash → revert feature, rebuild step by step
```

### MCP not responding
```
1. Retry the operation (1 time)
2. Read mcpforunity://editor/state → check advice
3. If ready_for_tools=false → wait recommended_retry_after_ms, retry
4. If still fails → tell user: "MCP not responding. Check: Window → MCP for Unity → is server running?"
5. Switch to file-only mode if user confirms MCP is unavailable
```

### Screenshot is blank or wrong
```
1. Check Camera position and rotation
2. Check Game view resolution (not Free Aspect if fixed)
3. Check if objects are in camera frustum (find_gameobjects → check positions)
4. Retake screenshot
5. If still blank → note in DEV_STATE, continue (don't block on screenshot)
```

### Feature doesn't work after 3 attempts
```
1. Revert to last working state
2. Simplify the approach (less ambitious implementation)
3. Note in AGENT_MEMORY what didn't work and why
4. If still stuck → ask user for guidance
```

---

## Anti-Patterns (NEVER do these)

- ❌ Start coding without mode selection
- ❌ Start coding without plan approval (full cycle)
- ❌ Skip compile check after writing code
- ❌ Skip `read_console` after Play Mode
- ❌ Report "done" without reviewing screenshot
- ❌ Use legacy `UnityEngine.UI.Text` — ALWAYS `TextMeshPro`
- ❌ Create memory files in project root (only `Docs/`)
- ❌ Log file without datetime: `iteration-01.md` (must be `iteration-01-YYYYMMDD-HHMM.md`)
- ❌ Hardcode settings in MonoBehaviour (use SO)
- ❌ Use `Find`/`FindObjectOfType` in Update
- ❌ Add DI/ServiceLocator in fast mode without clear reason
- ❌ Use game-specific names in scripts (`TotalWar`, `MyGame`)
- ❌ Skip scene save after MCP changes
- ❌ Continue BUILD with broken MCP when `mcp_mode = use`
- ❌ Trust sub-agent output without verification
- ❌ Forget to update DEV_STATE and DEV_LOG
- ❌ Leave UI references without null checks in NoUI mode
- ❌ Impose `_source/` structure on projects that already have their own

---

## Core Mechanics Patterns

For reusable mechanics across projects: [tools/core-mechanics.md](tools/core-mechanics.md)

Key principles:
- Data in SO, logic in components
- One component, one mechanic
- Events over hard links
- Contracts (interfaces) where variants exist

---

## VCS Safety (Unity)

- Move/rename assets **only in Unity Editor** (`.meta` must travel with files)
- `.meta` files in VCS (never exclude)
- No spaces in file/folder names (`CamelCase` / `snake_case`)
- Keep sandbox scenes separate from production

---

## Quick Reference Links

- **Policy Matrix:** [POLICY_MATRIX.md](POLICY_MATRIX.md) — cadences, code quality, docs by mode
- **MCP Commands:** [mcp-commands.md](mcp-commands.md)
- **Templates:** [reference.md](reference.md)
- **Ready Prompts:** [PROMPTS.md](PROMPTS.md)
- **Code Rules:** [tools/code-writing.md](tools/code-writing.md)
- **Core Mechanics:** [tools/core-mechanics.md](tools/core-mechanics.md)
- **Libraries:** [tools/libraries-setup.md](tools/libraries-setup.md)
- **Modes:** [modes/fast.md](modes/fast.md) · [modes/standard.md](modes/standard.md) · [modes/pro.md](modes/pro.md)
- **Project Profiles:** `project-profiles/*.md`
- **Changelog:** [CHANGELOG.md](CHANGELOG.md)
