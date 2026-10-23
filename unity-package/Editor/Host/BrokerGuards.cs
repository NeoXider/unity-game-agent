using System;
using System.IO;
using System.Linq;
using UnityEditor;

namespace UnityGameAgent.EditorBroker
{
    // Guards apply only while an agent session is active and the broker is not paused; a human
    // working alone in the Editor is never affected. They report on the board rather than block,
    // except entering Play Mode outside a hot or exclusive window, which is cancelled.
    [InitializeOnLoad]
    static class BrokerGuards
    {
        static readonly string[] CompiledExtensions = { ".cs", ".asmdef", ".asmref", ".dll", ".rsp" };

        static BrokerGuards()
        {
            if (AssetDatabase.IsAssetImportWorkerProcess()) return;
            EditorApplication.playModeStateChanged += OnPlayModeStateChanged;
        }

        internal static bool Active(out BrokerState state)
        {
            state = BrokerHost.LastState;
            return BrokerHost.Enabled && state != null && state.SessionActive && !state.paused;
        }

        static bool PlayModeAllowed(BrokerState state)
        {
            if (!state.HasWindow) return false;
            var w = state.window;
            if (w.lane == BrokerConstants.LaneExclusive) return true;
            return w.lane == BrokerConstants.LaneHot &&
                   (w.phase == BrokerConstants.PhaseTests || w.phase == BrokerConstants.PhaseSession || w.phase == BrokerConstants.PhaseDraining);
        }

        static void OnPlayModeStateChanged(PlayModeStateChange change)
        {
            if (change != PlayModeStateChange.ExitingEditMode) return;
            BrokerState state;
            if (!Active(out state)) return;
            // Re-read: the executor may have opened the window during this very tick.
            BrokerState fresh;
            string error;
            if (BrokerHost.Store.TryRead(200, out fresh, out error)) state = fresh;
            if (PlayModeAllowed(state)) return;
            EditorApplication.isPlaying = false;
            BrokerHost.QueueViolation("", "play-mode-blocked",
                "Play Mode was entered outside a hot window during an agent session. Use 'request -Lane hot', or pause the broker on the board.");
        }

        internal static bool IsCompiledFile(string path)
        {
            var extension = Path.GetExtension(path ?? "");
            return CompiledExtensions.Any(e => string.Equals(e, extension, StringComparison.OrdinalIgnoreCase));
        }

        internal static bool SyncWindowOpen(BrokerState state)
        {
            return state.HasWindow &&
                   ((state.window.lane == BrokerConstants.LaneSync &&
                     (state.window.phase == BrokerConstants.PhaseApplying || state.window.phase == BrokerConstants.PhaseCompiling)) ||
                    state.window.lane == BrokerConstants.LaneExclusive);
        }

        // While tests or a session run, the Test Runner and the session's owner save on their own
        // (the runner writes a temporary Assets/InitTestScene*.unity, for example).
        internal static bool HotWindowRunning(BrokerState state)
        {
            return state.HasWindow && state.window.lane == BrokerConstants.LaneHot &&
                   (state.window.phase == BrokerConstants.PhaseTests || state.window.phase == BrokerConstants.PhaseSession);
        }
    }

    sealed class BrokerSaveGuard : AssetModificationProcessor
    {
        static string[] OnWillSaveAssets(string[] paths)
        {
            BrokerState state;
            if (!BrokerGuards.Active(out state) || BrokerGuards.SyncWindowOpen(state) || BrokerGuards.HotWindowRunning(state)) return paths;
            var now = BrokerClock.NowMs();
            foreach (var path in paths)
            {
                if (!path.StartsWith("Assets/", StringComparison.Ordinal) && !path.StartsWith("Packages/", StringComparison.Ordinal)) continue;
                if (path.StartsWith("Assets/InitTestScene", StringComparison.Ordinal)) continue;
                if (BrokerOps.OwnerOf(state, path, now).Length > 0) continue;
                BrokerHost.QueueViolation("", "unleased-save", path + " was saved while no agent holds a lease on it.");
            }
            // Never drop a save: losing someone's work is worse than a late warning.
            return paths;
        }
    }

    sealed class BrokerImportGuard : AssetPostprocessor
    {
        static void OnPostprocessAllAssets(string[] imported, string[] deleted, string[] moved, string[] movedFrom)
        {
            BrokerState state;
            if (!BrokerGuards.Active(out state) || BrokerGuards.SyncWindowOpen(state)) return;
            var now = BrokerClock.NowMs();
            foreach (var path in imported.Where(BrokerGuards.IsCompiledFile))
            {
                var owner = BrokerOps.OwnerOf(state, path, now);
                BrokerHost.QueueViolation(owner, "script-outside-sync",
                    path + " was imported outside a sync window. Write compiled files to your staging folder and request a sync.");
            }
        }
    }
}
