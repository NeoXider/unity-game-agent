using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

namespace UnityGameAgent.EditorBroker
{
    // Executes the current window one small step per tick. Each step reads the state, performs at
    // most one Unity operation outside the state lock and records the outcome, so a domain reload
    // between steps resumes from the phase stored in state.json.
    static class BrokerExecutor
    {
        const long SettleMs = 1500;
        const long TestReportTimeoutMs = 30 * 60 * 1000;
        const long PlayStartTimeoutMs = 120 * 1000;

        static BrokerConfig Cfg => BrokerConfig.Default;

        // A telemetry segment closed by a session change; appended only after the state write succeeded.
        static BrokerTelemetry s_ClosedTelemetry;

        public static void Step(BrokerStore store, BrokerFacts facts, long now)
        {
            BrokerState state;
            string error;
            s_ClosedTelemetry = null;
            if (!store.TryUpdate(s => Housekeeping(s, facts, now), 50, out state, out error)) return;
            if (s_ClosedTelemetry != null) AppendTelemetry(store, s_ClosedTelemetry);
            BrokerHost.LastState = state;
            if (!state.HasWindow) return;
            switch (state.window.phase)
            {
                case BrokerConstants.PhaseDraining: StartWindow(store, state, facts, now); break;
                case BrokerConstants.PhaseApplying: ApplySync(store, state, now); break;
                case BrokerConstants.PhaseCompiling: FinishSync(store, state, facts, now); break;
                case BrokerConstants.PhaseTests: PollTests(store, state, now); break;
                case BrokerConstants.PhaseSession: StepSession(store, state, now); break;
                case BrokerConstants.PhaseExclusive: StepExclusive(store, state, now); break;
                case BrokerConstants.PhaseSettling: FinishSettling(store, state, facts, now); break;
            }
        }

        static bool Housekeeping(BrokerState s, BrokerFacts facts, long now)
        {
            var changed = BrokerOps.Expire(s, now) > 0;
            changed |= BrokerOps.Promote(s, Cfg, now).Count > 0;
            bool counted;
            s_ClosedTelemetry = BrokerTelemetryOps.Record(s, now, out counted);
            changed |= counted;
            if (s.HasWindow) return changed;
            var decision = BrokerScheduler.Decide(s, facts, Cfg, now);
            BrokerHost.LastDecision = decision.reason;
            if (!decision.OpensWindow) return changed;
            BrokerScheduler.BeginWindow(s, decision, Cfg, now);
            return true;
        }

        // One JSON line per closed session segment: the project's history for 'editor-broker stats'.
        static void AppendTelemetry(BrokerStore store, BrokerTelemetry segment)
        {
            try
            {
                Directory.CreateDirectory(store.Dir);
                File.AppendAllText(Path.Combine(store.Dir, "telemetry.jsonl"), JsonUtility.ToJson(segment) + "\n", new UTF8Encoding(false));
            }
            catch (IOException)
            {
                // History is best effort; the live counters stay in the state file.
            }
        }

        static bool Update(BrokerStore store, Func<BrokerState, bool> mutate)
        {
            BrokerState state;
            string error;
            if (!store.TryUpdate(mutate, 2000, out state, out error)) return false;
            BrokerHost.LastState = state;
            return true;
        }

        static List<BrokerJob> WindowJobs(BrokerState s)
        {
            return s.jobs.Where(j => s.window.jobIds.Contains(j.id)).ToList();
        }

        static void StartWindow(BrokerStore store, BrokerState state, BrokerFacts facts, long now)
        {
            if (!BrokerScheduler.DrainComplete(state, now)) return;
            var lane = state.window.lane;
            if (lane == BrokerConstants.LaneHot)
            {
                if (facts.compileFailed)
                {
                    Abort(store, "Scripts have compile errors; hot work waits for a clean sync.", now);
                    return;
                }
                var dirty = BrokerHost.DirtyScenes();
                if (dirty.Count > 0)
                {
                    if (now < state.window.drainDeadlineMs) return;
                    Abort(store, "Unsaved scenes block Play Mode: " + string.Join(", ", dirty) +
                                 ". Their owners must save before yielding.", now);
                    return;
                }
                if (facts.isPlaying || facts.isCompiling) return;
                Update(store, s =>
                {
                    s.window.startedMs = now;
                    return true;
                });
                StartNextHot(store, now);
                return;
            }

            Update(store, s =>
            {
                var w = s.window;
                w.startedMs = now;
                foreach (var job in WindowJobs(s))
                {
                    job.status = BrokerConstants.JobRunning;
                    job.startedMs = now;
                }
                if (lane == BrokerConstants.LaneSync)
                {
                    BrokerScheduler.SetPhase(s, BrokerConstants.PhaseApplying, now);
                }
                else
                {
                    BrokerScheduler.SetPhase(s, BrokerConstants.PhaseExclusive, now);
                    var job = WindowJobs(s).FirstOrDefault();
                    w.deadlineMs = now + (long)((job != null ? job.minutes : Cfg.exclusiveDefaultMinutes) * 60000f);
                    w.currentJob = job != null ? job.id : "";
                }
                return true;
            });
            if (lane == BrokerConstants.LaneSync)
            {
                BrokerState fresh;
                string error;
                if (store.TryRead(2000, out fresh, out error)) ApplySync(store, fresh, now);
            }
        }

