using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Text;
using UnityEditor;
using UnityEngine;

namespace UnityGameAgent.EditorBroker
{
    // Session settings are per-user Editor preferences: applied on 'session start' and restored on
    // 'session stop' from a backup in Library/UgaBroker/settings.json. Project settings live in
    // ProjectSettings/ (tracked) and change only on an explicit 'doctor -Fix' request.
    static class BrokerSettings
    {
        public const string SmokeReason = "epmo-smoke";

        [Serializable]
        sealed class SettingsFile
        {
            public string sessionId = "";
            public string projectSettingsApplied = "";
            public bool epmoChanged;
            public bool epmoEnabledBefore;
            public int epmoOptionsBefore;
            public string projectSettingsNote = "";
            public bool workersSaved;
            public int[] workersBefore = new int[0];
        }

        sealed class Pref
        {
            public string name;
            public bool isBool;
            public int desired;
            public string label;
        }

        // Keys verified against Unity 6 Editor preferences. Values: kAutoRefreshMode 0 = Disabled;
        // ScriptCompilationDuringPlay 1 = Recompile After Finished Playing; InteractionMode 1 = No Throttling.
        static readonly Pref[] SessionPrefs =
        {
            new Pref { name = "kAutoRefreshMode", desired = 0, label = "Auto Refresh: Disabled" },
            new Pref { name = "kAutoRefresh", isBool = true, desired = 0, label = "Auto Refresh (legacy flag): off" },
            new Pref { name = "DirectoryMonitoring", isBool = true, desired = 0, label = "Directory Monitoring: off" },
            new Pref { name = "ScriptCompilationDuringPlay", desired = 1, label = "Script Changes While Playing: Recompile After Finished Playing" },
            new Pref { name = "InteractionMode", desired = 1, label = "Interaction Mode: No Throttling" },
            new Pref { name = "ApplicationIdleTime", desired = 0, label = "Application idle time: 0 ms" }
        };

        // Import workers are separate Unity processes of about 1 GB each. By default Unity keeps two
        // on standby and the rest for a minute after an import, which is what runs a machine with
        // several Editors out of memory. These are per-project user settings (UserSettings/, not
        // tracked), so they are backed up per project rather than reference-counted. Unity 6000.6
        // rejects a standby count of 0 ("Failed to set standby worker count to 0"); 1 is the floor.
        static readonly Pref[] WorkerPrefs =
        {
            new Pref { name = "standbyImportWorkerCount", desired = 1, label = "Standby import workers: 1" },
            new Pref { name = "idleImportWorkerShutdownDelayMilliseconds", desired = 10000, label = "Idle import worker shutdown: 10 s" }
        };

        static PropertyInfo WorkerProperty(Pref pref)
        {
            var property = typeof(EditorUserSettings).GetProperty(pref.name, BindingFlags.Static | BindingFlags.Public);
            return property != null && property.CanWrite && property.PropertyType == typeof(int) ? property : null;
        }

        static void ApplyWorkerPrefs(SettingsFile file)
        {
            // After a crash mid-session the first backup is still the user's own value: keep it.
            if (!file.workersSaved)
            {
                file.workersBefore = WorkerPrefs.Select(p => WorkerProperty(p) != null ? (int)WorkerProperty(p).GetValue(null, null) : -1).ToArray();
                file.workersSaved = true;
            }
            foreach (var pref in WorkerPrefs)
            {
                var property = WorkerProperty(pref);
                if (property != null) property.SetValue(null, pref.desired, null);
            }
        }

        static void RestoreWorkerPrefs(SettingsFile file)
        {
            if (!file.workersSaved) return;
            for (var i = 0; i < WorkerPrefs.Length && i < file.workersBefore.Length; i++)
            {
                var property = WorkerProperty(WorkerPrefs[i]);
                if (property != null && file.workersBefore[i] >= 0) property.SetValue(null, file.workersBefore[i], null);
            }
            file.workersSaved = false;
            file.workersBefore = new int[0];
        }

        static string FilePath(BrokerStore store)
        {
            return Path.Combine(store.Dir, "settings.json");
        }

        static SettingsFile Load(BrokerStore store)
        {
            try
            {
                var path = FilePath(store);
                if (File.Exists(path)) return JsonUtility.FromJson<SettingsFile>(File.ReadAllText(path)) ?? new SettingsFile();
            }
            catch (Exception)
            {
                // A damaged backup file must not stop the broker; the report shows current values.
            }
            return new SettingsFile();
        }

