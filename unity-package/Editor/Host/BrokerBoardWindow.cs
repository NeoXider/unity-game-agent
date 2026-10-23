using System.Collections.Generic;
using System.Linq;
using UnityEditor;
using UnityEngine;

namespace UnityGameAgent.EditorBroker
{
    // The board: one place where humans and agents see who works here, who holds what, what is queued
    // and when it should run, why a window waits and what went wrong. Agents read the same data with
    // 'editor-broker.ps1 status' and 'brief'; the human can post to the team board from here.
    public sealed class BrokerBoardWindow : EditorWindow
    {
        Vector2 m_Scroll;
        double m_NextRepaint;
        BrokerState m_State = new BrokerState();
        BrokerEditorStatus m_Editor;
        List<BrokerBoardEntry> m_Board = new List<BrokerBoardEntry>();
        List<BrokerTelemetry> m_History = new List<BrokerTelemetry>();
        List<BrokerForecastEntry> m_Forecast = new List<BrokerForecastEntry>();
        double m_NextHistory;
        string m_Post = "";
        GUIStyle m_Header;

        [MenuItem("Window/Unity Game Agent/Editor Broker")]
        public static void Open()
        {
            var window = GetWindow<BrokerBoardWindow>();
            window.titleContent = new GUIContent("Editor Broker");
            window.minSize = new Vector2(420, 300);
            window.Show();
        }

        void OnEnable()
        {
            EditorApplication.update += Poll;
            Reload();
        }

        void OnDisable()
        {
            EditorApplication.update -= Poll;
        }

        void Poll()
        {
            if (EditorApplication.timeSinceStartup < m_NextRepaint) return;
            m_NextRepaint = EditorApplication.timeSinceStartup + 1.0;
            Reload();
            Repaint();
        }

        void Reload()
        {
            if (!BrokerHost.Enabled) return;
            BrokerState state;
            string error;
            if (BrokerHost.Store.TryRead(20, out state, out error)) m_State = state;
            m_Editor = BrokerHost.Store.ReadEditorStatus();
            m_Board = BrokerTeam.ReadBoard(BrokerHost.Store);
            if (EditorApplication.timeSinceStartup >= m_NextHistory)
            {
                m_NextHistory = EditorApplication.timeSinceStartup + 10.0;
                m_History = BrokerTeam.History(BrokerHost.Store);
            }
            bool measured;
            m_Forecast = BrokerTeam.Forecast(m_State, m_History, BrokerClock.NowMs(), out measured);
        }

        void OnGUI()
        {
            if (m_Header == null) m_Header = new GUIStyle(EditorStyles.boldLabel) { fontSize = 12 };
            if (!BrokerHost.Enabled)
            {
                EditorGUILayout.HelpBox("The broker host is not running in this process.", MessageType.Warning);
                return;
            }
            var now = BrokerClock.NowMs();
            DrawToolbar();
            m_Scroll = EditorGUILayout.BeginScrollView(m_Scroll);
            DrawSummary(now);
            DrawTeam(now);
            DrawWindow(now);
            DrawLeases(now);
            DrawJobs(now);
            DrawTelemetry(now);
            DrawViolations();
            DrawSettings();
            EditorGUILayout.EndScrollView();
        }

        void DrawToolbar()
        {
            EditorGUILayout.BeginHorizontal(EditorStyles.toolbar);
            if (GUILayout.Button(m_State.paused ? "Resume broker" : "Pause broker", EditorStyles.toolbarButton))
                Mutate(s =>
                {
                    s.paused = !s.paused;
                    BrokerOps.AddViolation(s, BrokerConfig.Default, "human", s.paused ? "paused" : "resumed",
                        s.paused ? "A human paused the broker: no windows open and guards are off." : "A human resumed the broker.", BrokerClock.NowMs());
                });
            if (GUILayout.Button("Run next window now", EditorStyles.toolbarButton)) BrokerHost.RequestForceDue();
            GUILayout.FlexibleSpace();
            if (GUILayout.Button("Open state folder", EditorStyles.toolbarButton)) EditorUtility.RevealInFinder(BrokerHost.Store.StatePath);
            EditorGUILayout.EndHorizontal();
        }

        void DrawSummary(long now)
        {
            GUILayout.Label("Session", m_Header);
            EditorGUILayout.LabelField("Agent session", m_State.SessionActive ? m_State.sessionId + " (" + m_State.sessionOwner + ")" : "none");
            EditorGUILayout.LabelField("Editor", m_Editor == null ? "no heartbeat" : m_Editor.phase + (m_Editor.compileFailed ? "  - COMPILE ERRORS" : ""));
            if (m_Editor != null && m_Editor.dirtyScenes.Count > 0)
                EditorGUILayout.HelpBox("Unsaved scenes: " + string.Join(", ", m_Editor.dirtyScenes), MessageType.Info);
            EditorGUILayout.LabelField("Scheduler", BrokerHost.LastDecision);
            if (m_State.paused) EditorGUILayout.HelpBox("Paused: no windows open and guards are off.", MessageType.Warning);
        }

