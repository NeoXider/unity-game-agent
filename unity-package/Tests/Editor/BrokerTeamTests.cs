using System;
using System.IO;
using System.Linq;
using NUnit.Framework;

namespace UnityGameAgent.EditorBroker.Tests
{
    // Store-level behaviour of the roster and the team board; the pure rules run in BrokerVectorTests.
    public sealed class BrokerTeamTests
    {
        string m_Root;
        BrokerStore m_Store;

        [SetUp]
        public void SetUp()
        {
            m_Root = Path.Combine(Path.GetTempPath(), "uga-broker-team-" + Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(m_Root);
            m_Store = new BrokerStore(m_Root);
        }

        [TearDown]
        public void TearDown()
        {
            if (Directory.Exists(m_Root)) Directory.Delete(m_Root, true);
        }

        [Test]
        public void RosterWrittenByTheCliSurvivesAnEditorWrite()
        {
            // The CLI writes the roster; the Editor parses and rewrites the whole state on every tick.
            Directory.CreateDirectory(m_Store.Dir);
            File.WriteAllText(m_Store.StatePath,
                "{\"schema\":1,\"nextId\":4,\"roster\":[{\"agent\":\"core\",\"role\":\"developer\",\"doing\":\"score\",\"firstSeenMs\":1,\"lastSeenMs\":2,\"lastCommand\":\"take\",\"readId\":3}]}");
            BrokerState state;
            string error;
            Assert.IsTrue(m_Store.TryUpdate(s => true, 1000, out state, out error), error);
            Assert.IsTrue(m_Store.TryRead(1000, out state, out error), error);
            var member = state.roster.Single();
            Assert.AreEqual("core", member.agent);
            Assert.AreEqual("developer", member.role);
            Assert.AreEqual(3, member.readId);
        }

        [Test]
        public void SayAndBriefGoThroughTheApi()
        {
            var said = BrokerApi.Execute(m_Store, new BrokerRequest { action = "say", agent = "core", message = "Renamed Score.Add.\n# heading", to = "all" }, out _);
            Assert.AreEqual("posted", said.status, said.message);
            var direct = BrokerApi.Execute(m_Store, new BrokerRequest { action = "say", agent = "qa", message = "Tooltip overlaps.", to = "ui, core" }, out _);
            Assert.AreEqual("posted", direct.status, direct.message);
            Assert.AreEqual("error", BrokerApi.Execute(m_Store, new BrokerRequest { action = "say", agent = "qa", message = "x", to = "bad name" }, out _).status);
            Assert.AreEqual("error", BrokerApi.Execute(m_Store, new BrokerRequest { action = "say", agent = "qa", message = "  " }, out _).status);

            var text = File.ReadAllText(BrokerTeam.BoardPath(m_Store));
            Assert.IsTrue(text.StartsWith("# Team board", StringComparison.Ordinal));
            Assert.AreEqual(1, text.Split('\n').Count(l => l == "# Team board"), "header is written once");
            var entries = BrokerTeam.ParseBoard(text);
            Assert.AreEqual(2, entries.Count);
            Assert.AreEqual("Renamed Score.Add.\n\\# heading", entries[0].text);

            var gate = BrokerApi.Execute(m_Store, new BrokerRequest { action = "gate", agent = "ui" }, out _);
            Assert.AreEqual(2, gate.unread, "ui has two messages before its first brief");

            var brief = BrokerApi.Execute(m_Store, new BrokerRequest { action = "brief", agent = "ui", doing = "upgrade screen" }, out _);
            Assert.AreEqual("ok", brief.status, brief.message);
            StringAssert.Contains("Team (3):", brief.message);
            StringAssert.Contains("Board: 2 new", brief.message);
            StringAssert.Contains("Tooltip overlaps.", brief.message);

            var again = BrokerApi.Execute(m_Store, new BrokerRequest { action = "brief", agent = "ui" }, out _);
            StringAssert.Contains("Board: 0 new", again.message);
            Assert.AreEqual(0, again.unread);

            BrokerState state;
            string error;
            Assert.IsTrue(m_Store.TryRead(1000, out state, out error), error);
            Assert.AreEqual("upgrade screen", state.roster.Single(m => m.agent == "ui").doing);
            Assert.AreEqual(1, BrokerTeam.UnreadCount(m_Store, state, "core"), "core sees qa's message, not its own");
        }

        [Test]
        public void BriefShowsTheQueueWithAnEta()
        {
            BrokerState state;
            string error;
            Assert.IsTrue(m_Store.TryUpdate(s =>
            {
                var now = BrokerClock.NowMs();
                BrokerOps.Request(s, BrokerConfig.Default, "qa", BrokerConstants.LaneHot, BrokerConstants.JobTests, null,
                    "category:Smoke", "PlayMode", "", 0, "", now);
                return true;
            }, 1000, out state, out error), error);
            var brief = BrokerApi.Execute(m_Store, new BrokerRequest { action = "brief", agent = "qa" }, out _);
            StringAssert.Contains("ETA from defaults", brief.message);
            StringAssert.Contains("qa hot/tests: ~", brief.message);
            StringAssert.Contains("<- yours", brief.message);
        }
    }
}
