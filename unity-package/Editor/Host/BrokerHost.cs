using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;
using Debug = UnityEngine.Debug;

namespace UnityGameAgent.EditorBroker
{
    // Runs inside the Editor: executes windows, reacts to focus leases, applies session settings
    // and publishes Library/UgaBroker/editor.json. All coordination state is file-based, so every
    // step is safe to resume after a domain reload, a Play Mode transition or an Editor restart.
    [InitializeOnLoad]
    public static class BrokerHost
    {
        const double TickSeconds = 0.25;
        const double HeartbeatSeconds = 1.0;

        static readonly List<BrokerViolation> s_PendingViolations = new List<BrokerViolation>();
        static double s_NextTick;
        static double s_NextHeartbeat;
        static string s_LastFocusLease = "";
        static string s_LastError = "";
        static bool s_ForceDue;

        public static bool Enabled { get; private set; }
        public static BrokerStore Store { get; private set; }
        // Guards read this; the executor refreshes it after every write so a guard firing inside
        // a window step (an import during Refresh, a Play Mode entry) sees the current phase.
        public static BrokerState LastState { get; internal set; }
        public static string LastDecision { get; internal set; } = "";
        public static long HotBlockedUntilMs { get; internal set; }

        static BrokerHost()
        {
            // Asset import workers load editor assemblies too; only the main Editor process hosts.
            if (AssetDatabase.IsAssetImportWorkerProcess()) return;
            BrokerStore.CurrentProjectRoot = Path.GetDirectoryName(Application.dataPath);
            Store = new BrokerStore(BrokerStore.CurrentProjectRoot);
            Enabled = true;
            LastState = new BrokerState();
            EditorApplication.update += Tick;
            EditorApplication.quitting += () =>
            {
                try { BrokerMachine.DeleteEntry(Store.ProjectRoot); }
                catch (IOException) { }
            };
            BrokerCompileWatcher.Register(Store);
            BrokerConsoleCapture.Register(Store);
        }

        public static void RequestForceDue()
        {
            s_ForceDue = true;
        }

        public static void QueueViolation(string agent, string kind, string detail)
        {
            lock (s_PendingViolations)
            {
                s_PendingViolations.Add(new BrokerViolation { atMs = BrokerClock.NowMs(), agent = agent ?? "", kind = kind, detail = detail });
            }
        }

        static void Tick()
        {
            // Batch mode spins this callback thousands of times per second: throttle by time.
            var t = EditorApplication.timeSinceStartup;
            if (t < s_NextTick) return;
            s_NextTick = t + TickSeconds;
            try
            {
                Step();
                s_LastError = "";
            }
            catch (Exception e)
            {
                if (s_LastError != e.Message) Debug.LogWarning("[UGA Broker] " + e);
                s_LastError = e.Message;
            }
            if (t >= s_NextHeartbeat)
            {
                s_NextHeartbeat = t + HeartbeatSeconds;
                WriteHeartbeat();
            }
        }

        public static BrokerFacts CurrentFacts()
        {
            var facts = new BrokerFacts
            {
                isCompiling = EditorApplication.isCompiling,
                isUpdating = EditorApplication.isUpdating,
                isPlaying = EditorApplication.isPlayingOrWillChangePlaymode,
                compileFailed = EditorUtility.scriptCompilationFailed,
                hotBlockedUntilMs = HotBlockedUntilMs,
                forceDue = s_ForceDue
            };
            return facts;
        }

        static void Step()
        {
            FlushViolations();
            var facts = CurrentFacts();
            s_ForceDue = false;
            BrokerExecutor.Step(Store, facts, BrokerClock.NowMs());
            BrokerState state;
            string error;
            if (Store.TryRead(50, out state, out error)) LastState = state;
            BrokerSettings.Sync(Store, LastState);
            ReactToFocus(LastState);
        }