        void DrawTeam(long now)
        {
            GUILayout.Space(6);
            GUILayout.Label("Team", m_Header);
            var members = m_State.roster.OrderByDescending(m => m.lastSeenMs).ToList();
            if (members.Count == 0) EditorGUILayout.LabelField("No agent has called the broker in this session yet.");
            foreach (var m in members)
                EditorGUILayout.LabelField(m.agent + (m.role.Length > 0 ? " [" + m.role + "]" : ""),
                    "seen " + BrokerBoard.Age(now - m.lastSeenMs) + " ago (" + m.lastCommand + ")" + (m.doing.Length > 0 ? "  - " + m.doing : ""));

            GUILayout.Label("Team board (" + m_Board.Count + " message(s))", EditorStyles.miniBoldLabel);
            foreach (var e in m_Board.Skip(System.Math.Max(0, m_Board.Count - 6)))
                EditorGUILayout.HelpBox(e.id + "  " + e.at + "  " + e.from + " -> " + string.Join(",", e.to.ToArray()) + "\n" + e.text, MessageType.None);
            EditorGUILayout.BeginHorizontal();
            m_Post = EditorGUILayout.TextField(m_Post);
            using (new EditorGUI.DisabledScope(string.IsNullOrWhiteSpace(m_Post)))
            {
                if (GUILayout.Button("Post to agents", GUILayout.Width(110)))
                {
                    var text = m_Post;
                    if (BrokerTeam.CleanText(text).Length > BrokerTeam.MaxMessageChars)
                        ShowNotification(new GUIContent("Longer than " + BrokerTeam.MaxMessageChars + " characters."));
                    else
                    {
                        Mutate(s => BrokerTeam.Post(BrokerHost.Store, s, "human", new List<string> { "all" }, text, BrokerClock.NowMs()));
                        m_Post = "";
                        GUI.FocusControl(null);
                        Reload();
                    }
                }
            }
            using (new EditorGUI.DisabledScope(!System.IO.File.Exists(BrokerTeam.BoardPath(BrokerHost.Store))))
            {
                if (GUILayout.Button("Open", GUILayout.Width(50))) EditorUtility.OpenWithDefaultApp(BrokerTeam.BoardPath(BrokerHost.Store));
            }
            EditorGUILayout.EndHorizontal();
        }

        void DrawWindow(long now)
        {
            GUILayout.Space(6);
            GUILayout.Label("Window", m_Header);
            if (!m_State.HasWindow)
            {
                EditorGUILayout.LabelField("No window: agents work in their leased resources (cold lane).");
                return;
            }
            var w = m_State.window;
            EditorGUILayout.LabelField(w.id, w.lane + " / " + w.phase + (w.holder.Length > 0 ? "  holder " + w.holder : ""));
            EditorGUILayout.LabelField("Jobs", string.Join(", ", w.jobIds));
            if (w.phase == BrokerConstants.PhaseDraining)
            {
                var waiting = BrokerScheduler.Unyielded(m_State, now);
                EditorGUILayout.HelpBox("Draining: waiting for " + (waiting.Count == 0 ? "nobody" : string.Join(", ", waiting)) +
                                        " to yield; starts anyway in " + BrokerBoard.Age(w.drainDeadlineMs - now) + ".", MessageType.Info);
            }
            if (w.deadlineMs > 0 && (w.phase == BrokerConstants.PhaseSession || w.phase == BrokerConstants.PhaseExclusive))
                EditorGUILayout.LabelField("Time box", BrokerBoard.Age(w.deadlineMs - now) + " left");
        }

        void DrawLeases(long now)
        {
            GUILayout.Space(6);
            GUILayout.Label("Leases", m_Header);
            if (m_State.leases.Count == 0) EditorGUILayout.LabelField("(none)");
            foreach (var lease in m_State.leases.OrderBy(l => l.grantedMs).ToList())
            {
                EditorGUILayout.BeginHorizontal();
                EditorGUILayout.LabelField(lease.agent, GUILayout.Width(110));
                EditorGUILayout.LabelField(lease.kind, GUILayout.Width(45));
                EditorGUILayout.LabelField(lease.path + (lease.yielded ? "  (yielded)" : "") + "  " + BrokerBoard.Age(lease.expiresMs - now));
                if (GUILayout.Button("Release", GUILayout.Width(64)) &&
                    EditorUtility.DisplayDialog("Force release", "Release " + lease.path + " held by " + lease.agent + "?", "Release", "Cancel"))
                    Mutate(s =>
                    {
                        BrokerOps.Release(s, lease.agent, lease.path);
                        BrokerOps.AddViolation(s, BrokerConfig.Default, lease.agent, "forced-release",
                            "A human released " + lease.path + ".", BrokerClock.NowMs());
                    });
                EditorGUILayout.EndHorizontal();
            }
            if (m_State.waiting.Count > 0)
            {
                GUILayout.Label("Waiting (first come, first served)", EditorStyles.miniBoldLabel);
                foreach (var w in m_State.waiting) EditorGUILayout.LabelField(w.agent, w.kind + "  " + w.path);
            }
        }

