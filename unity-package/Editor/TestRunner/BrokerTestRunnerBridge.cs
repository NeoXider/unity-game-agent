using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using UnityEditor;
using UnityEditor.TestTools.TestRunner.Api;
using UnityEngine;

namespace UnityGameAgent.EditorBroker
{
    // Compiled only when com.unity.test-framework is installed (see the asmdef versionDefines).
    // Every queued selection of one mode runs in ONE Test Runner execution: the bridge lists the
    // tests, applies each job's selection with the broker's own matcher, and executes the union by
    // exact full names. (Several Filters in one ExecutionSettings do not reliably run as one batch.)
    [InitializeOnLoad]
    static class BrokerTestRunnerBridge
    {
        const string RunKey = "UgaBroker.TestRun";
        const string PlayModeOptionsKey = "UgaBroker.TestRun.PlayModeOptions";
        static TestRunnerApi s_Api;

        static BrokerTestRunnerBridge()
        {
            if (AssetDatabase.IsAssetImportWorkerProcess()) return;
            s_Api = ScriptableObject.CreateInstance<TestRunnerApi>();
            // Callbacks do not survive a domain reload; registering here re-attaches them in the
            // new domain, where a Play Mode run reports RunFinished.
            s_Api.RegisterCallbacks(new Callbacks());
            BrokerTestHook.Start = Start;
            // A run that ended without RunFinished (crash, cancel) must not leave reload switched on.
            if (SessionState.GetString(RunKey, "").Length == 0) RestorePlayModeOptions();
        }

        // Observed on Unity 6000.6 with Test Framework 1.8 (batch mode): with domain reload
        // disabled, only the first Play Mode test run of an Editor session discovers tests; later
        // runs start with zero tests. Each broker Play Mode run therefore reloads the domain, and
        // the project's own Enter Play Mode Options come back when the run finishes.
        static void EnableDomainReloadForRun()
        {
            var options = EditorSettings.enterPlayModeOptions;
            if ((options & EnterPlayModeOptions.DisableDomainReload) == 0) return;
            SessionState.SetInt(PlayModeOptionsKey, (int)options);
            EditorSettings.enterPlayModeOptions = options & ~EnterPlayModeOptions.DisableDomainReload;
        }

        static void RestorePlayModeOptions()
        {
            var saved = SessionState.GetInt(PlayModeOptionsKey, -1);
            if (saved < 0) return;
            EditorSettings.enterPlayModeOptions = (EnterPlayModeOptions)saved;
            SessionState.EraseInt(PlayModeOptionsKey);
        }

        static bool Start(string windowId, string mode, List<BrokerJob> jobs, out string error)
        {
            error = "";
            var filters = new List<BrokerTestFilter>();
            foreach (var job in jobs)
            {
                string parseError;
                var parsed = BrokerTestFilter.Parse(job.tests, out parseError);
                if (parsed == null)
                {
                    error = job.id + ": " + parseError;
                    return false;
                }
                filters.Add(parsed);
            }
            var testMode = mode == "EditMode" ? TestMode.EditMode : TestMode.PlayMode;
            s_Api.RetrieveTestList(testMode, root =>
            {
                var selected = new List<string>();
                CollectSelected(root, filters, selected);
                Trace("start " + windowId + " " + mode + " selected " + selected.Count + ": " + string.Join(", ", selected));
                if (selected.Count == 0)
                {
                    WriteResult(new BrokerTestRunResult { windowId = windowId, mode = mode, finishedMs = BrokerClock.NowMs() });
                    return;
                }
                SessionState.SetString(RunKey, windowId + "|" + mode);
                if (testMode == TestMode.PlayMode) EnableDomainReloadForRun();
                s_Api.Execute(new ExecutionSettings(new Filter { testMode = testMode, testNames = selected.Distinct().ToArray() }));
            });
            return true;
        }

        static void CollectSelected(ITestAdaptor test, List<BrokerTestFilter> filters, List<string> selected)
        {
            if (test.HasChildren)
            {
                foreach (var child in test.Children) CollectSelected(child, filters, selected);
                return;
            }
            if (test.IsSuite) return;
            var categories = test.Categories ?? new string[0];
            var assembly = AssemblyName(test);
            if (filters.Any(f => f.Matches(test.FullName, assembly, categories))) selected.Add(test.FullName);
        }

        // One line per run step in Library/UgaBroker/tests.log: enough to diagnose a selection that
        // matched nothing without attaching a debugger.
        static void Trace(string line)
        {
            try
            {
                var store = BrokerStore.ForCurrentProject();
                Directory.CreateDirectory(store.Dir);
                File.AppendAllText(Path.Combine(store.Dir, "tests.log"), System.DateTime.UtcNow.ToString("o") + " " + line + "\n", new UTF8Encoding(false));
            }
            catch (IOException)
            {
                // Diagnostics only.
            }
        }

        static void WriteResult(BrokerTestRunResult run)
        {
            var store = BrokerStore.ForCurrentProject();
            Directory.CreateDirectory(store.Dir);
            File.WriteAllText(BrokerTestHook.ResultPath(store, run.windowId, run.mode), JsonUtility.ToJson(run, true), new UTF8Encoding(false));
        }

        sealed class Callbacks : ICallbacks
        {
            public void RunStarted(ITestAdaptor testsToRun)
            {
            }

            public void RunFinished(ITestResultAdaptor result)
            {
                var marker = SessionState.GetString(RunKey, "");
                Trace("finished marker '" + marker + "' root " + (result.Test != null ? result.Test.FullName : "?") +
                      " pass " + result.PassCount + " fail " + result.FailCount + " skip " + result.SkipCount);
                if (marker.Length == 0) return;
                SessionState.EraseString(RunKey);
                RestorePlayModeOptions();
                var parts = marker.Split('|');
                var run = new BrokerTestRunResult { windowId = parts[0], mode = parts.Length > 1 ? parts[1] : "", finishedMs = BrokerClock.NowMs() };
                Collect(result, run.cases);
                Trace("cases " + run.cases.Count + ": " + string.Join(", ", run.cases.Select(c => c.fullName + "=" + c.status)));
                WriteResult(run);
            }

            public void TestStarted(ITestAdaptor test)
            {
            }

            public void TestFinished(ITestResultAdaptor result)
            {
            }
        }

        static void Collect(ITestResultAdaptor result, List<BrokerTestCase> cases)
        {
            if (result.HasChildren)
            {
                foreach (var child in result.Children) Collect(child, cases);
                return;
            }
            if (result.Test.IsSuite) return;
            cases.Add(new BrokerTestCase
            {
                fullName = result.Test.FullName,
                assembly = AssemblyName(result.Test),
                categories = result.Test.Categories != null ? result.Test.Categories.ToList() : new List<string>(),
                status = result.TestStatus.ToString(),
                message = result.Message ?? ""
            });
        }

        static string AssemblyName(ITestAdaptor test)
        {
            var type = test.TypeInfo;
            return type != null && type.Assembly != null ? type.Assembly.GetName().Name : "";
        }
    }
}
