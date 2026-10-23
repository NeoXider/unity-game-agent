using System;
using System.Collections.Generic;

namespace UnityGameAgent.EditorBroker
{
    // The state file is shared with tools/editor-broker.ps1. Field names are the wire format:
    // keep them in sync with the CLI and never rename one without a schema bump.

    [Serializable]
    public sealed class BrokerState
    {
        public int schema = BrokerConstants.Schema;
        public long revision;
        public long updatedMs;
        public long nextId = 1;
        public string sessionId = "";
        public long sessionStartedMs;
        public string sessionOwner = "";
        public bool paused;
        public string projectSettingsRequest = "";
        public List<BrokerLease> leases = new List<BrokerLease>();
        public List<BrokerWaiter> waiting = new List<BrokerWaiter>();
        public List<BrokerJob> jobs = new List<BrokerJob>();
        public BrokerWindow window = new BrokerWindow();
        public List<BrokerViolation> violations = new List<BrokerViolation>();

        public bool HasWindow => window != null && !string.IsNullOrEmpty(window.id);
        public bool SessionActive => !string.IsNullOrEmpty(sessionId);

        public string NewId(string prefix)
        {
            var id = prefix + nextId;
            nextId++;
            return id;
        }

        public void Normalize()
        {
            if (leases == null) leases = new List<BrokerLease>();
            if (waiting == null) waiting = new List<BrokerWaiter>();
            if (jobs == null) jobs = new List<BrokerJob>();
            if (window == null) window = new BrokerWindow();
            if (violations == null) violations = new List<BrokerViolation>();
            if (sessionId == null) sessionId = "";
            if (sessionOwner == null) sessionOwner = "";
            if (projectSettingsRequest == null) projectSettingsRequest = "";
            window.Normalize();
            foreach (var job in jobs) job.Normalize();
            if (nextId < 1) nextId = 1;
        }
    }

    [Serializable]
    public sealed class BrokerLease
    {
        public string id = "";
        public string agent = "";
        public string kind = "";
        public string resource = "";
        public string path = "";
        public long grantedMs;
        public long expiresMs;
        public bool yielded;
        public string note = "";
    }

    [Serializable]
    public sealed class BrokerWaiter
    {
        public string id = "";
        public string agent = "";
        public string kind = "";
        public string resource = "";
        public string path = "";
        public long requestedMs;
        public long expiresMs;
        public int ttlSec;
    }

    [Serializable]
    public sealed class BrokerJob
    {
        public string id = "";
        public string agent = "";
        public string lane = "";
        public string kind = "";
        public List<string> paths = new List<string>();
        public string tests = "";
        public string testMode = "";
        public string scene = "";
        public float minutes;
        public string reason = "";
        public long createdMs;
        public string status = BrokerConstants.JobQueued;
        public long startedMs;
        public long finishedMs;
        public string windowId = "";
        public bool doneRequested;
        public string summary = "";
        public List<string> details = new List<string>();

        public bool IsFinished => BrokerConstants.IsFinishedStatus(status);

        public void Normalize()
        {
            if (paths == null) paths = new List<string>();
            if (details == null) details = new List<string>();
            if (status == null) status = BrokerConstants.JobQueued;
            if (tests == null) tests = "";
            if (testMode == null) testMode = "";
            if (scene == null) scene = "";
            if (reason == null) reason = "";
            if (windowId == null) windowId = "";
            if (summary == null) summary = "";
        }
    }

    [Serializable]
    public sealed class BrokerWindow
    {
        public string id = "";
        public string lane = "";
        public string phase = "";
        public string holder = "";
        public long requestedMs;
        public long drainDeadlineMs;
        public long startedMs;
        public long phaseStartedMs;
        public long deadlineMs;
        public List<string> jobIds = new List<string>();
        public string currentJob = "";
        public string note = "";
        public List<string> appliedFiles = new List<string>();
        public string sceneSetup = "";

        public void Clear()
        {
            id = lane = phase = holder = currentJob = note = sceneSetup = "";
            requestedMs = drainDeadlineMs = startedMs = phaseStartedMs = deadlineMs = 0;
            jobIds = new List<string>();
            appliedFiles = new List<string>();
        }

