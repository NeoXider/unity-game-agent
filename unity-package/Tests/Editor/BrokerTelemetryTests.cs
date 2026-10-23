using System.Linq;
using NUnit.Framework;

namespace UnityGameAgent.EditorBroker.Tests
{
    public class BrokerTelemetryTests
    {
        static BrokerState NewState(string session = "S1")
        {
            var state = new BrokerState { sessionId = session };
            state.Normalize();
            return state;
        }

        static BrokerJob Job(BrokerState s, string agent, string lane, long created, long started, long finished, string status)
        {
            var job = new BrokerJob { id = s.NewId("J"), agent = agent, lane = lane, kind = lane, createdMs = created,
                startedMs = started, finishedMs = finished, status = status };
            s.jobs.Add(job);
            return job;
        }

        [Test]
        public void FinishedJobsAreCountedOncePerAgentAndLane()
        {
            var s = NewState();
            bool changed;
            BrokerTelemetryOps.Record(s, 1000, out changed);
            Job(s, "a", "sync", 1000, 4000, 9000, BrokerConstants.JobPassed);    // waited 3 s, ran 5 s
            Job(s, "a", "hot", 2000, 12000, 20000, BrokerConstants.JobFailed);   // waited 10 s
            Job(s, "b", "sync", 3000, 0, 0, BrokerConstants.JobQueued);          // not finished yet
            BrokerTelemetryOps.Record(s, 21000, out changed);
            BrokerTelemetryOps.Record(s, 22000, out changed);

            var t = s.telemetry;
            Assert.AreEqual(2, t.jobs);
            Assert.AreEqual(1, t.failed);
            Assert.AreEqual(13000, t.waitMs);
            Assert.AreEqual(10000, t.waitMaxMs);
            var a = t.agents.Single(x => x.agent == "a");
            Assert.AreEqual(2, a.jobs);
            Assert.AreEqual(10000, a.waitMaxMs);
            Assert.AreEqual(13000, a.runMs);
            Assert.AreEqual(1, t.lanes.Single(l => l.lane == "hot").jobs);
        }

        [Test]
        public void QueueAverageIsWeightedByTime()
        {
            var s = NewState();
            bool changed;
            BrokerTelemetryOps.Record(s, 0, out changed);
            s.telemetry.sinceMs = s.telemetry.queueSinceMs = s.telemetry.waitersSinceMs = 1;
            Job(s, "a", "sync", 1, 0, 0, BrokerConstants.JobQueued);
            Job(s, "b", "sync", 1, 0, 0, BrokerConstants.JobQueued);
            BrokerTelemetryOps.Record(s, 1, out changed);       // 2 queued from t=1
            s.jobs.RemoveAt(1);
            BrokerTelemetryOps.Record(s, 5001, out changed);    // 1 queued from t=5001
            s.jobs.Clear();
            BrokerTelemetryOps.Record(s, 10001, out changed);   // 0 queued from t=10001
            Assert.AreEqual(2, s.telemetry.queuePeak);
            // (2 * 5000 + 1 * 5000 + 0 * 10000) / 20000 = 0.75
            Assert.AreEqual(0.75, BrokerTelemetryOps.AverageQueue(s.telemetry, 20001), 1e-9);
        }

        [Test]
        public void LeaseWaitsComeFromPromotedWaiters()
        {
            var s = NewState();
            var cfg = BrokerConfig.Default;
            bool changed;
            BrokerOps.Take(s, cfg, "a", BrokerConstants.KindCold, "folder:Assets/UI/", "Assets/UI/", 600, 1000);
            var queued = BrokerOps.Take(s, cfg, "b", BrokerConstants.KindCold, "asset:Assets/UI/Menu.prefab", "Assets/UI/Menu.prefab", 600, 2000);
            Assert.AreEqual("queued", queued.status);
            BrokerTelemetryOps.Record(s, 2000, out changed);
            Assert.AreEqual(1, s.telemetry.waitersPeak);
            BrokerOps.Release(s, "a", "");
            var granted = BrokerOps.Promote(s, cfg, 9000);
            Assert.AreEqual(1, granted.Count);
            Assert.AreEqual(7000, granted[0].waitedMs);
            BrokerTelemetryOps.Record(s, 9000, out changed);
            Assert.AreEqual(1, s.telemetry.leaseWaits);
            Assert.AreEqual(7000, s.telemetry.agents.Single(x => x.agent == "b").leaseWaitMaxMs);
        }

        [Test]
        public void WindowsRecordDrainAndRun()
        {
            var s = NewState();
            bool changed;
            BrokerTelemetryOps.Record(s, 0, out changed);
            s.window.id = "W1";
            s.window.lane = BrokerConstants.LaneSync;
            s.window.requestedMs = 1000;
            s.window.startedMs = 4000;
            BrokerScheduler.EndWindow(s, BrokerConfig.Default, 10000);
            Assert.AreEqual(1, s.telemetry.windows);
            Assert.AreEqual(3000, s.telemetry.drainMs);
            Assert.AreEqual(6000, s.telemetry.windowMs);
            Assert.AreEqual(1, s.telemetry.lanes.Single(l => l.lane == "sync").windows);
        }

        [Test]
        public void SessionChangeClosesTheSegment()
        {
            var s = NewState("S1");
            bool changed;
            BrokerTelemetryOps.Record(s, 1000, out changed);
            Job(s, "a", "sync", 1000, 2000, 3000, BrokerConstants.JobPassed);
            Assert.IsNull(BrokerTelemetryOps.Record(s, 4000, out changed));
            s.sessionId = "";
            var closed = BrokerTelemetryOps.Record(s, 5000, out changed);
            Assert.IsNotNull(closed);
            Assert.AreEqual("S1", closed.sessionId);
            Assert.AreEqual(5000, closed.endedMs);
            Assert.AreEqual(1, closed.jobs);
            Assert.AreEqual("", s.telemetry.sessionId);
            Assert.AreEqual(0, s.telemetry.jobs);
        }
    }
}
