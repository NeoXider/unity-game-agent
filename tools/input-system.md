# Input System (new) — switching, Android Back, and driving it from QA

Use for any project on `com.unity.inputsystem`, and before changing **Active Input Handling**.
New mobile projects should use **Input System Package (New)** only: `Both` makes Unity warn at every
Android build ("not supported on Android and might cause input and performance issues").

## Switching a project to Input System only

1. **Find every legacy call first.** Under "Input System Package (New)" every `UnityEngine.Input`
   member throws `InvalidOperationException` at runtime — it compiles fine, so the compiler will not
   tell you.
   ```bash
   rg -n "Input\.(Get|mouse|touch|any|acceleration)" --glob "*.cs" Assets Packages
   ```
   Port project code to `Keyboard` / `Mouse` / `Touchscreen` / `Pointer`, or guard it with
   `#if ENABLE_LEGACY_INPUT_MANAGER`. Third-party plugins: check they are guarded
   (`#if ENABLE_INPUT_SYSTEM && !ENABLE_LEGACY_INPUT_MANAGER`) or not used in any scene.
2. **Replace `StandaloneInputModule`** on every `EventSystem` (all scenes and prefabs) with
   `InputSystemUIInputModule`, then call `AssignDefaultActions()` — a module added from code has no
   actions and silently ignores every tap. Verify the grep, not a brief: see
   [playmode-qa-automation.md](playmode-qa-automation.md) "Delegated Work".
3. **Set the handler** through the serialized PlayerSettings, not by hand-editing
   `ProjectSettings.asset` while the editor is open (the editor overwrites the file from memory):
   ```csharp
   var ps = UnityEditor.Unsupported.GetSerializedAssetInterfaceSingleton("PlayerSettings");
   var so = new UnityEditor.SerializedObject(ps);
   so.FindProperty("activeInputHandler").intValue = 1; // 0 legacy, 1 new, 2 both
   so.ApplyModifiedPropertiesWithoutUndo();
   UnityEditor.AssetDatabase.SaveAssets();
   ```
4. **Restart the editor** — the scripting defines change only after a restart. From automation:
   save/clean all scenes first, then
   `EditorApplication.delayCall += () => EditorApplication.OpenProject(Directory.GetCurrentDirectory());`
   and wait for MCP to reconnect (1–3 min). Confirm with `#if ENABLE_LEGACY_INPUT_MANAGER` in an
   eval that it is now off.
5. **Diff `ProjectSettings.asset` before committing.** Saving PlayerSettings writes the editor's
   *in-memory* values — company, product name, bundle id, splash — which may differ from git because
   the owner changed them in the editor and has not committed yet. That difference is the owner's
   newer intent: commit it or ask; never "restore" it from git.

## Android Back button

The legacy API delivered Back as `KeyCode.Escape`. With the Input System it is unreliable on
handsets, and **Predictive Back support** (on by default in new Unity 6 projects, Android 13+
`OnBackInvokedCallback`) changes how it arrives. Handle it through two channels and guard against
both firing for one press:

```csharp
private int _backHandledFrame = -1;

private void Update()
{
    // Keyboard.current can be null on a handset: check every keyboard device.
    foreach (var device in UnityEngine.InputSystem.InputSystem.devices)
        if (device is UnityEngine.InputSystem.Keyboard k && k.escapeKey.wasPressedThisFrame) { OnBack(); break; }
}

private void Awake()   => Application.wantsToQuit += OnWantsToQuit;
private void OnDestroy() => Application.wantsToQuit -= OnWantsToQuit;

// When no key event arrives, the system Back asks the app to quit instead. A game that never quits
// itself can treat that request as a Back press.
private bool OnWantsToQuit()
{
#if UNITY_ANDROID && !UNITY_EDITOR
    OnBack();
    return false;
#else
    return true;
#endif
}

private void OnBack()
{
    if (_backHandledFrame == Time.frameCount) return; // both channels in one frame
    _backHandledFrame = Time.frameCount;
    // navigate: close popup -> previous page -> menu; on the root page minimise (below)
}
```

- **Back on the root menu minimises**, it does not quit and does not do nothing:
  ```csharp
  #if UNITY_ANDROID && !UNITY_EDITOR
  using var player = new AndroidJavaClass("com.unity3d.player.UnityPlayer");
  using var activity = player.GetStatic<AndroidJavaObject>("currentActivity");
  activity.Call<bool>("moveTaskToBack", true);
  #endif
  ```
  Unity's Android manual recommends `moveTaskToBack` over `Application.Quit`.
- Screens that need an explicit choice (Win, reward, Time's Up, an ad in progress) ignore Back.
- If the project calls `Application.Quit` anywhere (a settings "Exit" button), let that path set a
  flag that `OnWantsToQuit` honours, or it can no longer quit.
- **Verify on a device.** Editor tests prove the navigation logic, not the delivery channel. Record
  "Back verified on device: yes/no" in the QA report.

## Driving the Input System from QA (Play Mode, via MCP eval)

Two traps make naive injection silently do nothing:

1. **Focus.** With the default `editorInputBehaviorInPlayMode = PointersAndKeyboardsRespectGameViewFocus`
   and `backgroundBehavior = ResetAndDisableNonBackgroundDevices`, an unfocused editor drops pointer
   and keyboard events, and existing devices get reset/disabled. Do not modify the project's settings
   asset — assign a **runtime instance** for the session:
   ```csharp
   var s = ScriptableObject.CreateInstance<UnityEngine.InputSystem.InputSettings>();
   s.backgroundBehavior = UnityEngine.InputSystem.InputSettings.BackgroundBehavior.IgnoreFocus;
   s.editorInputBehaviorInPlayMode =
       UnityEngine.InputSystem.InputSettings.EditorInputBehaviorInPlayMode.AllDeviceInputAlwaysGoesToGameView;
   UnityEngine.InputSystem.InputSystem.settings = s;
   ```
2. **Disabled devices.** Add fresh virtual devices instead of reusing `Mouse.current`:
   `InputSystem.AddDevice<Mouse>("QAMouse")`, `AddDevice<Keyboard>("QAKeyboard")`. Remove them
   (`InputSystem.RemoveDevice`) before leaving Play Mode.

A click must be move → press → release, with the input system and the EventSystem both updated
between steps. Doing all of it inside one eval makes it deterministic:

```csharp
var mouse = (Mouse)InputSystem.GetDevice("QAMouse");
var es = EventSystem.current;
var tick = typeof(EventSystem).GetMethod("Update", BindingFlags.Instance | BindingFlags.NonPublic);
void Step(Vector2 p, bool down) {
    var st = new MouseState { position = p };
    if (down) st = st.WithButton(MouseButton.Left, true);
    InputSystem.QueueStateEvent(mouse, st); InputSystem.Update(); tick.Invoke(es, null);
}
Vector2 at = RectTransformUtility.WorldToScreenPoint(null, button.transform.position); // overlay canvas
Step(at + Vector2.one, false); Step(at, true); Step(at, false);   // then assert the observable result
```

A drag is the same with intermediate `Step(p_i, true)` calls — use it to prove a scroll view does or
does not move on an axis. For a key, queue `new KeyboardState(Key.Escape)` then an empty
`KeyboardState()` on a later frame. This drives the real `InputSystemUIInputModule`, which
`ExecuteEvents.Execute` does not.
