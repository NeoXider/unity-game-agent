using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Security.Cryptography;
using System.Text;
using UnityEngine;

namespace UnityGameAgent.EditorBroker
{
    [Serializable]
    public sealed class BrokerMachineEntry
    {
        public string projectPath = "";
        public int pid;
        public string unityVersion = "";
        public string packageVersion = "";
        public long heartbeatMs;
        public string phase = "";
        public string sessionId = "";
        public int leases;
        public int queuedJobs;
        public string window = "";
    }

    [Serializable]
    public sealed class BrokerSessionHolder
    {
        public string projectPath = "";
        public string sessionId = "";
        public long sinceMs;
    }

    [Serializable]
    public sealed class BrokerPrefBackup
    {
        public string name = "";
        public bool isBool;
        public bool existed;
        public int intValue;
        public bool boolValue;
    }

    // Editor preferences are per user, not per project, so session settings are shared by every
    // project on the machine: the first session backs them up, the last one restores them.
    [Serializable]
    public sealed class BrokerMachineSettings
    {
        public List<BrokerSessionHolder> holders = new List<BrokerSessionHolder>();
        public List<BrokerPrefBackup> backups = new List<BrokerPrefBackup>();
    }

    // Machine-wide data shared by every project's broker and the CLI. Same layout as
    // tools/editor-broker.ps1: %LOCALAPPDATA%/UnityGameAgent on Windows, ~/.unity-game-agent elsewhere,
    // or UGA_MACHINE_DIR when set (tests).
    public static class BrokerMachine
    {
        static readonly UTF8Encoding Utf8NoBom = new UTF8Encoding(false);

        public static string Dir
        {
            get
            {
                var overridden = Environment.GetEnvironmentVariable("UGA_MACHINE_DIR");
                if (!string.IsNullOrEmpty(overridden)) return overridden;
                if (Environment.OSVersion.Platform == PlatformID.Win32NT)
                    return Path.Combine(Environment.GetEnvironmentVariable("LOCALAPPDATA") ?? Path.GetTempPath(), "UnityGameAgent");
                return Path.Combine(Environment.GetEnvironmentVariable("HOME") ?? Path.GetTempPath(), ".unity-game-agent");
            }
        }

        public static string RegistryDir => Path.Combine(Dir, "brokers");

        public static string ProjectKey(string projectRoot)
        {
            var normalized = Path.GetFullPath(projectRoot).Replace('\\', '/').TrimEnd('/').ToLowerInvariant();
            using (var sha = SHA1.Create())
            {
                var hash = sha.ComputeHash(Encoding.UTF8.GetBytes(normalized));
                return BitConverter.ToString(hash).Replace("-", "").Substring(0, 16).ToLowerInvariant();
            }
        }

        public static string EntryPath(string projectRoot)
        {
            return Path.Combine(RegistryDir, ProjectKey(projectRoot) + ".json");
        }

        public static void WriteEntry(BrokerMachineEntry entry)
        {
            Directory.CreateDirectory(RegistryDir);
            var path = EntryPath(entry.projectPath);
            var temp = path + "." + Process.GetCurrentProcess().Id + ".tmp";
            File.WriteAllText(temp, JsonUtility.ToJson(entry, true), Utf8NoBom);
            if (File.Exists(path)) File.Replace(temp, path, null);
            else File.Move(temp, path);
        }

        public static void DeleteEntry(string projectRoot)
        {
            var path = EntryPath(projectRoot);
            if (File.Exists(path)) File.Delete(path);
        }

        public static List<BrokerMachineEntry> ReadEntries()
        {
            var entries = new List<BrokerMachineEntry>();
            if (!Directory.Exists(RegistryDir)) return entries;
            foreach (var file in Directory.GetFiles(RegistryDir, "*.json"))
            {
                try
                {
                    var entry = JsonUtility.FromJson<BrokerMachineEntry>(File.ReadAllText(file));
                    if (entry != null) entries.Add(entry);
                }
                catch (Exception)
                {
                    // Being rewritten right now; the next read sees it.
                }
            }
            return entries;
        }

        public static bool IsAlive(BrokerMachineEntry entry, long now, long staleMs)
        {
            if (entry == null || now - entry.heartbeatMs > staleMs) return false;
            try
            {
                Process.GetProcessById(entry.pid);
                return true;
            }
            catch (ArgumentException)
            {
                return false;
            }
        }

        // Runs mutate on the machine settings under a byte-range lock; saves when it returns true.
        public static bool UpdateSettings(Func<BrokerMachineSettings, bool> mutate, int timeoutMs, out string error)
        {
            error = "";
            Directory.CreateDirectory(Dir);
            var lockPath = Path.Combine(Dir, "session-settings.lock");
            var filePath = Path.Combine(Dir, "session-settings.json");
            var timer = Stopwatch.StartNew();
            FileStream stream = null;
            while (stream == null)
            {
                try
                {
                    stream = new FileStream(lockPath, FileMode.OpenOrCreate, FileAccess.ReadWrite, FileShare.ReadWrite | FileShare.Delete);
                    stream.Lock(0, 1);
                }
                catch (IOException)
                {
                    if (stream != null) stream.Dispose();
                    stream = null;
                    if (timer.ElapsedMilliseconds >= timeoutMs)
                    {
                        error = "Machine settings are busy; retry.";
                        return false;
                    }
                    System.Threading.Thread.Sleep(10);
                }
            }
            try
            {
                BrokerMachineSettings settings = null;
                if (File.Exists(filePath))
                {
                    try { settings = JsonUtility.FromJson<BrokerMachineSettings>(File.ReadAllText(filePath)); }
                    catch (Exception) { settings = null; }
                }
                settings = settings ?? new BrokerMachineSettings();
                if (settings.holders == null) settings.holders = new List<BrokerSessionHolder>();
                if (settings.backups == null) settings.backups = new List<BrokerPrefBackup>();
                if (mutate(settings)) File.WriteAllText(filePath, JsonUtility.ToJson(settings, true), Utf8NoBom);
                return true;
            }
            finally
            {
                try { stream.Unlock(0, 1); }
                catch (IOException) { }
                stream.Dispose();
            }
        }
    }
}
