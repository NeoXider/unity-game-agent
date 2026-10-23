using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using NUnit.Framework;
using UnityEngine;

namespace UnityGameAgent.EditorBroker.Tests
{
    // Runs the same cases as tools/test-editor-broker.ps1, so the CLI and the Editor agree on
    // resource parsing, lease conflicts, FIFO promotion, focus limits and request validation.
    public sealed class BrokerVectorTests
    {
        [Serializable]
        sealed class AsmdefEntry
        {
            public string name = "";
            public string path = "";
        }

        [Serializable]
        sealed class PathCase
        {
            public string resource = "";
            public bool ok;
            public string type = "";
            public string path = "";
        }

        [Serializable]
        sealed class OverlapCase
        {
            public string a = "";
            public string b = "";
            public bool overlap;
        }

        [Serializable]
        sealed class CoverCase
        {
            public string lease = "";
            public string asset = "";
            public bool covered;
        }

        [Serializable]
        sealed class Step
        {
            public string op = "";
            public string agent = "";
            public string kind = "";
            public string resource = "";
            public string expect = "";
            public string lane = "";
            public string holder = "";
            public string paths = "";
            public string tests = "";
            public string mode = "";
            public string scene = "";
            public string reason = "";
            public long at;
            public int ttl;
            public int position;
            public int count;
            public float minutes;
            public bool value;
            public List<string> granted = new List<string>();
            public List<string> list = new List<string>();
        }

        [Serializable]
        sealed class Scenario
        {
            public string name = "";
            public List<Step> steps = new List<Step>();
        }

        [Serializable]
        sealed class FilterCase
        {
            public string spec = "";
            public string fullName = "";
            public string assembly = "";
            public List<string> categories = new List<string>();
            public bool match;
        }

        [Serializable]
        sealed class Vectors
        {
            public List<AsmdefEntry> asmdefs = new List<AsmdefEntry>();
            public List<PathCase> paths = new List<PathCase>();
            public List<OverlapCase> overlaps = new List<OverlapCase>();
            public List<CoverCase> covers = new List<CoverCase>();
            public List<Scenario> scenarios = new List<Scenario>();
            public List<FilterCase> filters = new List<FilterCase>();
        }

        static Vectors s_Vectors;

        static Vectors Load()
        {
            if (s_Vectors != null) return s_Vectors;
            var package = UnityEditor.PackageManager.PackageInfo.FindForAssembly(typeof(BrokerOps).Assembly);
            Assert.IsNotNull(package, "Broker package not found");
            var path = Path.Combine(package.resolvedPath, "Tests/Editor/broker-vectors.json");
            s_Vectors = JsonUtility.FromJson<Vectors>(File.ReadAllText(path));
            return s_Vectors;
        }

        static Func<string, string> Resolver()
        {
            var vectors = Load();
            return name => vectors.asmdefs.Where(a => a.name == name).Select(a => a.path).FirstOrDefault();
        }

        [Test]
        public void ResourcesParseAsSpecified()
        {
            foreach (var c in Load().paths)
            {
                string type, path, error;
                var ok = BrokerPaths.TryParse(c.resource, Resolver(), out type, out path, out error);
                Assert.AreEqual(c.ok, ok, c.resource + ": " + error);
                if (!c.ok) continue;
                Assert.AreEqual(c.type, type, c.resource);
                Assert.AreEqual(c.path, path, c.resource);
            }
        }

        [Test]
        public void OverlapAndCoverageFollowFolderPrefixes()
        {
            foreach (var c in Load().overlaps)
            {
                Assert.AreEqual(c.overlap, BrokerPaths.Overlaps(c.a, c.b), c.a + " vs " + c.b);
                Assert.AreEqual(c.overlap, BrokerPaths.Overlaps(c.b, c.a), c.b + " vs " + c.a);
            }
            foreach (var c in Load().covers)
                Assert.AreEqual(c.covered, BrokerPaths.Covers(c.lease, c.asset), c.lease + " covers " + c.asset);
        }