        static void Abort(BrokerStore store, string reason, long now)
        {
            BrokerHost.HotBlockedUntilMs = now + Cfg.hotRetryCooldownMs;
            Update(store, s =>
            {
                BrokerOps.AddViolation(s, Cfg, "", "window-blocked", s.window.id + ": " + reason, now);
                BrokerScheduler.EndWindow(s, Cfg, now);
                return true;
            });
        }

        // SYNC: publish every requester's staged files, import explicit paths, then one Refresh that
        // compiles all script changes together.
        static void ApplySync(BrokerStore store, BrokerState state, long now)
        {
            var jobs = WindowJobs(state);
            var applied = new List<string>();
            var rejected = new Dictionary<string, List<string>>(StringComparer.OrdinalIgnoreCase);
            foreach (var agent in jobs.Select(j => j.agent).Distinct(StringComparer.OrdinalIgnoreCase))
            {
                var dir = store.StagingDir(agent);
                if (!Directory.Exists(dir)) continue;
                foreach (var file in Directory.GetFiles(dir, "*", SearchOption.AllDirectories))
                {
                    var relative = file.Substring(dir.Length).TrimStart('\\', '/').Replace('\\', '/');
                    var normalized = BrokerPaths.NormalizePath(relative, false);
                    var owned = normalized != null && BrokerOps.HoldsCover(state, agent, normalized, now);
                    if (!owned)
                    {
                        if (!rejected.ContainsKey(agent)) rejected[agent] = new List<string>();
                        rejected[agent].Add(relative);
                        continue;
                    }
                    var target = Path.Combine(store.ProjectRoot, normalized);
                    Directory.CreateDirectory(Path.GetDirectoryName(target));
                    File.Copy(file, target, true);
                    File.Delete(file);
                    applied.Add(agent + "|" + normalized);
                }
                RemoveEmptyDirectories(dir);
            }

            Update(store, s =>
            {
                BrokerScheduler.SetPhase(s, BrokerConstants.PhaseCompiling, now);
                s.window.appliedFiles = applied;
                foreach (var job in WindowJobs(s))
                {
                    List<string> mine;
                    if (rejected.TryGetValue(job.agent, out mine))
                        foreach (var path in mine) job.details.Add("rejected: " + path + " is not under your lease; it stays staged.");
                }
                return true;
            });

            var explicitPaths = jobs.SelectMany(j => j.paths)
                .Where(p => File.Exists(Path.Combine(store.ProjectRoot, p)))
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .ToList();
            if (explicitPaths.Count > 0)
            {
                AssetDatabase.StartAssetEditing();
                try
                {
                    foreach (var path in explicitPaths) AssetDatabase.ImportAsset(path, ImportAssetOptions.ForceUpdate);
                }
                finally
                {
                    AssetDatabase.StopAssetEditing();
                }
            }
            AssetDatabase.Refresh(ImportAssetOptions.Default);
        }

        static void RemoveEmptyDirectories(string root)
        {
            foreach (var dir in Directory.GetDirectories(root, "*", SearchOption.AllDirectories).OrderByDescending(d => d.Length))
                if (Directory.GetFileSystemEntries(dir).Length == 0) Directory.Delete(dir);
        }