        static void Save(BrokerStore store, SettingsFile file)
        {
            Directory.CreateDirectory(store.Dir);
            File.WriteAllText(FilePath(store), JsonUtility.ToJson(file, true), new UTF8Encoding(false));
        }

        static bool SameProject(string a, string b)
        {
            return string.Equals(a.Replace('\\', '/').TrimEnd('/'), b.Replace('\\', '/').TrimEnd('/'), StringComparison.OrdinalIgnoreCase);
        }

        // A holder whose project has no live broker for ten minutes crashed or was closed mid-session.
        static void PruneHolders(BrokerMachineSettings machine, string self, long now)
        {
            var entries = BrokerMachine.ReadEntries();
            machine.holders.RemoveAll(h => !SameProject(h.projectPath, self) &&
                                           !entries.Any(e => SameProject(e.projectPath, h.projectPath) && BrokerMachine.IsAlive(e, now, 600000)));
        }

        public static void Sync(BrokerStore store, BrokerState state)
        {
            if (state == null) return;
            var file = Load(store);
            var changed = false;
            var now = BrokerClock.NowMs();
            var self = store.ProjectRoot;
            string error;
            if (state.SessionActive && file.sessionId != state.sessionId)
            {
                var ok = BrokerMachine.UpdateSettings(machine =>
                {
                    PruneHolders(machine, self, now);
                    if (machine.holders.Count == 0) machine.backups = SessionPrefs.Select(Backup).ToList();
                    machine.holders.RemoveAll(h => SameProject(h.projectPath, self));
                    machine.holders.Add(new BrokerSessionHolder { projectPath = self, sessionId = state.sessionId, sinceMs = now });
                    return true;
                }, 500, out error);
                if (!ok) return;
                foreach (var pref in SessionPrefs) Write(pref, pref.desired);
                RefreshInteractionMode();
                ApplyWorkerPrefs(file);
                file.sessionId = state.sessionId;
                changed = true;
            }
            else if (!state.SessionActive && file.sessionId.Length > 0)
            {
                List<BrokerPrefBackup> restore = null;
                var ok = BrokerMachine.UpdateSettings(machine =>
                {
                    machine.holders.RemoveAll(h => SameProject(h.projectPath, self));
                    PruneHolders(machine, self, now);
                    if (machine.holders.Count > 0) return true;
                    restore = machine.backups;
                    machine.backups = new List<BrokerPrefBackup>();
                    return true;
                }, 500, out error);
                if (!ok) return;
                // Another project's session still needs the shared preferences: keep them.
                if (restore != null)
                {
                    foreach (var backup in restore) Restore(backup);
                    RefreshInteractionMode();
                }
                RestoreWorkerPrefs(file);
                file.sessionId = "";
                changed = true;
            }
            if (state.projectSettingsRequest.Length > 0 && file.projectSettingsApplied != state.projectSettingsRequest)
            {
                ApplyProjectSettings(store, file, state);
                file.projectSettingsApplied = state.projectSettingsRequest;
                changed = true;
            }
            if (changed) Save(store, file);
        }

        static BrokerPrefBackup Backup(Pref pref)
        {
            return new BrokerPrefBackup
            {
                name = pref.name,
                isBool = pref.isBool,
                existed = EditorPrefs.HasKey(pref.name),
                intValue = pref.isBool ? 0 : EditorPrefs.GetInt(pref.name, 0),
                boolValue = pref.isBool && EditorPrefs.GetBool(pref.name, true)
            };
        }

        static void Write(Pref pref, int value)
        {
            if (pref.isBool) EditorPrefs.SetBool(pref.name, value != 0);
            else EditorPrefs.SetInt(pref.name, value);
        }

        static void Restore(BrokerPrefBackup backup)
        {
            if (!backup.existed)
            {
                EditorPrefs.DeleteKey(backup.name);
                return;
            }
            if (backup.isBool) EditorPrefs.SetBool(backup.name, backup.boolValue);
            else EditorPrefs.SetInt(backup.name, backup.intValue);
        }

        // The Preferences window calls this internal method after changing Interaction Mode.
        static void RefreshInteractionMode()
        {
            var method = typeof(EditorApplication).GetMethod("UpdateInteractionModeSettings",
                BindingFlags.Static | BindingFlags.NonPublic | BindingFlags.Public);
            if (method != null && method.GetParameters().Length == 0) method.Invoke(null, null);
        }

