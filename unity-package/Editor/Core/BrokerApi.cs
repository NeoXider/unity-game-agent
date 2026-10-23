using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using UnityEngine;

namespace UnityGameAgent.EditorBroker
{
    [Serializable]
    public sealed class BrokerRequest
    {
        public string action = "";
        public string agent = "";
        public string resource = "";
        public string kind = BrokerConstants.KindCold;
        public int ttlSec;
        public string lane = "";
        public string jobKind = "";
        public string paths = "";
        public string tests = "";
        public string testMode = "";
        public string scene = "";
        public float minutes;
        public string reason = "";
        public string jobId = "";
    }

    // Entry point for the optional MCP / Unity CLI adapters. Same verbs and rules as
    // tools/editor-broker.ps1, which remains the channel that works while the Editor reloads.
    public static class BrokerApi
    {
        [Serializable]
        sealed class AsmdefName
        {
            public string name = "";
        }

        public static Func<string, string> AsmdefResolver(string projectRoot)
        {
            return name =>
            {
                foreach (var root in new[] { "Assets", "Packages" })
                {
                    var dir = Path.Combine(projectRoot, root);
                    if (!Directory.Exists(dir)) continue;
                    foreach (var file in Directory.GetFiles(dir, "*.asmdef", SearchOption.AllDirectories))
                    {
                        try
                        {
                            var parsed = JsonUtility.FromJson<AsmdefName>(File.ReadAllText(file));
                            if (parsed != null && string.Equals(parsed.name, name, StringComparison.Ordinal))
                                return file.Substring(projectRoot.Length).TrimStart('\\', '/').Replace('\\', '/');
                        }
                        catch (Exception)
                        {
                            // An unreadable asmdef cannot match; keep scanning.
                        }
                    }
                }
                return null;
            };
        }

        public static BrokerOpResult Execute(BrokerStore store, BrokerRequest r, out string board)
        {
            board = "";
            var cfg = BrokerConfig.Default;
            var action = (r.action ?? "").Trim().ToLowerInvariant();
            string type = "", path = "", parseError = "";
            if ((action == "take" || (action == "release" && !string.IsNullOrEmpty(r.resource))) &&
                !BrokerPaths.TryParse(r.resource, AsmdefResolver(store.ProjectRoot), out type, out path, out parseError))
                return BrokerOpResult.Of("error", parseError);

            BrokerOpResult result = null;
            BrokerState state;
            string error;
            var ok = store.TryUpdate(s =>
            {
                var now = BrokerClock.NowMs();
                switch (action)
                {
                    case "status":
                        result = BrokerOpResult.Of("ok", "Board attached.");
                        break;
                    case "take":
                        result = BrokerOps.Take(s, cfg, r.agent, string.IsNullOrEmpty(r.kind) ? BrokerConstants.KindCold : r.kind,
                            r.resource, path, r.ttlSec, now);
                        break;
                    case "release":
                        var released = BrokerOps.Release(s, r.agent, path);
                        result = BrokerOpResult.Of(released > 0 ? "released" : "none", released + " lease(s) or request(s) released.");
                        break;
                    case "renew":
                        var renewed = BrokerOps.Renew(s, cfg, r.agent, r.ttlSec, now);
                        result = BrokerOpResult.Of(renewed > 0 ? "renewed" : "none", renewed + " lease(s) or request(s) renewed.");
                        break;
                    case "yield":
                        var yielded = BrokerOps.Yield(s, r.agent, now);
                        result = BrokerOpResult.Of("yielded", yielded + " lease(s) marked safe for a window.");
                        break;
                    case "gate":
                        result = BrokerOps.Gate(s, r.agent, now);
                        break;
                    case "request":
                        var paths = (r.paths ?? "").Split(new[] { ';', ',' }, StringSplitOptions.RemoveEmptyEntries)
                            .Select(p => p.Trim()).Where(p => p.Length > 0).ToList();
                        var jobKind = string.IsNullOrEmpty(r.jobKind) ? DefaultKind(r.lane) : r.jobKind;
                        result = BrokerOps.Request(s, cfg, r.agent, r.lane, jobKind, paths, r.tests, r.testMode, r.scene,
                            r.minutes, r.reason, now);
                        break;
                    case "cancel":
                        result = BrokerOps.Cancel(s, r.agent, r.jobId, now);
                        break;
                    case "done":
                        result = BrokerOps.Done(s, r.agent, r.jobId);
                        break;
                    case "job":
                        var job = s.jobs.FirstOrDefault(j => j.id == r.jobId);
                        result = job == null
                            ? BrokerOpResult.Of("error", "Unknown job " + r.jobId + ".")
                            : new BrokerOpResult { status = job.status, jobId = job.id, message = job.summary };
                        break;
                    default:
                        result = BrokerOpResult.Of("error", "Unknown action '" + r.action +
                                                            "'. Use status, take, release, renew, yield, gate, request, cancel, done or job.");
                        return false;
                }
                if (action == "status" || action == "job") return false;
                BrokerOps.Promote(s, cfg, now);
                return result.status != "error";
            }, 2000, out state, out error);

            if (!ok) return BrokerOpResult.Of("error", error);
            board = BrokerBoard.Describe(state, store.ReadEditorStatus(), BrokerClock.NowMs());
            return result;
        }

