using System.Collections.Generic;
using System.Linq;

namespace UnityGameAgent.EditorBroker
{
    public sealed class BrokerFacts
    {
        public bool isCompiling;
        public bool isUpdating;
        public bool isPlaying;
        public bool compileFailed;
        public long hotBlockedUntilMs;
        // Set by the board's "Run next window now": treat every lease as yielded for one decision.
        public bool forceDue;
    }

    public sealed class BrokerDecision
    {
        public string lane = "";
        public List<string> jobIds = new List<string>();
        public string reason = "";

        public bool OpensWindow => lane.Length > 0;

        public static BrokerDecision None(string reason)
        {
            return new BrokerDecision { reason = reason };
        }
    }

    // Decides which window opens next. Order of operations: cold work always wins while agents are
    // busy; a sync window (import + compile) batches every staged change; a hot window batches tests
    // and Play Mode sessions and runs last; an exclusive window gives one agent the whole Editor.
    public static class BrokerScheduler
    {
        public static BrokerDecision Decide(BrokerState state, BrokerFacts facts, BrokerConfig cfg, long now)
        {
            if (state.paused) return BrokerDecision.None("Broker paused.");
            if (state.HasWindow) return BrokerDecision.None("Window " + state.window.id + " is active.");
            if (facts.isCompiling || facts.isUpdating) return BrokerDecision.None("Editor is compiling or importing.");
            if (facts.isPlaying) return BrokerDecision.None("Play Mode was entered outside a broker window.");

            var active = BrokerOps.Active(state, now);
            var allYielded = facts.forceDue || active.All(l => l.yielded);
            var coldQuiet = facts.forceDue || (allYielded && state.waiting.Count == 0);

            var queued = state.jobs.Where(j => j.status == BrokerConstants.JobQueued).OrderBy(j => j.createdMs).ToList();
            var sync = queued.Where(j => j.lane == BrokerConstants.LaneSync).ToList();
            var hot = queued.Where(j => j.lane == BrokerConstants.LaneHot).ToList();
            var exclusive = queued.Where(j => j.lane == BrokerConstants.LaneExclusive).ToList();

            var hotDue = hot.Count > 0 && now >= facts.hotBlockedUntilMs &&
                         (coldQuiet || now - hot[0].createdMs >= cfg.hotMaxWaitMs || hot.Count >= cfg.hotBatchSize);
            var syncDue = sync.Count > 0 &&
                          (now - sync[0].createdMs >= cfg.syncMaxWaitMs || allYielded || hotDue);
            var exclusiveDue = exclusive.Count > 0 &&
                               (now - exclusive[0].createdMs >= cfg.exclusiveMaxWaitMs || allYielded);

            if (syncDue)
                return new BrokerDecision { lane = BrokerConstants.LaneSync, jobIds = sync.Select(j => j.id).ToList(), reason = "Staged changes are due." };
            if (exclusiveDue)
                return new BrokerDecision { lane = BrokerConstants.LaneExclusive, jobIds = new List<string> { exclusive[0].id }, reason = "Exclusive request is due." };
            if (hotDue)
            {
                if (facts.compileFailed) return BrokerDecision.None("Hot work waits: scripts have compile errors.");
                var ordered = hot.Where(j => j.kind == BrokerConstants.JobTests)
                    .Concat(hot.Where(j => j.kind != BrokerConstants.JobTests))
                    .Select(j => j.id)
                    .ToList();
                return new BrokerDecision { lane = BrokerConstants.LaneHot, jobIds = ordered, reason = "Hot batch is due." };
            }

            if (hot.Count > 0 && now < facts.hotBlockedUntilMs) return BrokerDecision.None("Hot work is cooling down after a blocked window.");
            if (queued.Count > 0) return BrokerDecision.None("Queued work waits for agents to yield or for its maximum wait.");
            return BrokerDecision.None("Nothing queued.");
        }

        public static void BeginWindow(BrokerState state, BrokerDecision decision, BrokerConfig cfg, long now)
        {
            var window = state.window;
            window.Clear();
            window.id = state.NewId("W");
            window.lane = decision.lane;
            window.phase = BrokerConstants.PhaseDraining;
            window.requestedMs = now;
            window.phaseStartedMs = now;
            window.drainDeadlineMs = now + cfg.drainTimeoutMs;
            window.jobIds = new List<string>(decision.jobIds);
            if (decision.lane == BrokerConstants.LaneExclusive)
            {
                var job = state.jobs.FirstOrDefault(j => j.id == decision.jobIds[0]);
                window.holder = job != null ? job.agent : "";
            }
            foreach (var job in state.jobs.Where(j => decision.jobIds.Contains(j.id))) job.windowId = window.id;
        }

        // Agents (other than the window holder) whose active leases have not yielded yet.
        public static List<string> Unyielded(BrokerState state, long now)
        {
            return BrokerOps.Active(state, now)
                .Where(l => !l.yielded && !BrokerOps.SameAgent(l.agent, state.window.holder))
                .Select(l => l.agent)
                .Distinct()
                .ToList();
        }

        public static bool DrainComplete(BrokerState state, long now)
        {
            return Unyielded(state, now).Count == 0 || now >= state.window.drainDeadlineMs;
        }

        public static void SetPhase(BrokerState state, string phase, long now)
        {
            state.window.phase = phase;
            state.window.phaseStartedMs = now;
        }

        public static void EndWindow(BrokerState state, BrokerConfig cfg, long now)
        {
            var windowId = state.window.id;
            BrokerTelemetryOps.RecordWindow(state, now);
            foreach (var job in state.jobs.Where(j => j.windowId == windowId && j.status == BrokerConstants.JobQueued))
                job.windowId = "";
            state.window.Clear();
            BrokerOps.TrimFinished(state, cfg);
        }
    }
}