        void DrawJobs(long now)
        {
            GUILayout.Space(6);
            GUILayout.Label("Queues", m_Header);
            foreach (var lane in new[] { BrokerConstants.LaneSync, BrokerConstants.LaneExclusive, BrokerConstants.LaneHot })
            {
                var jobs = m_State.jobs.Where(j => j.lane == lane && !j.IsFinished).OrderBy(j => j.createdMs).ToList();
                EditorGUILayout.LabelField(lane, jobs.Count == 0 ? "empty" : jobs.Count + " waiting or running");
                foreach (var job in jobs)
                {
                    var eta = m_Forecast.FirstOrDefault(f => f.jobId == job.id);
                    EditorGUILayout.LabelField("   " + job.id + " " + job.agent, job.kind + " " + job.status + "  " + BrokerBoard.Age(now - job.createdMs) +
                                                                                (job.tests.Length > 0 ? "  " + job.tests : "") + (job.reason.Length > 0 ? "  " + job.reason : "") +
                                                                                (eta != null ? "  ~done in " + BrokerBoard.Age(eta.doneMs - now) : ""));
                }
            }
            var finished = m_State.jobs.Where(j => j.IsFinished).OrderByDescending(j => j.finishedMs).Take(8).ToList();
            if (finished.Count == 0) return;
            GUILayout.Label("Recent results", EditorStyles.miniBoldLabel);
            foreach (var job in finished)
            {
                var type = job.status == BrokerConstants.JobPassed ? MessageType.None
                    : job.status == BrokerConstants.JobBlocked ? MessageType.Warning : MessageType.Error;
                EditorGUILayout.HelpBox(job.id + " " + job.agent + " " + job.lane + "/" + job.kind + ": " + job.status + " - " + job.summary, type);
            }
        }

        // Live counters of this segment; the project history is in 'editor-broker.ps1 stats'.
        void DrawTelemetry(long now)
        {
            var t = m_State.telemetry;
            if (t == null || t.sinceMs == 0) return;
            GUILayout.Space(6);
            GUILayout.Label("Telemetry (" + BrokerBoard.Age(now - t.sinceMs) + ")", m_Header);
            EditorGUILayout.LabelField("Jobs", t.jobs + " (" + t.failed + " failed, " + t.blocked + " blocked); wait avg " +
                                               BrokerBoard.Age(t.jobs > 0 ? t.waitMs / t.jobs : 0) + ", max " + BrokerBoard.Age(t.waitMaxMs));
            EditorGUILayout.LabelField("Queue", "avg " + BrokerTelemetryOps.AverageQueue(t, now).ToString("0.00") + ", peak " + t.queuePeak +
                                                "; lease waiters avg " + BrokerTelemetryOps.AverageWaiters(t, now).ToString("0.00") + ", peak " + t.waitersPeak);
            EditorGUILayout.LabelField("Windows", t.windows + "; run avg " + BrokerBoard.Age(t.windows > 0 ? t.windowMs / t.windows : 0) +
                                                  ", drain avg " + BrokerBoard.Age(t.windows > 0 ? t.drainMs / t.windows : 0));
            foreach (var a in t.agents.OrderBy(a => a.agent))
                EditorGUILayout.LabelField("   " + a.agent, a.jobs + " job(s), wait avg " + BrokerBoard.Age(a.jobs > 0 ? a.waitMs / a.jobs : 0) +
                                                             ", max " + BrokerBoard.Age(a.waitMaxMs) + "; lease waits " + a.leaseWaits);
        }

        void DrawViolations()
        {
            if (m_State.violations.Count == 0) return;
            GUILayout.Space(6);
            GUILayout.Label("Protocol notes", m_Header);
            foreach (var v in m_State.violations.Skip(System.Math.Max(0, m_State.violations.Count - 8)))
                EditorGUILayout.HelpBox(v.kind + (v.agent.Length > 0 ? " [" + v.agent + "]" : "") + ": " + v.detail, MessageType.Warning);
        }

        void DrawSettings()
        {
            if (m_Editor == null) return;
            GUILayout.Space(6);
            GUILayout.Label("Settings and adapters", m_Header);
            foreach (var setting in m_Editor.settings)
                EditorGUILayout.LabelField((setting.ok ? "OK  " : "FIX ") + setting.name, setting.scope + ": " + setting.current + " (wanted " + setting.desired + ")");
            foreach (var adapter in m_Editor.adapters)
                EditorGUILayout.LabelField((adapter.ok ? "OK  " : "FIX ") + adapter.name, adapter.note);
        }

        void Mutate(System.Action<BrokerState> change)
        {
            BrokerState state;
            string error;
            if (BrokerHost.Store.TryUpdate(s =>
                {
                    change(s);
                    return true;
                }, 500, out state, out error))
                m_State = state;
            else
                ShowNotification(new GUIContent(error));
        }
    }
}