        public void Normalize()
        {
            if (id == null) id = "";
            if (lane == null) lane = "";
            if (phase == null) phase = "";
            if (holder == null) holder = "";
            if (currentJob == null) currentJob = "";
            if (note == null) note = "";
            if (sceneSetup == null) sceneSetup = "";
            if (jobIds == null) jobIds = new List<string>();
            if (appliedFiles == null) appliedFiles = new List<string>();
        }
    }

    [Serializable]
    public sealed class BrokerViolation
    {
        public long atMs;
        public string agent = "";
        public string kind = "";
        public string detail = "";
    }

    [Serializable]
    public sealed class BrokerOpResult
    {
        public string status = "";
        public string message = "";
        public string leaseId = "";
        public string jobId = "";
        public int position;

        public static BrokerOpResult Of(string status, string message)
        {
            return new BrokerOpResult { status = status, message = message };
        }
    }

    // Written only by the Editor (Library/UgaBroker/editor.json); the CLI reads it.
    [Serializable]
    public sealed class BrokerEditorStatus
    {
        public int schema = BrokerConstants.Schema;
        public int pid;
        public string unityVersion = "";
        public string packageVersion = "";
        public string projectPath = "";
        public long heartbeatMs;
        public string phase = "";
        public bool isCompiling;
        public bool isUpdating;
        public bool isPlaying;
        public bool compileFailed;
        public bool brokerPaused;
        public string activeScene = "";
        public List<string> loadedScenes = new List<string>();
        public List<string> dirtyScenes = new List<string>();
        public string sessionId = "";
        public string projectSettingsApplied = "";
        public List<BrokerSettingReport> settings = new List<BrokerSettingReport>();
        public List<BrokerAdapterReport> adapters = new List<BrokerAdapterReport>();
        public string lastError = "";
    }

    [Serializable]
    public sealed class BrokerSettingReport
    {
        public string name = "";
        public string scope = "";
        public string current = "";
        public string desired = "";
        public bool ok;
        public string note = "";
    }

    [Serializable]
    public sealed class BrokerAdapterReport
    {
        public string name = "";
        public bool present;
        public bool ok;
        public string note = "";
    }

    public static class BrokerConstants
    {
        public const int Schema = 1;
        public const string PackageVersion = "3.8.0";

        public const string KindCold = "cold";
        public const string KindFocus = "focus";

        public const string LaneSync = "sync";
        public const string LaneHot = "hot";
        public const string LaneExclusive = "exclusive";

        public const string JobSync = "sync";
        public const string JobTests = "tests";
        public const string JobSession = "session";
        public const string JobSmoke = "smoke";
        public const string JobExclusive = "exclusive";

        public const string JobQueued = "queued";
        public const string JobRunning = "running";
        public const string JobPassed = "passed";
        public const string JobFailed = "failed";
        public const string JobBlocked = "blocked";
        public const string JobCanceled = "canceled";

        public const string PhaseDraining = "draining";
        public const string PhaseApplying = "applying";
        public const string PhaseCompiling = "compiling";
        public const string PhaseTests = "tests";
        public const string PhaseSession = "session";
        public const string PhaseExclusive = "exclusive";
        public const string PhaseSettling = "settling";

        public static bool IsFinishedStatus(string status)
        {
            return status == JobPassed || status == JobFailed || status == JobBlocked || status == JobCanceled;
        }
    }

    [Serializable]
    public sealed class BrokerConfig
    {
        public int defaultTtlSec = 900;
        public int maxTtlSec = 3600;
        public long focusMaxHoldMs = 180000;
        public long waiterTtlMs = 900000;
        public long syncMaxWaitMs = 30000;
        public long hotMaxWaitMs = 600000;
        public int hotBatchSize = 3;
        public long exclusiveMaxWaitMs = 120000;
        public long drainTimeoutMs = 60000;
        public long hotWindowMaxMs = 600000;
        public float sessionDefaultMinutes = 5f;
        public float exclusiveDefaultMinutes = 10f;
        public long hotRetryCooldownMs = 60000;
        public int maxFinishedJobs = 50;
        public int maxViolations = 50;

        public static readonly BrokerConfig Default = new BrokerConfig();
    }
}
