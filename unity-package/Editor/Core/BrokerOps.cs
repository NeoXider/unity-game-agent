using System;
using System.Collections.Generic;
using System.Linq;

namespace UnityGameAgent.EditorBroker
{
    // Pure lease and job operations. tools/editor-broker.ps1 implements the same rules; the shared
    // cases in Tests/Editor/broker-vectors.json keep the two implementations identical.
    public static class BrokerOps
    {
        public static bool SameAgent(string a, string b)
        {
            return string.Equals(a ?? "", b ?? "", StringComparison.OrdinalIgnoreCase);
        }

        public static List<BrokerLease> Active(BrokerState state, long now)
        {
            return state.leases.Where(l => l.expiresMs > now).ToList();
        }

        public static int Expire(BrokerState state, long now)
        {
            return state.leases.RemoveAll(l => l.expiresMs <= now) + state.waiting.RemoveAll(w => w.expiresMs <= now);
        }

        static bool Conflicts(string agentA, string kindA, string pathA, string agentB, string kindB, string pathB)
        {
            if (SameAgent(agentA, agentB)) return false;
            if (kindA == BrokerConstants.KindFocus && kindB == BrokerConstants.KindFocus) return true;
            return BrokerPaths.Overlaps(pathA, pathB);
        }

        static long FocusExpiry(BrokerState state, BrokerConfig cfg, string agent, long grantedMs, long ttlMs, long now)
        {
            var othersWaiting = state.waiting.Any(w => w.kind == BrokerConstants.KindFocus && !SameAgent(w.agent, agent));
            return othersWaiting
                ? Math.Min(now + ttlMs, grantedMs + cfg.focusMaxHoldMs)
                : now + Math.Min(ttlMs, cfg.focusMaxHoldMs);
        }

        static int ClampTtl(BrokerConfig cfg, int ttlSec)
        {
            if (ttlSec <= 0) ttlSec = cfg.defaultTtlSec;
            return Math.Max(10, Math.Min(cfg.maxTtlSec, ttlSec));
        }

        public static bool HoldsCover(BrokerState state, string agent, string path, long now)
        {
            return state.leases.Any(l => l.expiresMs > now && l.kind == BrokerConstants.KindCold &&
                                         SameAgent(l.agent, agent) && BrokerPaths.Covers(l.path, path));
        }

