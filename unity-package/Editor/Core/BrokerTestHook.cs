using System;
using System.Collections.Generic;
using System.IO;

namespace UnityGameAgent.EditorBroker
{
    [Serializable]
    public sealed class BrokerTestCase
    {
        public string fullName = "";
        public string assembly = "";
        public List<string> categories = new List<string>();
        public string status = "";
        public string message = "";
    }

    [Serializable]
    public sealed class BrokerTestRunResult
    {
        public string windowId = "";
        public string mode = "";
        public long finishedMs;
        public string error = "";
        public List<BrokerTestCase> cases = new List<BrokerTestCase>();
    }

    // The core assembly does not reference the Unity Test Framework. The optional
    // UnityGameAgent.EditorBroker.TestRunner assembly installs Start when the package is present
    // and writes the run result to ResultPath when the (possibly reloaded) run finishes.
    public static class BrokerTestHook
    {
        public delegate bool StartRun(string windowId, string mode, List<BrokerJob> jobs, out string error);

        public static StartRun Start;

        public static string ResultPath(BrokerStore store, string windowId, string mode)
        {
            return Path.Combine(store.Dir, "tests-" + windowId + "-" + mode + ".json");
        }
    }
}
