using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using UnityEditor;
using UnityEditor.Compilation;
using UnityEngine;

namespace UnityGameAgent.EditorBroker
{
    [Serializable]
    public sealed class BrokerCompileMessage
    {
        public string file = "";
        public int line;
        public string assembly = "";
        public string message = "";
    }

    [Serializable]
    public sealed class BrokerCompileLog
    {
        public long startedMs;
        public long finishedMs;
        public List<BrokerCompileMessage> messages = new List<BrokerCompileMessage>();
    }

    // Compile errors are written to disk as they arrive: a successful compile reloads the domain,
    // and the sync window finishes in the new domain by reading this file.
    static class BrokerCompileWatcher
    {
        static BrokerStore s_Store;

        static string LogPath => Path.Combine(s_Store.Dir, "compile.json");

        public static void Register(BrokerStore store)
        {
            s_Store = store;
            CompilationPipeline.compilationStarted += _ => Write(new BrokerCompileLog { startedMs = BrokerClock.NowMs() });
            CompilationPipeline.assemblyCompilationFinished += OnAssemblyFinished;
            CompilationPipeline.compilationFinished += _ =>
            {
                var log = Read(s_Store) ?? new BrokerCompileLog();
                log.finishedMs = BrokerClock.NowMs();
                Write(log);
            };
        }

        static void OnAssemblyFinished(string assemblyPath, CompilerMessage[] messages)
        {
            var log = Read(s_Store) ?? new BrokerCompileLog { startedMs = BrokerClock.NowMs() };
            foreach (var m in messages)
            {
                if (m.type != CompilerMessageType.Error) continue;
                log.messages.Add(new BrokerCompileMessage
                {
                    file = (m.file ?? "").Replace('\\', '/'),
                    line = m.line,
                    assembly = Path.GetFileNameWithoutExtension(assemblyPath),
                    message = m.message
                });
            }
            Write(log);
        }

        public static BrokerCompileLog Read(BrokerStore store)
        {
            try
            {
                var path = Path.Combine(store.Dir, "compile.json");
                return File.Exists(path) ? JsonUtility.FromJson<BrokerCompileLog>(File.ReadAllText(path)) : null;
            }
            catch (Exception)
            {
                return null;
            }
        }

        static void Write(BrokerCompileLog log)
        {
            try
            {
                Directory.CreateDirectory(s_Store.Dir);
                File.WriteAllText(LogPath, JsonUtility.ToJson(log, true), new UTF8Encoding(false));
            }
            catch (IOException)
            {
                // Best effort: the board then reports the failure without per-file attribution.
            }
        }
    }

    // Records errors and exceptions logged during a broker-run Play Mode session to a file, so the
    // record survives the domain reload of entering Play Mode.
    static class BrokerConsoleCapture
    {
        const int MaxLines = 50;
        static BrokerStore s_Store;

        public static void Register(BrokerStore store)
        {
            s_Store = store;
            Application.logMessageReceived += OnLog;
        }

        static string PathFor(BrokerStore store, string jobId)
        {
            return Path.Combine(store.Dir, "console-" + jobId + ".log");
        }

        public static void Reset(BrokerStore store, string jobId)
        {
            Directory.CreateDirectory(store.Dir);
            File.WriteAllText(PathFor(store, jobId), "", new UTF8Encoding(false));
        }

        static void OnLog(string condition, string stackTrace, LogType type)
        {
            if (type != LogType.Error && type != LogType.Exception && type != LogType.Assert) return;
            var state = BrokerHost.LastState;
            if (state == null || !state.HasWindow || state.window.phase != BrokerConstants.PhaseSession) return;
            var path = PathFor(s_Store, state.window.currentJob);
            try
            {
                if (!File.Exists(path)) return;
                if (File.ReadAllLines(path).Length >= MaxLines) return;
                var firstLine = (condition ?? "").Split('\n')[0];
                File.AppendAllText(path, type + ": " + firstLine + Environment.NewLine, new UTF8Encoding(false));
            }
            catch (IOException)
            {
                // Dropping one log line is better than failing the editor's log callback.
            }
        }

        public static List<string> ReadAndDelete(BrokerStore store, string jobId)
        {
            var path = PathFor(store, jobId);
            if (!File.Exists(path)) return new List<string>();
            var lines = new List<string>(File.ReadAllLines(path));
            lines.RemoveAll(string.IsNullOrWhiteSpace);
            File.Delete(path);
            return lines;
        }
    }
}