        public static BrokerOpResult Take(BrokerState state, BrokerConfig cfg, string agent, string kind,
            string resource, string path, int ttlSec, long now)
        {
            if (!BrokerPaths.IsValidAgent(agent)) return BrokerOpResult.Of("error", "Invalid agent name.");
            if (kind != BrokerConstants.KindCold && kind != BrokerConstants.KindFocus)
                return BrokerOpResult.Of("error", "Kind must be cold or focus.");
            if (string.IsNullOrEmpty(path)) return BrokerOpResult.Of("error", "Resource path is empty.");
            Expire(state, now);
            var ttlMs = ClampTtl(cfg, ttlSec) * 1000L;
            if (kind == BrokerConstants.KindFocus)
            {
                if (!path.EndsWith(".unity", StringComparison.OrdinalIgnoreCase))
                    return BrokerOpResult.Of("error", "Focus is granted for a scene resource only.");
                if (!HoldsCover(state, agent, path, now))
                    return BrokerOpResult.Of("error", "Take a cold lease on the scene before asking for focus.");
            }

            var own = state.leases.FirstOrDefault(l => SameAgent(l.agent, agent) && l.kind == kind &&
                                                        string.Equals(l.path, path, StringComparison.OrdinalIgnoreCase));
            if (own != null)
            {
                own.expiresMs = kind == BrokerConstants.KindFocus
                    ? FocusExpiry(state, cfg, agent, own.grantedMs, ttlMs, now)
                    : now + ttlMs;
                return new BrokerOpResult { status = "renewed", leaseId = own.id, message = "Lease renewed." };
            }

            var ownWaiterIndex = state.waiting.FindIndex(w => SameAgent(w.agent, agent) && w.kind == kind &&
                                                              string.Equals(w.path, path, StringComparison.OrdinalIgnoreCase));
            var earlierWaiters = ownWaiterIndex < 0 ? state.waiting.Count : ownWaiterIndex;
            var blockers = state.leases
                .Where(l => l.expiresMs > now && Conflicts(agent, kind, path, l.agent, l.kind, l.path))
                .Select(l => l.agent)
                .Concat(state.waiting.Take(earlierWaiters)
                    .Where(w => Conflicts(agent, kind, path, w.agent, w.kind, w.path))
                    .Select(w => w.agent + " (queued)"))
                .Distinct()
                .ToList();

            if (blockers.Count == 0)
            {
                var waitedMs = 0L;
                if (ownWaiterIndex >= 0)
                {
                    waitedMs = Math.Max(0, now - state.waiting[ownWaiterIndex].requestedMs);
                    state.waiting.RemoveAt(ownWaiterIndex);
                }
                var lease = Grant(state, cfg, agent, kind, resource, path, ttlMs, now);
                lease.waitedMs = waitedMs;
                return new BrokerOpResult { status = "granted", leaseId = lease.id, message = "Lease granted." };
            }

            if (ownWaiterIndex >= 0)
            {
                var existing = state.waiting[ownWaiterIndex];
                existing.expiresMs = now + cfg.waiterTtlMs;
                existing.ttlSec = (int)(ttlMs / 1000);
                return new BrokerOpResult
                {
                    status = "queued", leaseId = existing.id, position = ownWaiterIndex + 1,
                    message = "Waiting behind " + string.Join(", ", blockers) + "."
                };
            }

            var waiter = new BrokerWaiter
            {
                id = state.NewId("Q"), agent = agent, kind = kind, resource = resource, path = path,
                requestedMs = now, expiresMs = now + cfg.waiterTtlMs, ttlSec = (int)(ttlMs / 1000)
            };
            state.waiting.Add(waiter);
            return new BrokerOpResult
            {
                status = "queued", leaseId = waiter.id, position = state.waiting.Count,
                message = "Waiting behind " + string.Join(", ", blockers) + "."
            };
        }

        static BrokerLease Grant(BrokerState state, BrokerConfig cfg, string agent, string kind, string resource,
            string path, long ttlMs, long now)
        {
            var lease = new BrokerLease
            {
                id = state.NewId("L"), agent = agent, kind = kind, resource = resource, path = path, grantedMs = now
            };
            lease.expiresMs = kind == BrokerConstants.KindFocus
                ? FocusExpiry(state, cfg, agent, now, ttlMs, now)
                : now + ttlMs;
            state.leases.Add(lease);
            return lease;
        }

        // Grants waiting requests in FIFO order: an entry is granted only when it conflicts with no
        // active lease and with no earlier entry that is still waiting.
        public static List<BrokerLease> Promote(BrokerState state, BrokerConfig cfg, long now)
        {
            Expire(state, now);
            var granted = new List<BrokerLease>();
            var i = 0;
            while (i < state.waiting.Count)
            {
                var w = state.waiting[i];
                if (w.kind == BrokerConstants.KindFocus && !HoldsCover(state, w.agent, w.path, now))
                {
                    state.waiting.RemoveAt(i);
                    continue;
                }
                var blocked = state.leases.Any(l => l.expiresMs > now && Conflicts(w.agent, w.kind, w.path, l.agent, l.kind, l.path)) ||
                              state.waiting.Take(i).Any(e => Conflicts(w.agent, w.kind, w.path, e.agent, e.kind, e.path));
                if (blocked)
                {
                    i++;
                    continue;
                }
                state.waiting.RemoveAt(i);
                var lease = Grant(state, cfg, w.agent, w.kind, w.resource, w.path, Math.Max(10, w.ttlSec) * 1000L, now);
                lease.waitedMs = Math.Max(0, now - w.requestedMs);
                granted.Add(lease);
            }
            return granted;
        }

        public static int Release(BrokerState state, string agent, string path)
        {
            bool Match(string agentName, string leasePath) =>
                SameAgent(agentName, agent) &&
                (string.IsNullOrEmpty(path) || string.Equals(leasePath, path, StringComparison.OrdinalIgnoreCase));
            return state.leases.RemoveAll(l => Match(l.agent, l.path)) + state.waiting.RemoveAll(w => Match(w.agent, w.path));
        }

