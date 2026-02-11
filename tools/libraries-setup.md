# Libraries setup — how to add (for agent)

Instructions for the agent: how to add commonly used libraries to a Unity project. **Full install list** — step by step below.

---

## Install before development starts

**Agent must** install libraries from this file before starting implementation (after plan approval, before first feature). Do not proceed to implementation until installed.

**Install by default (all projects):**
- **UniTask** — async/await.
- **DOTween** — tweens (if no Asset Store access — note in DEV_STATE and use built-in Animator/code where tweens are needed).
- **Newtonsoft.Json** — JSON (saves, configs, API); Unity package `com.unity.nuget.newtonsoft-json`.

**As needed (per task / GAME_DESIGN / DEV_CONFIG):**
- **Unity Localization** — only if multiple languages are required.
- Rest (VContainer, Cinemachine, Input System) — only when explicitly required.

Check **Packages/manifest.json** and **Assets**: if a package is already present — do not add again. After install record in `Docs/DEV_LOG/` or `Docs/AGENT_MEMORY.md`.

---

## UniTask (Cysharp)

**Purpose:** async/await for Unity, no allocation, cancellation, await for AsyncOperation and coroutines. Recommended for delays, scene load, operation chains.

### How to add

**Option 1: Package Manager (recommended)**

1. In Unity: **Window → Package Manager**.
2. **+** (Add) → **Add package from git URL...**.
3. Paste URL:
   ```
   https://github.com/Cysharp/UniTask.git?path=src/UniTask/Assets/Plugins/UniTask
   ```
4. **Add**. Wait for import.

**Option 2: manifest.json (if editing files directly)**

In `Packages/manifest.json`, inside `dependencies` add (with comma after previous entry):

```json
"com.cysharp.unitask": "git+https://github.com/Cysharp/UniTask.git?path=src/UniTask/Assets/Plugins/UniTask"
```

Save; Unity will fetch the package on next reload/refresh.

**Requirements:** Git installed. Unity 2018.4+.

**Verify:** `using Cysharp.Threading.Tasks;` and types `UniTask`, `UniTaskVoid` available.

**Docs:** [UniTask GitHub](https://github.com/Cysharp/UniTask#readme).

---

## DOTween (Demigiant)

**Purpose:** tweens for transform, UI, arbitrary values. Quick animation setup without Animator.

### How to add

DOTween is distributed via **Asset Store** and developer site; no official UPM from Demigiant.

**Option 1: Asset Store**

1. [DOTween (HOTween v2) on Asset Store](https://assetstore.unity.com/packages/tools/animation/dotween-hotween-v2-27676).
2. Add to cart / get (free version available).
3. Unity: **Window → Package Manager** → **My Assets** (or **Asset Store**) → find DOTween → **Download** / **Import**.
4. Import into project.
5. After first import: **Tools → Demigiant → DOTween Utility Panel** → **Setup** (select modules: Unity, TextMeshPro, 2D etc.) → Apply.

**Option 2: Developer site**

1. Go to [dotween.demigiant.com](https://dotween.demigiant.com/download.php).
2. Download latest **DOTween*.unitypackage**.
3. Unity: **Assets → Import Package → Custom Package** → select .unitypackage → **Import**.
4. After import: **Tools → Demigiant → DOTween Utility Panel** → **Setup** (select modules) → **Apply**.

**Verify:** e.g. `transform.DOMove(...)` with `using DG.Tweening;`.

**Docs:** [DOTween Documentation](https://dotween.demigiant.com/documentation.php).

---

## Newtonsoft.Json (Json.NET)

**Purpose:** JSON serialize/deserialize — saves, config load, API responses. Often already in project or needed for first save feature.

### How to add

**Unity 2022+ (official Unity package)**

1. **Window → Package Manager**.
2. **+** → **Add package by name...**.
3. Package name: `com.unity.nuget.newtonsoft-json`.
4. **Add**.

**manifest.json:** in `dependencies` add:
```json
"com.unity.nuget.newtonsoft-json": "3.2.2"
```
(or current version from Unity package list.)

**Verify:** `using Newtonsoft.Json;` (e.g. `JsonConvert.SerializeObject`, `JsonConvert.DeserializeObject`).

---

## Unity Localization (as needed)

**Purpose:** localization — string tables, keys, text by language. Built-in Unity package.

### How to add

1. **Window → Package Manager**.
2. **+** → **Add package by name...**.
3. Name: `com.unity.localization`.
4. **Add**.

Then create Tables, keys, assign locales. Docs: [Unity Localization](https://docs.unity3d.com/Packages/com.unity.localization@1.0/manual/index.html). Add only if GAME_DESIGN or user request requires multiple languages.

---

## Other (as needed)

- **VContainer / Zenject** — DI for large projects (Pro mode). Install only when architecture clearly needs IoC. VContainer: UPM/Git; Zenject (Extenject): Asset Store or [GitHub](https://github.com/Mathijs-Bakker/Extenject).
- **Cinemachine** — camera (follow, virtual cameras). Built-in: `com.unity.cinemachine`. Add when advanced camera is needed.
- **Input System** — new input. Built-in: `com.unity.inputsystem`. Required if new Input System is selected in settings.

---

## For the agent

- Before adding a library check **Packages/manifest.json** and **Assets** — it may already be installed.
- After adding any library from this file record in iteration file (`Docs/DEV_LOG/`) or `Docs/AGENT_MEMORY.md` so it is not added again.
- Add only for a concrete need (saves → Newtonsoft; tweens → DOTween; multiple languages → Localization). If the user asked for a different library or install method — follow that.