        static void FinishSync(BrokerStore store, BrokerState state, BrokerFacts facts, long now)
        {
            if (facts.isCompiling || facts.isUpdating) return;
            if (now - state.window.phaseStartedMs < SettleMs) return;
            var compileFailed = EditorUtility.scriptCompilationFailed;
            var log = BrokerCompileWatcher.Read(store);
            var errors = compileFailed && log != null ? log.messages : new List<BrokerCompileMessage>();
            var appliedBy = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            foreach (var entry in state.window.appliedFiles)
            {
                var split = entry.IndexOf('|');
                if (split > 0) appliedBy[entry.Substring(split + 1)] = entry.Substring(0, split);
            }

            Update(store, s =>
            {
                string Owner(string file)
                {
                    var path = (file ?? "").Replace('\\', '/');
                    string agent;
                    if (appliedBy.TryGetValue(path, out agent)) return agent;
                    return BrokerOps.OwnerOf(s, path, now);
                }

                var owners = errors.Select(e => Owner(e.file)).ToList();
                var culprits = owners.Select(o => o.Length > 0 ? o : "unowned files").Distinct().ToList();
                foreach (var job in WindowJobs(s))
                {
                    var own = errors.Where((e, i) => BrokerOps.SameAgent(owners[i], job.agent)).Select(Describe).ToList();
                    var files = appliedBy.Values.Count(a => BrokerOps.SameAgent(a, job.agent));
                    var rejected = job.details.Where(d => d.StartsWith("rejected:", StringComparison.Ordinal)).ToList();
                    if (own.Count > 0)
                        BrokerOps.Finish(job, BrokerConstants.JobFailed, own.Count + " compile error(s) in your files; nothing new was loaded.", own.Concat(rejected), now);
                    else if (rejected.Count > 0)
                        BrokerOps.Finish(job, BrokerConstants.JobFailed, rejected.Count + " staged file(s) were outside your lease and were not applied.", rejected, now);
                    else if (compileFailed)
                        BrokerOps.Finish(job, BrokerConstants.JobBlocked, "Applied " + files + " file(s), but compilation failed in " +
                                                                           string.Join(", ", culprits) + "; your code loads after the next clean compile.",
                            errors.Take(10).Select(Describe), now);
                    else
                        BrokerOps.Finish(job, BrokerConstants.JobPassed, "Applied " + files + " file(s); import and compile finished cleanly.", null, now);
                }
                if (owners.Any(o => o.Length == 0))
                    BrokerOps.AddViolation(s, Cfg, "", "unowned-compile-errors",
                        "Compile errors in files nobody leased: " + string.Join(", ", errors.Where((e, i) => owners[i].Length == 0).Select(e => e.file).Distinct()), now);
                BrokerScheduler.EndWindow(s, Cfg, now);
                return true;
            });
        }

        static string Describe(BrokerCompileMessage message)
        {
            return message.file + "(" + message.line + "): " + message.message;
        }

        // HOT: one test run per test mode for every queued selection, then Play Mode sessions in order.
        static void StartNextHot(BrokerStore store, long now)
        {
            BrokerState state;
            string error;
            if (!store.TryRead(2000, out state, out error)) return;
            var w = state.window;
            var pending = WindowJobs(state).Where(j => j.status == BrokerConstants.JobQueued).ToList();

            var tests = pending.Where(j => j.kind == BrokerConstants.JobTests).ToList();
            if (tests.Count > 0)
            {
                var mode = tests.Any(j => j.testMode == "EditMode") ? "EditMode" : "PlayMode";
                var batch = tests.Where(j => j.testMode == mode).ToList();
                var ids = batch.Select(j => j.id).ToList();
                if (BrokerTestHook.Start == null)
                {
                    FailJobs(store, ids, "The Unity Test Framework package is not installed in this project.", now);
                    StartNextHot(store, now);
                    return;
                }
                File.Delete(BrokerTestHook.ResultPath(store, w.id, mode));
                Update(store, s =>
                {
                    BrokerScheduler.SetPhase(s, BrokerConstants.PhaseTests, now);
                    s.window.currentJob = mode;
                    foreach (var job in s.jobs.Where(j => ids.Contains(j.id)))
                    {
                        job.status = BrokerConstants.JobRunning;
                        job.startedMs = now;
                    }
                    return true;
                });
                string startError;
                if (!BrokerTestHook.Start(w.id, mode, batch, out startError))
                {
                    FailJobs(store, ids, "Test run did not start: " + startError, now);
                    StartNextHot(store, now);
                }
                return;
            }

            var sessions = pending.Where(j => j.kind == BrokerConstants.JobSession || j.kind == BrokerConstants.JobSmoke).ToList();
            var withinCap = w.startedMs == 0 || now - w.startedMs < Cfg.hotWindowMaxMs;
            if (sessions.Count > 0 && withinCap)
            {
                var job = sessions[0];
                var setup = BrokerSceneSetup.Serialize(EditorSceneManager.GetSceneManagerSetup());
                BrokerConsoleCapture.Reset(store, job.id);
                Update(store, s =>
                {
                    BrokerScheduler.SetPhase(s, BrokerConstants.PhaseSession, now);
                    s.window.currentJob = job.id;
                    s.window.note = "";
                    s.window.sceneSetup = setup;
                    s.window.deadlineMs = now + (long)(job.minutes * 60000f);
                    var stored = s.jobs.First(j => j.id == job.id);
                    stored.status = BrokerConstants.JobRunning;
                    stored.startedMs = now;
                    return true;
                });
                if (job.scene.Length > 0 && File.Exists(Path.Combine(store.ProjectRoot, job.scene)))
                    EditorSceneManager.OpenScene(job.scene, OpenSceneMode.Single);
                EditorApplication.isPlaying = true;
                return;
            }

            Update(store, s =>
            {
                BrokerScheduler.EndWindow(s, Cfg, now);
                return true;
            });
        }