        static void FlushViolations()
        {
            List<BrokerViolation> pending;
            lock (s_PendingViolations)
            {
                if (s_PendingViolations.Count == 0) return;
                pending = new List<BrokerViolation>(s_PendingViolations);
                s_PendingViolations.Clear();
            }
            BrokerState ignored;
            string error;
            var saved = Store.TryUpdate(s =>
            {
                foreach (var v in pending) BrokerOps.AddViolation(s, BrokerConfig.Default, v.agent, v.kind, v.detail, v.atMs);
                return true;
            }, 50, out ignored, out error);
            if (!saved)
                lock (s_PendingViolations) s_PendingViolations.InsertRange(0, pending);
        }

        // A focus lease makes its scene the active one so scene-graph MCP tools target it.
        static void ReactToFocus(BrokerState state)
        {
            if (state == null || state.HasWindow || EditorApplication.isPlayingOrWillChangePlaymode || EditorApplication.isCompiling) return;
            var now = BrokerClock.NowMs();
            var focus = state.leases.FirstOrDefault(l => l.kind == BrokerConstants.KindFocus && l.expiresMs > now);
            var focusId = focus != null ? focus.id : "";
            if (focusId == s_LastFocusLease) return;
            s_LastFocusLease = focusId;
            if (focus == null) return;
            var scene = SceneManager.GetSceneByPath(focus.path);
            if (!scene.IsValid() || !scene.isLoaded)
            {
                if (!File.Exists(Path.Combine(Store.ProjectRoot, focus.path))) return;
                scene = EditorSceneManager.OpenScene(focus.path, OpenSceneMode.Additive);
            }
            if (scene.IsValid() && scene.isLoaded) SceneManager.SetActiveScene(scene);
        }

        static void WriteHeartbeat()
        {
            var state = LastState ?? new BrokerState();
            var status = new BrokerEditorStatus
            {
                pid = Process.GetCurrentProcess().Id,
                unityVersion = Application.unityVersion,
                packageVersion = BrokerConstants.PackageVersion,
                projectPath = Store.ProjectRoot.Replace('\\', '/'),
                heartbeatMs = BrokerClock.NowMs(),
                isCompiling = EditorApplication.isCompiling,
                isUpdating = EditorApplication.isUpdating,
                isPlaying = EditorApplication.isPlaying,
                compileFailed = EditorUtility.scriptCompilationFailed,
                brokerPaused = state.paused,
                activeScene = SceneManager.GetActiveScene().path,
                lastError = s_LastError
            };
            status.phase = state.HasWindow ? "window " + state.window.lane + "/" + state.window.phase
                : status.isCompiling ? "compiling"
                : status.isUpdating ? "importing"
                : status.isPlaying ? "playing"
                : "idle";
            for (var i = 0; i < SceneManager.sceneCount; i++)
            {
                var scene = SceneManager.GetSceneAt(i);
                var name = scene.path.Length > 0 ? scene.path : "(untitled)";
                if (scene.isLoaded) status.loadedScenes.Add(name);
                if (scene.isDirty) status.dirtyScenes.Add(name);
            }
            BrokerSettings.FillReport(status);
            try
            {
                Store.WriteEditorStatus(status);
                // One registry entry per project lets the CLI list every live broker on this machine.
                BrokerMachine.WriteEntry(new BrokerMachineEntry
                {
                    projectPath = status.projectPath, pid = status.pid, unityVersion = status.unityVersion,
                    packageVersion = status.packageVersion, heartbeatMs = status.heartbeatMs, phase = status.phase,
                    sessionId = state.sessionId, leases = state.leases.Count,
                    queuedJobs = state.jobs.Count(j => j.status == BrokerConstants.JobQueued),
                    window = state.HasWindow ? state.window.id + " " + state.window.lane + "/" + state.window.phase : ""
                });
            }
            catch (IOException)
            {
                // A reader held the file during the swap; the next heartbeat retries.
            }
            catch (UnauthorizedAccessException)
            {
                // Same as above on platforms that report sharing conflicts this way.
            }
        }

        public static List<string> DirtyScenes()
        {
            var dirty = new List<string>();
            for (var i = 0; i < SceneManager.sceneCount; i++)
            {
                var scene = SceneManager.GetSceneAt(i);
                if (scene.isDirty) dirty.Add(scene.path.Length > 0 ? scene.path : "(untitled)");
            }
            return dirty;
        }
    }
}