        public static int Renew(BrokerState state, BrokerConfig cfg, string agent, int ttlSec, long now)
        {
            Expire(state, now);
            var ttlMs = ClampTtl(cfg, ttlSec) * 1000L;
            var count = 0;
            foreach (var lease in state.leases.Where(l => SameAgent(l.agent, agent)))
            {
                lease.expiresMs = lease.kind == BrokerConstants.KindFocus
                    ? FocusExpiry(state, cfg, agent, lease.grantedMs, ttlMs, now)
                    : now + ttlMs;
                count++;
            }
            foreach (var waiter in state.waiting.Where(w => SameAgent(w.agent, agent)))
            {
                waiter.expiresMs = now + cfg.waiterTtlMs;
                count++;
            }
            return count;
        }

        public static int Yield(BrokerState state, string agent, long now)
        {
            var count = 0;
            foreach (var lease in state.leases.Where(l => l.expiresMs > now && SameAgent(l.agent, agent)))
            {
                lease.yielded = true;
                count++;
            }
            return count;
        }

        // "go": the agent may touch the Editor now (its leases stop counting as yielded).
        // "wait": a window is draining or running; the agent's leases count as yielded.
        public static BrokerOpResult Gate(BrokerState state, string agent, long now)
        {
            Expire(state, now);
            var mine = state.leases.Where(l => SameAgent(l.agent, agent)).ToList();
            if (state.HasWindow && !SameAgent(state.window.holder, agent))
            {
                foreach (var lease in mine) lease.yielded = true;
                return BrokerOpResult.Of("wait", "Window " + state.window.id + " (" + state.window.lane + ", " +
                                                 state.window.phase + ") owns the Editor. Retry after it ends.");
            }
            foreach (var lease in mine) lease.yielded = false;
            return BrokerOpResult.Of("go", "The Editor is free for your leased resources.");
        }

        public static BrokerOpResult Request(BrokerState state, BrokerConfig cfg, string agent, string lane, string kind,
            IList<string> paths, string tests, string testMode, string scene, float minutes, string reason, long now)
        {
            if (!BrokerPaths.IsValidAgent(agent)) return BrokerOpResult.Of("error", "Invalid agent name.");
            Expire(state, now);
            var normalizedPaths = new List<string>();
            var job = new BrokerJob { agent = agent, lane = lane, kind = kind, createdMs = now };
            switch (lane + "/" + kind)
            {
                case "sync/sync":
                    foreach (var raw in paths ?? new List<string>())
                    {
                        var p = BrokerPaths.NormalizePath(raw, false);
                        if (p == null) return BrokerOpResult.Of("error", "Invalid import path: " + raw);
                        if (!HoldsCover(state, agent, p, now))
                            return BrokerOpResult.Of("error", "Import path is not under your lease: " + p);
                        normalizedPaths.Add(p);
                    }
                    break;
                case "hot/tests":
                    if (string.IsNullOrWhiteSpace(tests)) return BrokerOpResult.Of("error", "A test request needs -Tests.");
                    string filterError;
                    if (BrokerTestFilter.Parse(tests, out filterError) == null) return BrokerOpResult.Of("error", filterError);
                    job.tests = tests.Trim();
                    job.testMode = string.IsNullOrEmpty(testMode) ? "PlayMode" : testMode;
                    if (job.testMode != "PlayMode" && job.testMode != "EditMode")
                        return BrokerOpResult.Of("error", "Test mode must be PlayMode or EditMode.");
                    break;
                case "hot/session":
                case "hot/smoke":
                    job.minutes = minutes > 0 ? minutes : (kind == BrokerConstants.JobSmoke ? 0.05f : cfg.sessionDefaultMinutes);
                    job.minutes = Math.Max(0.05f, Math.Min(30f, job.minutes));
                    if (!string.IsNullOrWhiteSpace(scene))
                    {
                        var s = BrokerPaths.NormalizePath(scene, false);
                        if (s == null || !s.EndsWith(".unity", StringComparison.OrdinalIgnoreCase))
                            return BrokerOpResult.Of("error", "Session scene must be an Assets/ or Packages/ .unity path.");
                        job.scene = s;
                    }
                    job.reason = reason ?? "";
                    break;
                case "exclusive/exclusive":
                    if (string.IsNullOrWhiteSpace(reason)) return BrokerOpResult.Of("error", "An exclusive request needs -Reason.");
                    job.reason = reason.Trim();
                    job.minutes = minutes > 0 ? minutes : cfg.exclusiveDefaultMinutes;
                    job.minutes = Math.Max(1f, Math.Min(60f, job.minutes));
                    break;
                default:
                    return BrokerOpResult.Of("error", "Unknown lane/kind: " + lane + "/" + kind);
            }
            job.paths = normalizedPaths;

            var duplicate = state.jobs.FirstOrDefault(j => j.status == BrokerConstants.JobQueued && SameAgent(j.agent, agent) &&
                                                           j.lane == job.lane && j.kind == job.kind && j.tests == job.tests &&
                                                           j.scene == job.scene && j.testMode == job.testMode &&
                                                           j.paths.SequenceEqual(job.paths, StringComparer.OrdinalIgnoreCase));
            if (duplicate != null)
            {
                return new BrokerOpResult { status = "exists", jobId = duplicate.id, message = "Same request is already queued." };
            }
            job.id = state.NewId("J");
            state.jobs.Add(job);
            return new BrokerOpResult { status = "queued", jobId = job.id, message = "Request queued." };
        }

