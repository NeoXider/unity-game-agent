using System;
using System.Collections.Generic;
using System.Linq;

namespace UnityGameAgent.EditorBroker
{
    // Per-project numbers about how agents share the Editor: how long jobs and leases wait, how long
    // the queue gets and how long windows run. The Editor counts them in the state file; when the
    // session changes it closes the segment, and the host appends it to Library/UgaBroker/telemetry.jsonl.
    // Field names are the wire format read by tools/editor-broker.ps1 (stats).
    [Serializable]
    public sealed class BrokerTelemetry
    {
        public string sessionId = "";
        public long sinceMs;
        public long endedMs;

        public int jobs;
        public int failed;
        public int blocked;
        public int canceled;
        public long waitMs;
        public long waitMaxMs;
        public long runMs;

        public int windows;
        public long windowMs;
        public long windowMaxMs;
        public long drainMs;

        // Queued jobs and lease waiters, as time-weighted levels: integral / elapsed = average.
        public int queueLevel;
        public long queueSinceMs;
        public long queueIntegral;
        public int queuePeak;
        public int waitersLevel;
        public long waitersSinceMs;
        public long waitersIntegral;
        public int waitersPeak;

        public int leaseWaits;
        public long leaseWaitMs;
        public long leaseWaitMaxMs;

        public List<BrokerAgentStats> agents = new List<BrokerAgentStats>();
        public List<BrokerLaneStats> lanes = new List<BrokerLaneStats>();

        public bool HasData => jobs > 0 || windows > 0 || leaseWaits > 0 || queuePeak > 0 || waitersPeak > 0;

        public void Normalize()
        {
            if (sessionId == null) sessionId = "";
            if (agents == null) agents = new List<BrokerAgentStats>();
            if (lanes == null) lanes = new List<BrokerLaneStats>();
        }
    }

    [Serializable]
    public sealed class BrokerAgentStats
    {
        public string agent = "";
        public int jobs;
        public int failed;
        public int blocked;
        public long waitMs;
        public long waitMaxMs;
        public long runMs;
        public int leaseWaits;
        public long leaseWaitMs;
        public long leaseWaitMaxMs;
    }

    [Serializable]
    public sealed class BrokerLaneStats
    {
        public string lane = "";
        public int jobs;
        public long waitMs;
        public long waitMaxMs;
        public long runMs;
        public int windows;
        public long windowMs;
        public long drainMs;
    }

    public static class BrokerTelemetryOps
    {
        // Counts finished jobs and granted leases not counted yet and follows the queue levels.
        // Returns the closed segment when the session changed since the last call, otherwise null.
        public static BrokerTelemetry Record(BrokerState state, long now, out bool changed)
        {
            changed = false;
            BrokerTelemetry closed = null;
            var t = state.telemetry;
            if (!string.Equals(t.sessionId, state.sessionId ?? "", StringComparison.Ordinal))
            {
                CloseLevels(t, now);
                if (t.HasData)
                {
                    t.endedMs = now;
                    closed = t;
                }
                t = state.telemetry = new BrokerTelemetry { sessionId = state.sessionId ?? "" };
                changed = true;
            }
            if (t.sinceMs == 0)
            {
                t.sinceMs = t.queueSinceMs = t.waitersSinceMs = now;
                changed = true;
            }

            foreach (var job in state.jobs.Where(j => j.IsFinished && !j.counted))
            {
                job.counted = true;
                AddJob(t, job);
                changed = true;
            }
            foreach (var lease in state.leases.Where(l => !l.counted))
            {
                lease.counted = true;
                changed = true;
                if (lease.waitedMs <= 0) continue;
                t.leaseWaits++;
                t.leaseWaitMs += lease.waitedMs;
                t.leaseWaitMaxMs = Math.Max(t.leaseWaitMaxMs, lease.waitedMs);
                var a = Agent(t, lease.agent);
                a.leaseWaits++;
                a.leaseWaitMs += lease.waitedMs;
                a.leaseWaitMaxMs = Math.Max(a.leaseWaitMaxMs, lease.waitedMs);
            }

            var queued = state.jobs.Count(j => j.status == BrokerConstants.JobQueued);
            if (queued != t.queueLevel)
            {
                t.queueIntegral += t.queueLevel * Math.Max(0, now - t.queueSinceMs);
                t.queueLevel = queued;
                t.queueSinceMs = now;
                t.queuePeak = Math.Max(t.queuePeak, queued);
                changed = true;
            }
            var waiters = state.waiting.Count;
            if (waiters != t.waitersLevel)
            {
                t.waitersIntegral += t.waitersLevel * Math.Max(0, now - t.waitersSinceMs);
                t.waitersLevel = waiters;
                t.waitersSinceMs = now;
                t.waitersPeak = Math.Max(t.waitersPeak, waiters);
                changed = true;
            }
            return closed;
        }

