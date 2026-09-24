# Audio: generate, import, play, pause

A casual game needs roughly: 2 music loops (menu, gameplay), 1 ambience bed, and 12–20 short SFX
(tap, popup, grab, step, connect, undo, restart, hint, win, coins, gift, unlock, timer tick,
time's up). Plan the list from the game's events before generating anything.

## 1. Where audio comes from — in this order

1. **Generate.** Look for an existing pipeline before concluding there is none — packaged skills are
   not found by scanning project folders:
   - `~/.codex/skills/neoxider-video-studio` → `scripts/generate_audio.py --kind music|sfx|ambience
     --prompt "..." --duration N`, providers in `providers/stable_audio_3.json` (SFX, ambience) and
     `providers/ace_step_1_5.json` (music with structure), ComfyUI workflows under `AudioGen/`.
   - fal.ai (Stable Audio, ElevenLabs SFX) when a key is configured.
   - Also search `~/.claude/skills`, `~/.codex/skills`, and the project's own tools.
2. **Source** free clips whose licence allows shipping (CC0 first: Kenney, freesound CC0 filter,
   OpenGameArt CC0). Record source + licence per file in the project docs.
3. **Report the gap and ask.**

**Never hand-synthesise** clips with sine/noise arithmetic — they sound like test tones and quietly
lower the deliverable. That is not a fourth option.

Prompting notes that worked:
- Music: genre + mood + instrumentation + "seamless loop" + BPM; 60–120 s; ask for no vocals.
- SFX: one physical action, short, dry ("soft glass click, UI button, 0.15 s, no reverb tail").
  Generate 3–4 variants and pick by ear; trim silence at both ends (the start latency is audible).
- Match the whole set to one palette (e.g. glassy/soft for a calm puzzle); one harsh SFX spoils it.

## 2. Import settings

| Clip | Load Type | Compression | Mono | Notes |
|---|---|---|---|---|
| Music / ambience (> 10 s) | **Streaming** | Vorbis, quality 0.5–0.7 | no | streaming keeps it out of RAM |
| Frequent short SFX (tap, step, tick) | Decompress On Load | ADPCM or Vorbis | **yes** | zero decode latency |
| Other SFX | Compressed In Memory | Vorbis | yes | |

Normalise loudness across the set before import (music around −16 LUFS, SFX peaks around −1 dBFS),
then balance with mixer groups or volumes — not by re-exporting files one by one.

## 3. Playback architecture

- One audio owner (NeoxiderTools `AM` or the project's manager) with separate **music** and **SFX**
  volumes/toggles, persisted in settings. Music crossfades between menu and gameplay tracks.
- **One tap sound for every button** by hooking all `Button`s under the page root at startup —
  including pages that start inactive (`GetComponentsInChildren<Button>(true)`) — instead of wiring
  each button by hand.
- Rate-limit repeated SFX (a path step per cell during a fast drag): skip a clip if the same clip
  started < 40 ms ago, and vary pitch slightly (±3 %) to avoid a machine-gun effect.
- Pair important SFX with haptics (success, warning, light tap) through one haptics wrapper that
  respects the vibration setting (e.g. `com.tsyk5.mobilehapticfeedback` for iOS + Android).

## 4. Pause in the background and during ads

Music and SFX must stop when the app is minimised, the screen locks, a call comes in, or a rewarded
video plays — and **resume where they stopped** rather than restart.

- Use `AudioListener.pause` (pauses all sources, keeps their positions) with **one owner** that ORs
  every reason together; two scripts toggling it independently will unpause each other:
  ```csharp
  static void Apply() => AudioListener.pause = _adPlaying || _inBackground;
  void OnApplicationPause(bool paused) { _inBackground = paused; Apply(); }
  void OnApplicationFocus(bool focused) { if (!Application.isEditor) { _inBackground = !focused; Apply(); } }
  ```
  Create it with `RuntimeInitializeOnLoadMethod(BeforeSceneLoad)` + `DontDestroyOnLoad` so the
  loading screen is covered too. Ignore focus in the editor (clicking another window is not a pause).
- UI click sources that must keep playing while paused need `AudioSource.ignoreListenerPause = true`.
- Level timers must stop in the background too, and cap the first frame's delta after resume
  (`Mathf.Min(Time.unscaledDeltaTime, 0.1f)`), or the time away comes off the clock.

## 5. Verify

- Every event in the list plays exactly once per trigger (log or count `PlayOneShot` calls in a
  driven scenario), and no clip plays on a disabled toggle.
- Minimise/restore on a device: music resumes mid-track. In the editor, call the owner's
  pause/unpause path directly; `OnApplicationPause` does not fire there.
- Listen to the whole set in sequence once: mismatched loudness or a harsh outlier is a defect.