        public static BrokerOpResult Cancel(BrokerState state, string agent, string jobId, long now)
        {
            var job = state.jobs.FirstOrDefault(j => j.id == jobId);
            if (job == null) return BrokerOpResult.Of("error", "Unknown job " + jobId + ".");
            if (!SameAgent(job.agent, agent)) return BrokerOpResult.Of("error", "Job " + jobId + " belongs to " + job.agent + ".");
            if (job.status != BrokerConstants.JobQueued) return BrokerOpResult.Of("error", "Only a queued job can be canceled.");
            Finish(job, BrokerConstants.JobCanceled, "Canceled by " + agent + ".", null, now);
            return new BrokerOpResult { status = "canceled", jobId = jobId, message = "Job canceled." };
        }

        public static BrokerOpResult Done(BrokerState state, string agent, string jobId)
        {
            var job = state.jobs.FirstOrDefault(j => j.id == jobId);
            if (job == null) return BrokerOpResult.Of("error", "Unknown job " + jobId + ".");
            if (!SameAgent(job.agent, agent)) return BrokerOpResult.Of("error", "Job " + jobId + " belongs to " + job.agent + ".");
            if (job.kind != BrokerConstants.JobSession && job.kind != BrokerConstants.JobExclusive)
                return BrokerOpResult.Of("error", "Only a Play Mode session or an exclusive window can be finished early.");
            if (job.IsFinished) return BrokerOpResult.Of("error", "Job " + jobId + " already finished.");
            job.doneRequested = true;
            return new BrokerOpResult { status = "done-requested", jobId = jobId, message = "The broker will close it on its next tick." };
        }

        public static void Finish(BrokerJob job, string status, string summary, IEnumerable<string> details, long now)
        {
            job.status = status;
            job.summary = summary ?? "";
            job.finishedMs = now;
            job.details = details != null ? details.Take(40).ToList() : new List<string>();
        }

        public static void TrimFinished(BrokerState state, BrokerConfig cfg)
        {
            var finished = state.jobs.Where(j => j.IsFinished).OrderByDescending(j => j.finishedMs).ToList();
            foreach (var stale in finished.Skip(cfg.maxFinishedJobs)) state.jobs.Remove(stale);
        }

        public static void AddViolation(BrokerState state, BrokerConfig cfg, string agent, string kind, string detail, long now)
        {
            state.violations.Add(new BrokerViolation { atMs = now, agent = agent ?? "", kind = kind, detail = detail });
            if (state.violations.Count > cfg.maxViolations)
                state.violations.RemoveRange(0, state.violations.Count - cfg.maxViolations);
        }

        // Owner of a project path: the agent holding a cold lease that covers it, or "".
        public static string OwnerOf(BrokerState state, string assetPath, long now)
        {
            var lease = state.leases.FirstOrDefault(l => l.expiresMs > now && l.kind == BrokerConstants.KindCold &&
                                                         BrokerPaths.Covers(l.path, assetPath));
            return lease != null ? lease.agent : "";
        }
    }
}