        // Called when a window ends: its drain (requested to started) and run (started to now).
        public static void RecordWindow(BrokerState state, long now)
        {
            var w = state.window;
            if (w == null || string.IsNullOrEmpty(w.id)) return;
            var t = state.telemetry;
            var drain = Math.Max(0, (w.startedMs > 0 ? w.startedMs : now) - w.requestedMs);
            var run = w.startedMs > 0 ? Math.Max(0, now - w.startedMs) : 0;
            t.windows++;
            t.windowMs += run;
            t.windowMaxMs = Math.Max(t.windowMaxMs, run);
            t.drainMs += drain;
            var lane = Lane(t, w.lane);
            lane.windows++;
            lane.windowMs += run;
            lane.drainMs += drain;
        }

        // Average queued jobs and lease waiters over the segment, including the current level.
        public static double AverageQueue(BrokerTelemetry t, long now)
        {
            return Average(t.queueIntegral, t.queueLevel, t.queueSinceMs, t.sinceMs, t.endedMs > 0 ? t.endedMs : now);
        }

        public static double AverageWaiters(BrokerTelemetry t, long now)
        {
            return Average(t.waitersIntegral, t.waitersLevel, t.waitersSinceMs, t.sinceMs, t.endedMs > 0 ? t.endedMs : now);
        }

        static double Average(long integral, int level, long levelSince, long since, long until)
        {
            var span = until - since;
            if (span <= 0) return 0;
            return (integral + (double)level * Math.Max(0, until - levelSince)) / span;
        }

        static void CloseLevels(BrokerTelemetry t, long now)
        {
            if (t.sinceMs == 0) return;
            t.queueIntegral += t.queueLevel * Math.Max(0, now - t.queueSinceMs);
            t.queueSinceMs = now;
            t.waitersIntegral += t.waitersLevel * Math.Max(0, now - t.waitersSinceMs);
            t.waitersSinceMs = now;
        }

        static void AddJob(BrokerTelemetry t, BrokerJob job)
        {
            // A job canceled before its window started waited until it was canceled.
            var started = job.startedMs > 0 ? job.startedMs : job.finishedMs;
            var wait = Math.Max(0, started - job.createdMs);
            var run = job.startedMs > 0 ? Math.Max(0, job.finishedMs - job.startedMs) : 0;
            t.jobs++;
            t.waitMs += wait;
            t.waitMaxMs = Math.Max(t.waitMaxMs, wait);
            t.runMs += run;
            if (job.status == BrokerConstants.JobFailed) t.failed++;
            else if (job.status == BrokerConstants.JobBlocked) t.blocked++;
            else if (job.status == BrokerConstants.JobCanceled) t.canceled++;

            var a = Agent(t, job.agent);
            a.jobs++;
            a.waitMs += wait;
            a.waitMaxMs = Math.Max(a.waitMaxMs, wait);
            a.runMs += run;
            if (job.status == BrokerConstants.JobFailed) a.failed++;
            else if (job.status == BrokerConstants.JobBlocked) a.blocked++;

            var lane = Lane(t, job.lane);
            lane.jobs++;
            lane.waitMs += wait;
            lane.waitMaxMs = Math.Max(lane.waitMaxMs, wait);
            lane.runMs += run;
        }

        static BrokerAgentStats Agent(BrokerTelemetry t, string agent)
        {
            var name = agent ?? "";
            var stats = t.agents.FirstOrDefault(a => string.Equals(a.agent, name, StringComparison.OrdinalIgnoreCase));
            if (stats != null) return stats;
            stats = new BrokerAgentStats { agent = name };
            t.agents.Add(stats);
            return stats;
        }

        static BrokerLaneStats Lane(BrokerTelemetry t, string lane)
        {
            var name = lane ?? "";
            var stats = t.lanes.FirstOrDefault(l => l.lane == name);
            if (stats != null) return stats;
            stats = new BrokerLaneStats { lane = name };
            t.lanes.Add(stats);
            return stats;
        }
    }
}