        static void FailJobs(BrokerStore store, List<string> ids, string summary, long now)
        {
            Update(store, s =>
            {
                foreach (var job in s.jobs.Where(j => ids.Contains(j.id))) BrokerOps.Finish(job, BrokerConstants.JobFailed, summary, null, now);
                return true;
            });
        }

        static void PollTests(BrokerStore store, BrokerState state, long now)
        {
            var mode = state.window.currentJob;
            var path = BrokerTestHook.ResultPath(store, state.window.id, mode);
            var running = WindowJobs(state).Where(j => j.kind == BrokerConstants.JobTests && j.testMode == mode &&
                                                       j.status == BrokerConstants.JobRunning).Select(j => j.id).ToList();
            if (!File.Exists(path))
            {
                if (now - state.window.phaseStartedMs > TestReportTimeoutMs)
                {
                    FailJobs(store, running, "The " + mode + " test run did not report within 30 minutes.", now);
                    StartNextHot(store, now);
                }
                return;
            }
            BrokerTestRunResult result;
            try
            {
                result = JsonUtility.FromJson<BrokerTestRunResult>(File.ReadAllText(path));
            }
            catch (IOException)
            {
                return;
            }
            Update(store, s =>
            {
                foreach (var job in s.jobs.Where(j => running.Contains(j.id)))
                {
                    string parseError;
                    var filter = BrokerTestFilter.Parse(job.tests, out parseError);
                    if (result.error.Length > 0)
                    {
                        BrokerOps.Finish(job, BrokerConstants.JobFailed, "Test run failed: " + result.error, null, now);
                        continue;
                    }
                    var matched = result.cases.Where(c => filter != null && filter.Matches(c.fullName, c.assembly, c.categories)).ToList();
                    var failed = matched.Where(c => c.status == "Failed").ToList();
                    var passed = matched.Count(c => c.status == "Passed");
                    if (matched.Count == 0)
                        BrokerOps.Finish(job, BrokerConstants.JobFailed, "No " + mode + " test matched '" + job.tests + "'; an empty selection is not a pass.", null, now);
                    else if (failed.Count > 0)
                        BrokerOps.Finish(job, BrokerConstants.JobFailed, failed.Count + " of " + matched.Count + " " + mode + " tests failed.",
                            failed.Select(c => c.fullName + ": " + c.message), now);
                    else if (passed == 0)
                        BrokerOps.Finish(job, BrokerConstants.JobFailed, "All " + matched.Count + " matched tests were skipped or inconclusive.", null, now);
                    else
                        BrokerOps.Finish(job, BrokerConstants.JobPassed, passed + " " + mode + " test(s) passed, " + (matched.Count - passed) + " skipped.", null, now);
                }
                return true;
            });
            File.Delete(path);
            StartNextHot(store, now);
        }

        static void StepSession(BrokerStore store, BrokerState state, long now)
        {
            var w = state.window;
            var job = state.jobs.FirstOrDefault(j => j.id == w.currentJob);
            if (job == null)
            {
                StartNextHot(store, now);
                return;
            }
            var playing = EditorApplication.isPlaying;
            if (w.note.Length == 0)
            {
                if (playing)
                {
                    // The session clock starts when Play Mode is really running.
                    Update(store, s =>
                    {
                        s.window.note = "playing";
                        s.window.deadlineMs = now + (long)(job.minutes * 60000f);
                        return true;
                    });
                    return;
                }
                if (now - w.phaseStartedMs > PlayStartTimeoutMs && !EditorApplication.isPlayingOrWillChangePlaymode)
                {
                    CloseSession(store, state, job, BrokerConstants.JobFailed, "Play Mode did not start (check compile errors and the console).", now);
                }
                return;
            }

            var stoppedByAgent = !EditorApplication.isPlayingOrWillChangePlaymode;
            var finishing = job.doneRequested || now >= w.deadlineMs || stoppedByAgent;
            if (!finishing) return;
            if (EditorApplication.isPlaying)
            {
                EditorApplication.isPlaying = false;
                return;
            }
            if (EditorApplication.isPlayingOrWillChangePlaymode || EditorApplication.isCompiling) return;
            var errors = BrokerConsoleCapture.ReadAndDelete(store, job.id);
            if (job.kind == BrokerConstants.JobSmoke)
            {
                var ok = errors.Count == 0;
                CloseSession(store, state, job, ok ? BrokerConstants.JobPassed : BrokerConstants.JobFailed,
                    ok ? "Smoke Play Mode run logged no errors." : errors.Count + " error(s) were logged during the smoke Play Mode run.", now, errors);
                if (!ok && job.reason == BrokerSettings.SmokeReason) BrokerSettings.RollbackEnterPlayModeOptions(store, errors);
                return;
            }
            var why = job.doneRequested ? "finished by the agent" : stoppedByAgent ? "Play Mode was stopped" : "time box reached";
            CloseSession(store, state, job, BrokerConstants.JobPassed,
                "Play Mode session " + why + "; " + errors.Count + " console error(s). The verdict belongs to the agent.", now, errors);
        }

