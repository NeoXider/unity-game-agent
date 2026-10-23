using MCPForUnity.Editor.Helpers;
using MCPForUnity.Editor.Tools;
using Newtonsoft.Json.Linq;

namespace UnityGameAgent.EditorBroker.Adapters
{
    // MCP for Unity (CoplayDev) custom tool. Compiled only when com.coplaydev.unity-mcp is
    // installed. It works while the Editor is responsive; during a compile, reload or Play Mode
    // transition use tools/editor-broker.ps1, which reads the same state file.
    [McpForUnityTool("uga_broker", AutoRegister = true,
        Description = "Unity Game Agent editor broker for several agents sharing one Editor. Actions: status, take, release, renew, yield, gate, request, cancel, done, job. Take a lease before editing a scene/prefab/asset/folder, call gate before each batch of Editor calls, yield when idle, and request sync/hot/exclusive work instead of refreshing, compiling, entering Play Mode or running tests yourself.")]
    public static class UgaBrokerCoplayTool
    {
        public sealed class Parameters
        {
            [ToolParameter("status | take | release | renew | yield | gate | request | cancel | done | job", Required = false, DefaultValue = "status")]
            public string action { get; set; }

            [ToolParameter("Your agent name (letters, digits, '.', '_' or '-').", Required = false)]
            public string agent { get; set; }

            [ToolParameter("take/release: scene:Assets/X.unity, prefab:..., asset:..., folder:Assets/UI/ or asmdef:Name.", Required = false)]
            public string resource { get; set; }

            [ToolParameter("take: cold (ownership) or focus (scene-graph token; needs a cold lease on the scene).", Required = false, DefaultValue = "cold")]
            public string kind { get; set; }

            [ToolParameter("take/renew: lease time to live in seconds.", Required = false)]
            public int ttl_sec { get; set; }

            [ToolParameter("request: sync, hot or exclusive.", Required = false)]
            public string lane { get; set; }

            [ToolParameter("request: sync, tests, session or exclusive (defaults by lane).", Required = false)]
            public string job_kind { get; set; }

            [ToolParameter("request sync: extra asset paths under your lease to reimport, separated by ';'.", Required = false)]
            public string paths { get; set; }

            [ToolParameter("request tests: name:Full.Name; group:regex; category:Cat; assembly:Asm.", Required = false)]
            public string tests { get; set; }

            [ToolParameter("request tests: PlayMode or EditMode.", Required = false)]
            public string test_mode { get; set; }

            [ToolParameter("request session: scene to open for the Play Mode session.", Required = false)]
            public string scene { get; set; }

            [ToolParameter("request session/exclusive: time box in minutes.", Required = false)]
            public float minutes { get; set; }

            [ToolParameter("request exclusive: why the whole Editor is needed.", Required = false)]
            public string reason { get; set; }

            [ToolParameter("cancel/done/job: job id.", Required = false)]
            public string job_id { get; set; }
        }

        public static object HandleCommand(JObject @params)
        {
            var request = new BrokerRequest
            {
                action = Str(@params, "action", "status"),
                agent = Str(@params, "agent", ""),
                resource = Str(@params, "resource", ""),
                kind = Str(@params, "kind", BrokerConstants.KindCold),
                ttlSec = @params?["ttl_sec"]?.Value<int>() ?? 0,
                lane = Str(@params, "lane", ""),
                jobKind = Str(@params, "job_kind", ""),
                paths = Str(@params, "paths", ""),
                tests = Str(@params, "tests", ""),
                testMode = Str(@params, "test_mode", ""),
                scene = Str(@params, "scene", ""),
                minutes = @params?["minutes"]?.Value<float>() ?? 0f,
                reason = Str(@params, "reason", ""),
                jobId = Str(@params, "job_id", "")
            };
            string board;
            var result = BrokerApi.Execute(BrokerStore.ForCurrentProject(), request, out board);
            var data = new
            {
                status = result.status,
                lease_id = result.leaseId,
                job_id = result.jobId,
                position = result.position,
                board
            };
            if (result.status == "error") return new ErrorResponse(result.message, data);
            return new SuccessResponse(result.message, data);
        }

        static string Str(JObject source, string key, string fallback)
        {
            var token = source?[key];
            return token == null || token.Type == JTokenType.Null ? fallback : token.ToString();
        }
    }
}
