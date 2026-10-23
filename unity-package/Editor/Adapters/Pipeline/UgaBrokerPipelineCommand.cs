using System.Collections.Generic;
using Unity.Pipeline.Commands;

namespace UnityGameAgent.EditorBroker.Adapters
{
    // Unity CLI command (com.unity.pipeline 0.8+): `unity command uga_broker --action status`.
    // It touches only the broker state file, so it does not need the main thread and answers while
    // the Editor imports. The Pipeline server still restarts on domain reload; for waiting on a
    // window use tools/editor-broker.ps1 wait.
    public static class UgaBrokerPipelineCommand
    {
        [CliCommand("global", "uga_broker",
            "Unity Game Agent editor broker for several agents sharing one Editor: status, take, release, renew, yield, gate, request, cancel, done, job.",
            MainThreadRequired = false)]
        public static Dictionary<string, object> UgaBroker(
            [CliArg("action", "status | take | release | renew | yield | gate | request | cancel | done | job")] string action = "status",
            [CliArg("agent", "Your agent name")] string agent = "",
            [CliArg("resource", "scene:/prefab:/asset:/folder:/asmdef: resource for take or release")] string resource = "",
            [CliArg("kind", "cold or focus")] string kind = "cold",
            [CliArg("ttl_sec", "Lease time to live in seconds")] int ttl_sec = 0,
            [CliArg("lane", "sync, hot or exclusive")] string lane = "",
            [CliArg("job_kind", "sync, tests, session or exclusive")] string job_kind = "",
            [CliArg("paths", "Extra asset paths to reimport, separated by ';'")] string paths = "",
            [CliArg("tests", "name:/group:/category:/assembly: selection")] string tests = "",
            [CliArg("test_mode", "PlayMode or EditMode")] string test_mode = "",
            [CliArg("scene", "Scene for a Play Mode session")] string scene = "",
            [CliArg("minutes", "Time box for a session or exclusive window")] float minutes = 0f,
            [CliArg("reason", "Why an exclusive window is needed")] string reason = "",
            [CliArg("job_id", "Job id for cancel, done or job")] string job_id = "")
        {
            var request = new BrokerRequest
            {
                action = action, agent = agent, resource = resource, kind = kind, ttlSec = ttl_sec, lane = lane,
                jobKind = job_kind, paths = paths, tests = tests, testMode = test_mode, scene = scene,
                minutes = minutes, reason = reason, jobId = job_id
            };
            string board;
            var result = BrokerApi.Execute(BrokerStore.ForCurrentProject(), request, out board);
            return new Dictionary<string, object>
            {
                { "status", result.status },
                { "message", result.message },
                { "lease_id", result.leaseId },
                { "job_id", result.jobId },
                { "position", result.position },
                { "board", board }
            };
        }
    }
}
