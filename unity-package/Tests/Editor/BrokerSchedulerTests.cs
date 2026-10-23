using System.Collections.Generic;
using System.IO;
using NUnit.Framework;

namespace UnityGameAgent.EditorBroker.Tests
{
    public sealed class BrokerSchedulerTests
    {
        static readonly BrokerConfig Cfg = new BrokerConfig();

        static BrokerState WithLease(string agent, bool yielded)
        {
            var state = new BrokerState();
            state.leases.Add(new BrokerLease { id = "L1", agent = agent, kind = "cold", path = "Assets/A/", grantedMs = 0, expiresMs = 10000000, yielded = yielded });
            return state;
        }

        static BrokerJob Job(BrokerState state, string id, string lane, string kind, long createdMs, string agent = "dev")
        {
            var job = new BrokerJob { id = id, agent = agent, lane = lane, kind = kind, createdMs = createdMs };
            state.jobs.Add(job);
            return job;
        }

        [Test]
        public void SyncWaitsForBusyAgentsUntilItsMaximumWait()
        {
            var state = WithLease("art", false);
            Job(state, "J1", "sync", "sync", 0);
            Assert.IsFalse(BrokerScheduler.Decide(state, new BrokerFacts(), Cfg, 1000).OpensWindow);
            var due = BrokerScheduler.Decide(state, new BrokerFacts(), Cfg, Cfg.syncMaxWaitMs);
            Assert.AreEqual("sync", due.lane);
            CollectionAssert.AreEqual(new[] { "J1" }, due.jobIds);
        }

        [Test]
        public void SyncStartsAtOnceWhenEveryLeaseYielded()
        {
            var state = WithLease("art", true);
            Job(state, "J1", "sync", "sync", 0);
            Assert.AreEqual("sync", BrokerScheduler.Decide(state, new BrokerFacts(), Cfg, 10).lane);
        }

        [Test]
        public void HotWaitsWhileColdWorkIsActiveThenBatches()
        {
            var state = WithLease("art", false);
            Job(state, "J1", "hot", "tests", 0);
            Job(state, "J2", "hot", "session", 10);
            Assert.IsFalse(BrokerScheduler.Decide(state, new BrokerFacts(), Cfg, 1000).OpensWindow, "cold work wins");
            Job(state, "J3", "hot", "tests", 20);
            var batch = BrokerScheduler.Decide(state, new BrokerFacts(), Cfg, 1000);
            Assert.AreEqual("hot", batch.lane, "batch size reached");
            CollectionAssert.AreEqual(new[] { "J1", "J3", "J2" }, batch.jobIds, "tests run before sessions");
        }

        [Test]
        public void HotRunsAfterItsMaximumWaitEvenWhileAgentsWork()
        {
            var state = WithLease("art", false);
            Job(state, "J1", "hot", "tests", 0);
            Assert.AreEqual("hot", BrokerScheduler.Decide(state, new BrokerFacts(), Cfg, Cfg.hotMaxWaitMs).lane);
        }

        [Test]
        public void SyncRunsBeforeHotAndCompileErrorsBlockHot()
        {
            var state = WithLease("art", true);
            Job(state, "J1", "hot", "tests", 0);
            Job(state, "J2", "sync", "sync", 5);
            Assert.AreEqual("sync", BrokerScheduler.Decide(state, new BrokerFacts(), Cfg, 10).lane);
            state.jobs.RemoveAll(j => j.id == "J2");
            var blocked = BrokerScheduler.Decide(state, new BrokerFacts { compileFailed = true }, Cfg, 10);
            Assert.IsFalse(blocked.OpensWindow);
            StringAssert.Contains("compile", blocked.reason);
        }

        [Test]
        public void ExclusiveGetsTheEditorAfterItsMaximumWait()
        {
            var state = WithLease("art", false);
            Job(state, "J1", "exclusive", "exclusive", 0, "lead");
            Assert.IsFalse(BrokerScheduler.Decide(state, new BrokerFacts(), Cfg, 1000).OpensWindow);
            var due = BrokerScheduler.Decide(state, new BrokerFacts(), Cfg, Cfg.exclusiveMaxWaitMs);
            Assert.AreEqual("exclusive", due.lane);
            BrokerScheduler.BeginWindow(state, due, Cfg, Cfg.exclusiveMaxWaitMs);
            Assert.AreEqual("lead", state.window.holder);
            Assert.AreEqual(state.window.id, state.jobs[0].windowId);
        }

        [Test]
        public void NothingOpensWhilePausedBusyOrPlaying()
        {
            var state = WithLease("art", true);
            Job(state, "J1", "sync", "sync", 0);
            state.paused = true;
            Assert.IsFalse(BrokerScheduler.Decide(state, new BrokerFacts(), Cfg, 100000).OpensWindow);
            state.paused = false;
            Assert.IsFalse(BrokerScheduler.Decide(state, new BrokerFacts { isCompiling = true }, Cfg, 100000).OpensWindow);
            Assert.IsFalse(BrokerScheduler.Decide(state, new BrokerFacts { isPlaying = true }, Cfg, 100000).OpensWindow);
        }