        [Test]
        public void TestFiltersMatchLikeUnityFilters()
        {
            foreach (var c in Load().filters)
            {
                string error;
                var filter = BrokerTestFilter.Parse(c.spec, out error);
                Assert.IsNotNull(filter, c.spec + ": " + error);
                Assert.AreEqual(c.match, filter.Matches(c.fullName, c.assembly, c.categories), c.spec + " on " + c.fullName);
            }
        }

        [Test]
        public void ScenariosProduceTheExpectedLeaseState()
        {
            foreach (var scenario in Load().scenarios) Run(scenario);
        }

        static string Key(string agent, string kind, string path)
        {
            return agent + "|" + kind + "|" + path;
        }

        static void Run(Scenario scenario)
        {
            var cfg = new BrokerConfig();
            var state = new BrokerState();
            for (var i = 0; i < scenario.steps.Count; i++)
            {
                var step = scenario.steps[i];
                var label = scenario.name + " step " + (i + 1) + " (" + step.op + ")";
                var now = step.at;
                string type, path, error;
                switch (step.op)
                {
                    case "take":
                        var parsed = BrokerPaths.TryParse(step.resource, Resolver(), out type, out path, out error);
                        var take = parsed
                            ? BrokerOps.Take(state, cfg, step.agent, step.kind, step.resource, path, step.ttl, now)
                            : BrokerOpResult.Of("error", error);
                        Assert.AreEqual(step.expect, take.status, label + ": " + take.message);
                        if (step.expect == "queued") Assert.AreEqual(step.position, take.position, label + " position");
                        break;
                    case "release":
                        path = null;
                        if (step.resource.Length > 0) Assert.IsTrue(BrokerPaths.TryParse(step.resource, Resolver(), out type, out path, out error), label);
                        Assert.AreEqual(step.count, BrokerOps.Release(state, step.agent, path), label);
                        break;
                    case "renew":
                        Assert.AreEqual(step.count, BrokerOps.Renew(state, cfg, step.agent, step.ttl, now), label);
                        break;
                    case "yield":
                        Assert.AreEqual(step.count, BrokerOps.Yield(state, step.agent, now), label);
                        break;
                    case "gate":
                        Assert.AreEqual(step.expect, BrokerOps.Gate(state, step.agent, now).status, label);
                        break;
                    case "promote":
                        var granted = BrokerOps.Promote(state, cfg, now).Select(l => Key(l.agent, l.kind, l.path)).ToList();
                        CollectionAssert.AreEqual(step.granted, granted, label);
                        break;
                    case "leases":
                        var leases = state.leases.Select(l => Key(l.agent, l.kind, l.path)).OrderBy(s => s, StringComparer.Ordinal).ToList();
                        CollectionAssert.AreEqual(step.list.OrderBy(s => s, StringComparer.Ordinal).ToList(), leases, label);
                        break;
                    case "waiting":
                        CollectionAssert.AreEqual(step.list, state.waiting.Select(w => Key(w.agent, w.kind, w.path)).ToList(), label);
                        break;
                    case "window":
                        state.window.Clear();
                        state.window.id = "W-test";
                        state.window.lane = step.lane;
                        state.window.phase = BrokerConstants.PhaseDraining;
                        state.window.holder = step.holder;
                        break;
                    case "endwindow":
                        state.window.Clear();
                        break;
                    case "yielded":
                        var mine = state.leases.Where(l => BrokerOps.SameAgent(l.agent, step.agent)).ToList();
                        Assert.IsTrue(mine.Count > 0, label + ": agent has no lease");
                        Assert.IsTrue(mine.All(l => l.yielded == step.value), label);
                        break;
                    case "request":
                        var paths = step.paths.Split(';').Select(p => p.Trim()).Where(p => p.Length > 0).ToList();
                        var request = BrokerOps.Request(state, cfg, step.agent, step.lane, step.kind, paths, step.tests, step.mode,
                            step.scene, step.minutes, step.reason, now);
                        Assert.AreEqual(step.expect, request.status, label + ": " + request.message);
                        break;
                    default:
                        Assert.Fail(label + ": unknown op");
                        break;
                }
            }
        }
    }
}
