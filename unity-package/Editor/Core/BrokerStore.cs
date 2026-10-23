using System;
using System.Diagnostics;
using System.IO;
using System.Text;
using UnityEngine;

namespace UnityGameAgent.EditorBroker
{
    public static class BrokerClock
    {
        public static Func<long> Override;

        public static long NowMs()
        {
            return Override != null ? Override() : DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
        }
    }

    // State lives in <project>/Library/UgaBroker so it is never imported or committed.
    // Every reader and writer (Editor, CLI, adapters) holds a byte-range lock on state.lock
    // while touching state.json; byte-range locks are released by the OS if a holder dies.
    public sealed class BrokerStore
    {
        static readonly UTF8Encoding Utf8NoBom = new UTF8Encoding(false);

        // Captured on the main thread by the Editor host; background adapters reuse it.
        public static string CurrentProjectRoot = "";

        public readonly string ProjectRoot;
        public readonly string Dir;

        public BrokerStore(string projectRoot)
        {
            ProjectRoot = Path.GetFullPath(projectRoot);
            Dir = Path.Combine(Path.Combine(ProjectRoot, "Library"), "UgaBroker");
        }

        public static BrokerStore ForCurrentProject()
        {
            if (string.IsNullOrEmpty(CurrentProjectRoot))
                CurrentProjectRoot = Path.GetDirectoryName(Application.dataPath);
            return new BrokerStore(CurrentProjectRoot);
        }

        public string StatePath => Path.Combine(Dir, "state.json");
        public string BackupPath => Path.Combine(Dir, "state.json.bak");
        public string LockPath => Path.Combine(Dir, "state.lock");
        public string EditorStatusPath => Path.Combine(Dir, "editor.json");
        public string StagingRoot => Path.Combine(Dir, "staging");

        public string StagingDir(string agent)
        {
            return Path.Combine(StagingRoot, agent);
        }

        public bool TryRead(int timeoutMs, out BrokerState state, out string error)
        {
            return TryUpdate(_ => false, timeoutMs, out state, out error);
        }

        // Runs mutate under the lock; the state is saved only when mutate returns true.
        public bool TryUpdate(Func<BrokerState, bool> mutate, int timeoutMs, out BrokerState state, out string error)
        {
            state = null;
            error = "";
            FileStream lockStream;
            try
            {
                lockStream = AcquireLock(timeoutMs);
            }
            catch (Exception e)
            {
                error = "Cannot open broker lock: " + e.Message;
                return false;
            }
            if (lockStream == null)
            {
                error = "Broker state is busy; retry.";
                return false;
            }
            try
            {
                string recovered;
                state = LoadUnlocked(out recovered);
                var changed = mutate(state);
                if (recovered.Length > 0)
                {
                    BrokerOps.AddViolation(state, BrokerConfig.Default, "", "state-recovered",
                        "state.json was unreadable; recovered from " + recovered + ".", BrokerClock.NowMs());
                    changed = true;
                }
                if (changed) SaveUnlocked(state);
                return true;
            }
            catch (Exception e)
            {
                error = e.Message;
                return false;
            }
            finally
            {
                ReleaseLock(lockStream);
            }
        }

        FileStream AcquireLock(int timeoutMs)
        {
            Directory.CreateDirectory(Dir);
            var timer = Stopwatch.StartNew();
            while (true)
            {
                FileStream stream = null;
                try
                {
                    stream = new FileStream(LockPath, FileMode.OpenOrCreate, FileAccess.ReadWrite,
                        FileShare.ReadWrite | FileShare.Delete);
                    stream.Lock(0, 1);
                    return stream;
                }
                catch (IOException)
                {
                    if (stream != null) stream.Dispose();
                    if (timer.ElapsedMilliseconds >= timeoutMs) return null;
                    System.Threading.Thread.Sleep(10);
                }
            }
        }

        static void ReleaseLock(FileStream stream)
        {
            try { stream.Unlock(0, 1); }
            catch (IOException) { }
            finally { stream.Dispose(); }
        }

        BrokerState LoadUnlocked(out string recovered)
        {
            recovered = "";
            if (!File.Exists(StatePath)) return new BrokerState();
            var state = TryParse(StatePath);
            if (state != null) return state;
            state = File.Exists(BackupPath) ? TryParse(BackupPath) : null;
            recovered = state != null ? "state.json.bak" : "an empty state";
            return state ?? new BrokerState();
        }

        static BrokerState TryParse(string path)
        {
            try
            {
                var text = File.ReadAllText(path, Encoding.UTF8);
                if (string.IsNullOrWhiteSpace(text)) return null;
                var state = JsonUtility.FromJson<BrokerState>(text);
                if (state == null) return null;
                state.Normalize();
                return state;
            }
            catch (Exception)
            {
                return null;
            }
        }

        void SaveUnlocked(BrokerState state)
        {
            state.revision++;
            state.updatedMs = BrokerClock.NowMs();
            WriteAtomic(StatePath, JsonUtility.ToJson(state, true), BackupPath);
        }

        public static BrokerState Parse(string json)
        {
            var state = JsonUtility.FromJson<BrokerState>(json);
            if (state != null) state.Normalize();
            return state;
        }

        public void WriteEditorStatus(BrokerEditorStatus status)
        {
            Directory.CreateDirectory(Dir);
            WriteAtomic(EditorStatusPath, JsonUtility.ToJson(status, true), null);
        }

        public BrokerEditorStatus ReadEditorStatus()
        {
            try
            {
                if (!File.Exists(EditorStatusPath)) return null;
                return JsonUtility.FromJson<BrokerEditorStatus>(File.ReadAllText(EditorStatusPath, Encoding.UTF8));
            }
            catch (Exception)
            {
                return null;
            }
        }

        static void WriteAtomic(string path, string text, string backupPath)
        {
            var temp = path + ".tmp";
            File.WriteAllText(temp, text, Utf8NoBom);
            if (File.Exists(path))
            {
                if (backupPath != null) File.Replace(temp, path, backupPath);
                else File.Replace(temp, path, null);
            }
            else
            {
                File.Move(temp, path);
            }
        }
    }
}