        static string DefaultKind(string lane)
        {
            switch (lane)
            {
                case BrokerConstants.LaneSync: return BrokerConstants.JobSync;
                case BrokerConstants.LaneExclusive: return BrokerConstants.JobExclusive;
                default: return BrokerConstants.JobTests;
            }
        }
    }

    public static class BrokerBoard
    {
        public static string Describe(BrokerState state, BrokerEditorStatus editor, long now)
        {
            var text = new StringBuilder();
            text.AppendLine("Session: " + (state.SessionActive ? state.sessionId + " (owner " + state.sessionOwner + ")" : "none") +
                            (state.paused ? "  [PAUSED]" : ""));
            if (editor == null) text.AppendLine("Editor: no heartbeat yet");
            else
                text.AppendLine("Editor: " + editor.phase + ", heartbeat " + Age(now - editor.heartbeatMs) + " ago" +
                                (editor.compileFailed ? ", COMPILE ERRORS" : "") +
                                (editor.dirtyScenes.Count > 0 ? ", dirty: " + string.Join(", ", editor.dirtyScenes) : ""));
            if (state.HasWindow)
            {
                var w = state.window;
                var waiting = w.phase == BrokerConstants.PhaseDraining
                    ? " waiting for: " + string.Join(", ", BrokerScheduler.Unyielded(state, now)) +
                      " (deadline in " + Age(w.drainDeadlineMs - now) + ")"
                    : "";
                text.AppendLine("Window: " + w.id + " " + w.lane + "/" + w.phase + (w.holder.Length > 0 ? " holder " + w.holder : "") +
                                " jobs " + string.Join(",", w.jobIds) + waiting);
            }
            else text.AppendLine("Window: none");

            text.AppendLine("Leases:");
            foreach (var l in state.leases.OrderBy(l => l.grantedMs))
                text.AppendLine("  " + l.id + " " + l.agent + " " + l.kind + " " + l.path + " expires in " + Age(l.expiresMs - now) +
                                (l.yielded ? " yielded" : ""));
            if (state.leases.Count == 0) text.AppendLine("  (none)");
            if (state.waiting.Count > 0)
            {
                text.AppendLine("Waiting (FIFO):");
                foreach (var w in state.waiting) text.AppendLine("  " + w.id + " " + w.agent + " " + w.kind + " " + w.path);
            }
            text.AppendLine("Jobs:");
            var jobs = state.jobs.Where(j => !j.IsFinished).OrderBy(j => j.createdMs).ToList();
            foreach (var j in jobs)
                text.AppendLine("  " + j.id + " " + j.agent + " " + j.lane + "/" + j.kind + " " + j.status + " age " + Age(now - j.createdMs) + Label(j));
            if (jobs.Count == 0) text.AppendLine("  (none queued)");
            foreach (var j in state.jobs.Where(j => j.IsFinished).OrderByDescending(j => j.finishedMs).Take(5))
                text.AppendLine("  " + j.id + " " + j.agent + " " + j.lane + "/" + j.kind + " " + j.status + ": " + j.summary);
            if (state.violations.Count > 0)
            {
                text.AppendLine("Violations (latest):");
                foreach (var v in state.violations.Skip(Math.Max(0, state.violations.Count - 5)))
                    text.AppendLine("  " + v.kind + (v.agent.Length > 0 ? " [" + v.agent + "]" : "") + ": " + v.detail);
            }
            return text.ToString();
        }

        static string Label(BrokerJob job)
        {
            if (job.kind == BrokerConstants.JobTests) return " " + job.testMode + " " + job.tests;
            if (job.kind == BrokerConstants.JobSession) return " " + job.minutes + " min " + job.scene;
            if (job.kind == BrokerConstants.JobExclusive) return " " + job.reason;
            return "";
        }

        public static string Age(long ms)
        {
            if (ms < 0) ms = 0;
            if (ms < 1000) return ms + " ms";
            if (ms < 120000) return (ms / 1000) + " s";
            return (ms / 60000) + " min";
        }
    }
}