        static void CloseSession(BrokerStore store, BrokerState state, BrokerJob job, string status, string summary, long now,
            List<string> details = null)
        {
            if (job.scene.Length > 0 && state.window.sceneSetup.Length > 0 && BrokerHost.DirtyScenes().Count == 0)
            {
                var setup = BrokerSceneSetup.Deserialize(state.window.sceneSetup);
                if (setup.Length > 0) EditorSceneManager.RestoreSceneManagerSetup(setup);
            }
            Update(store, s =>
            {
                var stored = s.jobs.First(j => j.id == job.id);
                BrokerOps.Finish(stored, status, summary, details, now);
                s.window.currentJob = "";
                s.window.note = "";
                return true;
            });
            StartNextHot(store, now);
        }

        static void StepExclusive(BrokerStore store, BrokerState state, long now)
        {
            var job = state.jobs.FirstOrDefault(j => j.id == state.window.currentJob);
            if (job != null && !job.doneRequested && now < state.window.deadlineMs) return;
            if (EditorApplication.isPlaying)
            {
                EditorApplication.isPlaying = false;
                return;
            }
            Update(store, s =>
            {
                BrokerScheduler.SetPhase(s, BrokerConstants.PhaseSettling, now);
                return true;
            });
            AssetDatabase.Refresh(ImportAssetOptions.Default);
        }

        static void FinishSettling(BrokerStore store, BrokerState state, BrokerFacts facts, long now)
        {
            if (facts.isCompiling || facts.isUpdating || EditorApplication.isPlayingOrWillChangePlaymode) return;
            if (now - state.window.phaseStartedMs < SettleMs) return;
            var compileFailed = EditorUtility.scriptCompilationFailed;
            Update(store, s =>
            {
                foreach (var job in WindowJobs(s).Where(j => !j.IsFinished))
                {
                    var why = job.doneRequested ? "closed by the holder" : "time box reached";
                    BrokerOps.Finish(job, BrokerConstants.JobPassed, "Exclusive window " + why + "; project refreshed" +
                                                                     (compileFailed ? " and scripts now have compile errors." : "."), null, now);
                }
                BrokerScheduler.EndWindow(s, Cfg, now);
                return true;
            });
        }
    }

    static class BrokerSceneSetup
    {
        [Serializable]
        sealed class Item
        {
            public string path = "";
            public bool isLoaded;
            public bool isActive;
        }

        [Serializable]
        sealed class Items
        {
            public List<Item> items = new List<Item>();
        }

        public static string Serialize(SceneSetup[] setup)
        {
            var list = new Items();
            foreach (var s in setup ?? new SceneSetup[0])
                if (!string.IsNullOrEmpty(s.path)) list.items.Add(new Item { path = s.path, isLoaded = s.isLoaded, isActive = s.isActive });
            return list.items.Count > 0 ? JsonUtility.ToJson(list) : "";
        }

        public static SceneSetup[] Deserialize(string json)
        {
            if (string.IsNullOrEmpty(json)) return new SceneSetup[0];
            var list = JsonUtility.FromJson<Items>(json);
            var setup = list.items.Where(i => File.Exists(i.path))
                .Select(i => new SceneSetup { path = i.path, isLoaded = i.isLoaded, isActive = i.isActive })
                .ToArray();
            // An untitled active scene cannot be restored; Unity needs one loaded active scene.
            if (setup.Length > 0 && !setup.Any(s => s.isActive))
            {
                setup[0].isActive = true;
                setup[0].isLoaded = true;
            }
            return setup;
        }
    }
}