        // Unity 6 decides by the option flags; the old "enabled" toggle no longer reflects them.
        static bool DomainReloadDisabled()
        {
            return (EditorSettings.enterPlayModeOptions & EnterPlayModeOptions.DisableDomainReload) != 0;
        }

        static void ApplyProjectSettings(BrokerStore store, SettingsFile file, BrokerState state)
        {
            var wantedOptions = EditorSettings.enterPlayModeOptions | EnterPlayModeOptions.DisableDomainReload;
            var epmoChanged = !DomainReloadDisabled();
            if (epmoChanged)
            {
                file.epmoEnabledBefore = EditorSettings.enterPlayModeOptionsEnabled;
                file.epmoOptionsBefore = (int)EditorSettings.enterPlayModeOptions;
                file.epmoChanged = true;
                EditorSettings.enterPlayModeOptionsEnabled = true;
                EditorSettings.enterPlayModeOptions = wantedOptions;
            }
            EditorSettings.refreshImportMode = AssetDatabase.RefreshImportMode.OutOfProcessPerQueue;
            file.projectSettingsNote = SaveEditorSettings(state);
            if (!epmoChanged) return;
            // Without domain reload static fields keep their values between plays; one smoke run
            // catches projects that depend on the reset, and a failure rolls the option back.
            BrokerState ignored;
            string error;
            store.TryUpdate(s =>
            {
                var result = BrokerOps.Request(s, BrokerConfig.Default, "broker", BrokerConstants.LaneHot, BrokerConstants.JobSmoke,
                    null, "", "", "", 0.05f, SmokeReason, BrokerClock.NowMs());
                return result.status != "error";
            }, 2000, out ignored, out error);
        }

        // Only AssetDatabase.SaveAssets writes ProjectSettings in Unity 6 (SaveAssetIfDirty and
        // SaveToSerializedFileAndForget leave the file untouched). SaveAssets also saves every other
        // dirty asset, so it runs only while no agent holds a lease; otherwise the change stays in
        // memory until the Editor next saves the project.
        static string SaveEditorSettings(BrokerState state)
        {
            const string path = "ProjectSettings/EditorSettings.asset";
            var now = BrokerClock.NowMs();
            if (state != null && state.leases.Any(l => l.expiresMs > now))
                return "Applied in memory; " + path + " is written when the Editor next saves (agents hold leases, so the broker does not save all assets).";
            AssetDatabase.SaveAssets();
            var text = File.Exists(path) ? File.ReadAllText(path) : "";
            var expected = "m_EnterPlayModeOptions: " + (int)EditorSettings.enterPlayModeOptions;
            return text.Contains(expected) ? path + " saved." : path + " could not be verified after saving.";
        }

        public static void RollbackEnterPlayModeOptions(BrokerStore store, List<string> errors)
        {
            var file = Load(store);
            if (!file.epmoChanged) return;
            EditorSettings.enterPlayModeOptionsEnabled = file.epmoEnabledBefore;
            EditorSettings.enterPlayModeOptions = (EnterPlayModeOptions)file.epmoOptionsBefore;
            file.projectSettingsNote = SaveEditorSettings(BrokerHost.LastState);
            file.epmoChanged = false;
            Save(store, file);
            BrokerHost.QueueViolation("", "settings-rolled-back",
                "Enter Play Mode without domain reload was rolled back: the smoke run logged " + errors.Count +
                " error(s), first: " + (errors.FirstOrDefault() ?? "?") + ". The project relies on static state being reset.");
        }

        static readonly Dictionary<string, bool> s_Assemblies = new Dictionary<string, bool>();

        static bool AssemblyLoaded(string name)
        {
            bool loaded;
            if (s_Assemblies.TryGetValue(name, out loaded)) return loaded;
            loaded = AppDomain.CurrentDomain.GetAssemblies().Any(a => a.GetName().Name == name);
            s_Assemblies[name] = loaded;
            return loaded;
        }

