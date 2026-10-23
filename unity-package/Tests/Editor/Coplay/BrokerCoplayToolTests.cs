using MCPForUnity.Editor.Helpers;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using NUnit.Framework;
using UnityGameAgent.EditorBroker.Adapters;

namespace UnityGameAgent.EditorBroker.Tests
{
    // Compiled only when MCP for Unity (CoplayDev) is installed.
    public sealed class BrokerCoplayToolTests
    {
        [Test]
        public void StatusReturnsTheBoard()
        {
            var response = UgaBrokerCoplayTool.HandleCommand(new JObject { ["action"] = "status" });
            Assert.IsInstanceOf<SuccessResponse>(response);
            StringAssert.Contains("Session:", JsonConvert.SerializeObject(response));
        }

        [Test]
        public void UnknownActionIsAnError()
        {
            var response = UgaBrokerCoplayTool.HandleCommand(new JObject { ["action"] = "explode", ["agent"] = "qa" });
            Assert.IsInstanceOf<ErrorResponse>(response);
        }
    }
}