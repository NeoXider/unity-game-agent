using NUnit.Framework;
using UnityGameAgent.EditorBroker.Adapters;

namespace UnityGameAgent.EditorBroker.Tests
{
    // Compiled only when the Unity Pipeline package (Unity CLI bridge) is installed.
    public sealed class BrokerPipelineCommandTests
    {
        [Test]
        public void StatusReturnsTheBoard()
        {
            var result = UgaBrokerPipelineCommand.UgaBroker("status");
            Assert.AreEqual("ok", result["status"]);
            StringAssert.Contains("Session:", (string)result["board"]);
        }

        [Test]
        public void TakeAndReleaseRoundTrip()
        {
            Assert.AreEqual("granted", UgaBrokerPipelineCommand.UgaBroker("take", "pipeline-test", "asset:Assets/PipelineTest/A.asset")["status"]);
            Assert.AreEqual("released", UgaBrokerPipelineCommand.UgaBroker("release", "pipeline-test")["status"]);
        }
    }
}