        public static void FillReport(BrokerEditorStatus status)
        {
            var store = BrokerHost.Store;
            var file = Load(store);
            var session = file.sessionId.Length > 0;
            status.sessionId = file.sessionId;
            status.projectSettingsApplied = file.projectSettingsApplied;

            foreach (var pref in SessionPrefs)
            {
                var current = pref.isBool ? (EditorPrefs.GetBool(pref.name, true) ? 1 : 0) : EditorPrefs.GetInt(pref.name, -1);
                status.settings.Add(new BrokerSettingReport
                {
                    name = pref.name, scope = "session", current = current.ToString(), desired = pref.desired.ToString(),
                    ok = !session || current == pref.desired, note = pref.label
                });
            }
            foreach (var pref in WorkerPrefs)
            {
                var property = WorkerProperty(pref);
                var current = property != null ? (int)property.GetValue(null, null) : -1;
                status.settings.Add(new BrokerSettingReport
                {
                    name = pref.name, scope = "session", current = property != null ? current.ToString() : "n/a", desired = pref.desired.ToString(),
                    ok = property == null || !session || current == pref.desired,
                    note = property != null ? pref.label : "Not available in this Unity version."
                });
            }
            var epmoOk = DomainReloadDisabled();
            status.settings.Add(new BrokerSettingReport
            {
                name = "EnterPlayModeOptions", scope = "project",
                current = EditorSettings.enterPlayModeOptions.ToString(),
                desired = "DisableDomainReload", ok = epmoOk,
                note = "Faster Play Mode; the bridge survives. Static fields are not reset between plays. " + file.projectSettingsNote
            });
            status.settings.Add(new BrokerSettingReport
            {
                name = "RefreshImportMode", scope = "project", current = EditorSettings.refreshImportMode.ToString(),
                desired = "OutOfProcessPerQueue", ok = EditorSettings.refreshImportMode == AssetDatabase.RefreshImportMode.OutOfProcessPerQueue,
                note = "Parallel import."
            });
            status.settings.Add(new BrokerSettingReport
            {
                name = "AssetSerialization", scope = "check", current = EditorSettings.serializationMode.ToString(),
                desired = "ForceText", ok = EditorSettings.serializationMode == SerializationMode.ForceText,
                note = "Text assets are required for merges; the broker never changes this."
            });
            status.settings.Add(new BrokerSettingReport
            {
                name = "VersionControlMode", scope = "check", current = VersionControlSettings.mode,
                desired = "Visible Meta Files", ok = VersionControlSettings.mode == "Visible Meta Files",
                note = "Meta files must be visible; the broker never changes this."
            });
            status.settings.Add(new BrokerSettingReport
            {
                name = "RunInBackground", scope = "report", current = PlayerSettings.runInBackground.ToString(),
                desired = "-", ok = true, note = "Affects player builds, so it is reported only."
            });

            var coplay = AssemblyLoaded("MCPForUnity.Editor");
            var http = EditorPrefs.GetBool("MCPForUnity.UseHttpTransport", true);
            status.adapters.Add(new BrokerAdapterReport
            {
                name = "coplay-mcp", present = coplay, ok = !coplay || http,
                note = !coplay ? "Not installed." : http ? "HTTP transport (many clients)." :
                    "stdio transport: every new client disconnects the others. Switch MCP for Unity to HTTP before a multi-agent session."
            });
            var pipeline = AssemblyLoaded("Unity.Pipeline.Editor");
            var portFile = Path.Combine(Path.Combine(store.ProjectRoot, "Library"), Path.Combine("Pipeline", ".unity-pipeline-port"));
            status.adapters.Add(new BrokerAdapterReport
            {
                name = "unity-pipeline", present = pipeline, ok = !pipeline || File.Exists(portFile),
                note = !pipeline ? "Not installed." : File.Exists(portFile) ? "Pipeline server registered for the Unity CLI." : "Pipeline installed but no port file yet."
            });
            status.adapters.Add(new BrokerAdapterReport
            {
                name = "broker-tools", present = AssemblyLoaded("UnityGameAgent.EditorBroker.Coplay") || AssemblyLoaded("UnityGameAgent.EditorBroker.Pipeline"),
                ok = true,
                note = "uga_broker command: " +
                       (AssemblyLoaded("UnityGameAgent.EditorBroker.Coplay") ? "MCP for Unity " : "") +
                       (AssemblyLoaded("UnityGameAgent.EditorBroker.Pipeline") ? "Unity CLI" : "")
            });
            status.adapters.Add(new BrokerAdapterReport
            {
                name = "test-framework", present = BrokerTestHook.Start != null, ok = BrokerTestHook.Start != null,
                note = BrokerTestHook.Start != null ? "Hot test runs available." : "com.unity.test-framework missing: test requests fail."
            });
        }
    }
}