        [Test]
        public void ForceDueTreatsEveryLeaseAsYielded()
        {
            var state = WithLease("art", false);
            Job(state, "J1", "hot", "tests", 0);
            Assert.AreEqual("hot", BrokerScheduler.Decide(state, new BrokerFacts { forceDue = true }, Cfg, 10).lane);
        }

        [Test]
        public void DrainCompletesWhenOthersYieldOrAtTheDeadline()
        {
            var state = WithLease("art", false);
            state.leases.Add(new BrokerLease { id = "L2", agent = "lead", kind = "cold", path = "Assets/B/", expiresMs = 10000000 });
            Job(state, "J1", "exclusive", "exclusive", 0, "lead");
            BrokerScheduler.BeginWindow(state, new BrokerDecision { lane = "exclusive", jobIds = new List<string> { "J1" } }, Cfg, 0);
            CollectionAssert.AreEqual(new[] { "art" }, BrokerScheduler.Unyielded(state, 10), "the holder never has to yield");
            Assert.IsFalse(BrokerScheduler.DrainComplete(state, 10));
            Assert.IsTrue(BrokerScheduler.DrainComplete(state, Cfg.drainTimeoutMs));
            state.leases[0].yielded = true;
            Assert.IsTrue(BrokerScheduler.DrainComplete(state, 10));
        }

        [Test]
        public void EndWindowRequeuesJobsItDidNotRun()
        {
            var state = new BrokerState();
            Job(state, "J1", "hot", "session", 0);
            Job(state, "J2", "hot", "session", 1);
            BrokerScheduler.BeginWindow(state, new BrokerDecision { lane = "hot", jobIds = new List<string> { "J1", "J2" } }, Cfg, 0);
            BrokerOps.Finish(state.jobs[0], BrokerConstants.JobPassed, "done", null, 5);
            BrokerScheduler.EndWindow(state, Cfg, 6);
            Assert.IsFalse(state.HasWindow);
            Assert.AreEqual("", state.jobs[1].windowId);
            Assert.AreEqual(BrokerConstants.JobQueued, state.jobs[1].status);
        }
    }

    public sealed class BrokerAdapterPresenceTests
    {
        [Test]
        public void AdapterAssembliesFollowInstalledPackages()
        {
            var assemblies = System.AppDomain.CurrentDomain.GetAssemblies();
            bool Loaded(string name) => System.Array.Exists(assemblies, a => a.GetName().Name == name);
            Assert.AreEqual(Loaded("MCPForUnity.Editor"), Loaded("UnityGameAgent.EditorBroker.Coplay"), "CoplayDev adapter");
            Assert.AreEqual(Loaded("Unity.Pipeline.Editor"), Loaded("UnityGameAgent.EditorBroker.Pipeline"), "Unity Pipeline adapter");
            Assert.AreEqual(Loaded("UnityEditor.TestRunner"), BrokerTestHook.Start != null, "Test Runner bridge");
        }
    }

    public sealed class BrokerStoreTests
    {
        string m_Root;

        [SetUp]
        public void SetUp()
        {
            m_Root = Path.Combine(Path.GetTempPath(), "uga-broker-store-" + System.Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(m_Root);
        }

        [TearDown]
        public void TearDown()
        {
            if (Directory.Exists(m_Root)) Directory.Delete(m_Root, true);
        }

        [Test]
        public void UpdatesPersistAndKeepABackup()
        {
            var store = new BrokerStore(m_Root);
            BrokerState state;
            string error;
            Assert.IsTrue(store.TryUpdate(s =>
            {
                s.sessionId = "S1";
                return true;
            }, 1000, out state, out error), error);
            Assert.IsTrue(store.TryUpdate(s =>
            {
                s.sessionOwner = "lead";
                return true;
            }, 1000, out state, out error), error);
            Assert.IsTrue(File.Exists(store.BackupPath));
            Assert.IsTrue(store.TryRead(1000, out state, out error), error);
            Assert.AreEqual("S1", state.sessionId);
            Assert.AreEqual("lead", state.sessionOwner);
            Assert.AreEqual(2, state.revision);
        }

        [Test]
        public void CorruptStateRecoversFromBackupAndSaysSo()
        {
            var store = new BrokerStore(m_Root);
            BrokerState state;
            string error;
            store.TryUpdate(s =>
            {
                s.sessionId = "S1";
                return true;
            }, 1000, out state, out error);
            store.TryUpdate(s =>
            {
                s.sessionId = "S2";
                return true;
            }, 1000, out state, out error);
            File.WriteAllText(store.StatePath, "{ not json");
            Assert.IsTrue(store.TryRead(1000, out state, out error), error);
            Assert.AreEqual("S1", state.sessionId, "the previous good state comes back");
            Assert.IsTrue(state.violations.Exists(v => v.kind == "state-recovered"));
        }
    }
}
