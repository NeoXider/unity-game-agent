using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using UnityEngine;

namespace UnityGameAgent.EditorBroker
{
    public sealed class BrokerLaneAverage
    {
        public long runMs;
        public long drainMs;
        public long waitMs;
        public bool measured;
    }

    public sealed class BrokerForecastEntry
    {
        public string jobId = "";
        public string agent = "";
        public string lane = "";
        public string kind = "";
        public int order;       // 0: the active window; 1, 2, ...: planned windows in run order
        public long startMs;
        public long doneMs;
    }

    public sealed class BrokerBoardEntry
    {
        public string id = "";
        public long number;
        public string at = "";
        public string from = "";
        public List<string> to = new List<string>();
        public string text = "";
    }

    // Lets agents know about each other: the roster of agents that called the broker, a rough ETA
    // for queued work and the team board (Library/UgaBroker/team-board.md). tools/editor-broker.ps1
    // implements the same rules (brief, say); Tests/Editor/broker-vectors.json keeps them identical.
    public static class BrokerTeam
    {
        public const long RosterTtlMs = 7200000;
        public const long ActiveMs = 600000;
        public const int MaxMessageChars = 300;     // short notes; details go in a linked file
        public const int MaxRoleChars = 32;
        public const int MaxDoingChars = 120;
        public const int BriefMessages = 5;
        public const int MessageLineChars = 160;    // one brief line per message
        public const string BoardFileName = "team-board.md";

        public const string BoardHeader =
            "# Team board\n\n" +
            "Notes between the agents of this project, oldest first. Post with\n" +
            "`editor-broker.ps1 say -Agent <you> -Message \"...\" [-To <agent>]`; `brief` shows what is new for you.\n" +
            "Post through the broker (it appends under the state lock) instead of editing this file.\n\n";

        static readonly Regex EntryHeader = new Regex(@"^### M(\d{1,18}) (\d{4}-\d\d-\d\d \d\d:\d\d:\d\dZ) (\S+) -> (\S+)\s*$");
        static readonly Regex Spaces = new Regex(@"\s+");
        static readonly Regex LineEnds = new Regex("\r\n?");
        static readonly UTF8Encoding Utf8NoBom = new UTF8Encoding(false);

        // ------------------------------------------------------------ roster

        public static string OneLine(string text, int max)
        {
            if (string.IsNullOrWhiteSpace(text)) return "";
            var line = Spaces.Replace(text, " ").Trim();
            return line.Length > max ? line.Substring(0, max).TrimEnd() : line;
        }

        public static bool Busy(BrokerState state, string agent, long now)
        {
            return state.leases.Any(l => l.expiresMs > now && BrokerOps.SameAgent(l.agent, agent)) ||
                   state.waiting.Any(w => w.expiresMs > now && BrokerOps.SameAgent(w.agent, agent)) ||
                   state.jobs.Any(j => (j.status == BrokerConstants.JobQueued || j.status == BrokerConstants.JobRunning) &&
                                       BrokerOps.SameAgent(j.agent, agent));
        }

        // Records that an agent called the broker. Agents quiet for longer than the roster TTL that
        // hold nothing drop out, so the roster lists the agents of the current work.
        public static BrokerMember Touch(BrokerState state, string agent, string command, long now, string role = "", string doing = "")
        {
            var member = state.roster.FirstOrDefault(m => BrokerOps.SameAgent(m.agent, agent));
            if (member == null)
            {
                member = new BrokerMember { agent = agent, firstSeenMs = now };
                state.roster.Add(member);
            }
            member.lastSeenMs = now;
            member.lastCommand = command ?? "";
            var roleLine = OneLine(role, MaxRoleChars);
            if (roleLine.Length > 0) member.role = roleLine;
            var doingLine = OneLine(doing, MaxDoingChars);
            if (doingLine.Length > 0) member.doing = doingLine;
            var cutoff = now - RosterTtlMs;
            state.roster.RemoveAll(m => m.lastSeenMs <= cutoff && !BrokerOps.SameAgent(m.agent, agent) && !Busy(state, m.agent, now));
            return member;
        }

        // ------------------------------------------------------------ forecast

        // Guesses for a lane without telemetry yet; the sync and exclusive waits are the scheduler's maximum.
        public static Dictionary<string, BrokerLaneAverage> DefaultAverages()
        {
            return new Dictionary<string, BrokerLaneAverage>
            {
                { BrokerConstants.LaneSync, new BrokerLaneAverage { runMs = 30000, drainMs = 10000, waitMs = 30000 } },
                { BrokerConstants.LaneHot, new BrokerLaneAverage { runMs = 60000, drainMs = 10000, waitMs = 120000 } },
                { BrokerConstants.LaneExclusive, new BrokerLaneAverage { runMs = 0, drainMs = 10000, waitMs = 120000 } }
            };
        }

        // Sums the per-lane counters of telemetry segments (closed history plus the live one).
        public static List<BrokerLaneStats> LaneTotals(IEnumerable<BrokerTelemetry> segments)
        {
            var totals = new List<BrokerLaneStats>();
            foreach (var segment in segments.Where(s => s != null && s.lanes != null))
            {
                foreach (var l in segment.lanes.Where(l => l != null && !string.IsNullOrEmpty(l.lane)))
                {
                    var t = totals.FirstOrDefault(x => x.lane == l.lane);
                    if (t == null)
                    {
                        t = new BrokerLaneStats { lane = l.lane };
                        totals.Add(t);
                    }
                    t.jobs += l.jobs;
                    t.waitMs += l.waitMs;
                    t.windows += l.windows;
                    t.windowMs += l.windowMs;
                    t.drainMs += l.drainMs;
                }
            }
            return totals;
        }

        // Average window run, drain and job wait per lane; a lane without data keeps the defaults.
        public static Dictionary<string, BrokerLaneAverage> LaneAverages(IEnumerable<BrokerLaneStats> lanes)
        {
            var averages = DefaultAverages();
            foreach (var l in lanes)
            {
                BrokerLaneAverage a;
                if (l == null || !averages.TryGetValue(l.lane ?? "", out a)) continue;
                if (l.windows > 0)
                {
                    a.runMs = l.windowMs / l.windows;
                    a.drainMs = l.drainMs / l.windows;
                    a.measured = true;
                }
                if (l.jobs > 0) a.waitMs = l.waitMs / l.jobs;
            }
            return averages;
        }

        static bool IsBatchJob(string lane, BrokerJob job)
        {
            return lane == BrokerConstants.LaneSync || (lane == BrokerConstants.LaneHot && job.kind == BrokerConstants.JobTests);
        }

        static long DurationMs(BrokerJob job, BrokerLaneAverage average)
        {
            if (job.kind == BrokerConstants.JobExclusive && average.measured) return average.runMs;
            return (long)Math.Round(job.minutes * 60000.0);
        }

        static BrokerForecastEntry Entry(BrokerJob job, int order, long start, long done)
        {
            return new BrokerForecastEntry
            {
                jobId = job.id, agent = job.agent, lane = job.lane, kind = job.kind, order = order, startMs = start, doneMs = done
            };
        }

        // Adds the jobs of one window, in run order, and returns when the window ends. The sync jobs and
        // the tests of a hot window run as one batch; sessions and exclusive work follow one by one. A
        // job that has started keeps its start and ends no earlier than now.
        static long AddWindow(List<BrokerForecastEntry> forecast, string lane, List<BrokerJob> jobs, long cursor,
            Dictionary<string, BrokerLaneAverage> averages, int order, long now)
        {
            var avg = averages[lane];
            var batch = jobs.Where(j => IsBatchJob(lane, j)).ToList();
            if (batch.Count > 0)
            {
                var started = batch.Where(j => j.startedMs > 0).Select(j => j.startedMs).DefaultIfEmpty(0).Min();
                var start = started > 0 ? started : cursor;
                var done = started > 0 ? Math.Max(now, started + avg.runMs) : cursor + avg.runMs;
                foreach (var j in batch) forecast.Add(Entry(j, order, start, done));
                cursor = done;
            }
            foreach (var j in jobs.Where(j => !IsBatchJob(lane, j)))
            {
                var duration = DurationMs(j, avg);
                long start, done;
                if (j.startedMs > 0)
                {
                    start = j.startedMs;
                    done = Math.Max(now, start + duration);
                }
                else
                {
                    start = cursor;
                    done = cursor + duration;
                }
                forecast.Add(Entry(j, order, start, done));
                cursor = done;
            }
            return cursor;
        }

        // A planned window opens after the previous one plus a drain, and not before its oldest job is
        // as old as the lane's average wait (which folds in how long agents take to yield).
        static long AddPlanned(List<BrokerForecastEntry> forecast, string lane, List<BrokerJob> jobs, long cursor,
            Dictionary<string, BrokerLaneAverage> averages, int order, long now)
        {
            var avg = averages[lane];
            var oldest = jobs.Min(j => j.createdMs);
            var start = Math.Max(cursor + avg.drainMs, oldest + avg.waitMs);
            return AddWindow(forecast, lane, jobs, start, averages, order, now);
        }

        // Rough plan of the queue in the scheduler's order: the active window (order 0), one sync window
        // for every staged change, each exclusive request, then one hot window (tests first, then
        // sessions). Jobs queued later can still go first (a new sync request opens before waiting hot work).
        public static List<BrokerForecastEntry> Forecast(BrokerState state, Dictionary<string, BrokerLaneAverage> averages, long now)
        {
            var forecast = new List<BrokerForecastEntry>();
            var cursor = now;
            var taken = new HashSet<string>();
            if (state.HasWindow && averages.ContainsKey(state.window.lane))
            {
                var w = state.window;
                var inWindow = new List<BrokerJob>();
                foreach (var id in w.jobIds)
                {
                    taken.Add(id);
                    var job = state.jobs.FirstOrDefault(j => j.id == id);
                    if (job != null && (job.status == BrokerConstants.JobQueued || job.status == BrokerConstants.JobRunning)) inWindow.Add(job);
                }
                if (w.startedMs <= 0)
                {
                    var drain = averages[w.lane].drainMs;
                    var deadline = w.drainDeadlineMs > 0 ? w.drainDeadlineMs : w.requestedMs + drain;
                    cursor = Math.Max(now, Math.Min(deadline, w.requestedMs + drain));
                }
                cursor = AddWindow(forecast, w.lane, inWindow, cursor, averages, 0, now);
            }
            var queued = state.jobs.Where(j => j.status == BrokerConstants.JobQueued && !taken.Contains(j.id)).OrderBy(j => j.createdMs).ToList();
            var order = 0;
            var sync = queued.Where(j => j.lane == BrokerConstants.LaneSync).ToList();
            if (sync.Count > 0) cursor = AddPlanned(forecast, BrokerConstants.LaneSync, sync, cursor, averages, ++order, now);
            foreach (var e in queued.Where(j => j.lane == BrokerConstants.LaneExclusive).ToList())
                cursor = AddPlanned(forecast, BrokerConstants.LaneExclusive, new List<BrokerJob> { e }, cursor, averages, ++order, now);
            var hot = queued.Where(j => j.lane == BrokerConstants.LaneHot && j.kind == BrokerConstants.JobTests)
                .Concat(queued.Where(j => j.lane == BrokerConstants.LaneHot && j.kind != BrokerConstants.JobTests))
                .ToList();
            if (hot.Count > 0) AddPlanned(forecast, BrokerConstants.LaneHot, hot, cursor, averages, ++order, now);
            return forecast;
        }

        // Telemetry history (telemetry.jsonl); the live segment is in the state.
        public static List<BrokerTelemetry> History(BrokerStore store)
        {
            var segments = new List<BrokerTelemetry>();
            var file = Path.Combine(store.Dir, "telemetry.jsonl");
            if (!File.Exists(file)) return segments;
            try
            {
                foreach (var line in File.ReadAllLines(file))
                {
                    if (string.IsNullOrWhiteSpace(line)) continue;
                    try
                    {
                        var segment = JsonUtility.FromJson<BrokerTelemetry>(line);
                        if (segment != null) segments.Add(segment);
                    }
                    catch (Exception)
                    {
                        // A torn line cannot count; keep the rest.
                    }
                }
            }
            catch (IOException)
            {
                // The host may be appending right now; the forecast falls back to the live segment.
            }
            return segments;
        }

        public static List<BrokerForecastEntry> Forecast(BrokerState state, IEnumerable<BrokerTelemetry> history, long now, out bool measured)
        {
            var averages = LaneAverages(LaneTotals(history.Concat(new[] { state.telemetry })));
            measured = averages.Values.Any(a => a.measured);
            return Forecast(state, averages, now);
        }

        // ------------------------------------------------------------ team board

        // LF line ends, no blank edges, and no line that would start a Markdown heading (or a new entry).
        public static string CleanText(string text)
        {
            var lines = LineEnds.Replace(text ?? "", "\n").Trim().Split('\n');
            return string.Join("\n", lines.Select(l => l.StartsWith("#", StringComparison.Ordinal) ? "\\" + l.TrimEnd() : l.TrimEnd()).ToArray());
        }

        public static string FormatEntry(long number, long now, string from, IList<string> to, string text)
        {
            var at = DateTimeOffset.FromUnixTimeMilliseconds(now).UtcDateTime.ToString("yyyy-MM-dd HH:mm:ss", CultureInfo.InvariantCulture);
            return "### M" + number + " " + at + "Z " + from + " -> " + string.Join(",", to.ToArray()) + "\n" + CleanText(text) + "\n\n";
        }

        public static List<BrokerBoardEntry> ParseBoard(string text)
        {
            var entries = new List<BrokerBoardEntry>();
            if (string.IsNullOrEmpty(text)) return entries;
            BrokerBoardEntry current = null;
            var body = new List<string>();
            foreach (var raw in text.Split('\n'))
            {
                var line = raw.TrimEnd('\r');
                var m = EntryHeader.Match(line);
                if (m.Success)
                {
                    if (current != null)
                    {
                        current.text = string.Join("\n", body.ToArray()).Trim();
                        entries.Add(current);
                    }
                    current = new BrokerBoardEntry
                    {
                        id = "M" + m.Groups[1].Value, number = long.Parse(m.Groups[1].Value, CultureInfo.InvariantCulture),
                        at = m.Groups[2].Value, from = m.Groups[3].Value,
                        to = m.Groups[4].Value.Split(',').Where(t => t.Length > 0).ToList()
                    };
                    body = new List<string>();
                    continue;
                }
                if (current != null) body.Add(line);
            }
            if (current != null)
            {
                current.text = string.Join("\n", body.ToArray()).Trim();
                entries.Add(current);
            }
            return entries;
        }

        public static bool IsFor(BrokerBoardEntry entry, string agent)
        {
            if (BrokerOps.SameAgent(entry.from, agent)) return false;
            return entry.to.Any(t => string.Equals(t, "all", StringComparison.OrdinalIgnoreCase) || BrokerOps.SameAgent(t, agent));
        }

        public static List<BrokerBoardEntry> Unread(IEnumerable<BrokerBoardEntry> entries, long readId, string agent)
        {
            return entries.Where(e => e.number > readId && IsFor(e, agent)).ToList();
        }

        public static string BoardPath(BrokerStore store)
        {
            return Path.Combine(store.Dir, BoardFileName);
        }

        public static List<BrokerBoardEntry> ReadBoard(BrokerStore store)
        {
            try
            {
                var path = BoardPath(store);
                return File.Exists(path) ? ParseBoard(File.ReadAllText(path, Encoding.UTF8)) : new List<BrokerBoardEntry>();
            }
            catch (IOException)
            {
                return new List<BrokerBoardEntry>();
            }
        }

        public static int UnreadCount(BrokerStore store, BrokerState state, string agent)
        {
            var member = state.roster.FirstOrDefault(m => BrokerOps.SameAgent(m.agent, agent));
            return Unread(ReadBoard(store), member != null ? member.readId : 0, agent).Count;
        }

        // Call inside BrokerStore.TryUpdate: the id comes from the state and the append runs under its lock.
        public static string Post(BrokerStore store, BrokerState state, string from, IList<string> to, string text, long now)
        {
            var path = BoardPath(store);
            var id = state.NewId("M");
            var entry = FormatEntry(long.Parse(id.Substring(1), CultureInfo.InvariantCulture), now, from, to, text);
            Directory.CreateDirectory(store.Dir);
            File.AppendAllText(path, File.Exists(path) ? entry : BoardHeader + entry, Utf8NoBom);
            return id;
        }

        // Splits "a,b;c" into recipients; empty or "all" anywhere means everyone. Returns null when a
        // name is invalid.
        public static List<string> Recipients(string to, out string error)
        {
            error = "";
            var names = (to ?? "").Split(new[] { ',', ';' }, StringSplitOptions.RemoveEmptyEntries)
                .Select(t => t.Trim()).Where(t => t.Length > 0).ToList();
            if (names.Count == 0 || names.Any(t => string.Equals(t, "all", StringComparison.OrdinalIgnoreCase)))
                return new List<string> { "all" };
            var bad = names.FirstOrDefault(t => !BrokerPaths.IsValidAgent(t));
            if (bad == null) return names;
            error = "Invalid recipient '" + bad + "': use agent names or all.";
            return null;
        }

        // ------------------------------------------------------------ brief

        // Short job name for the brief: "sync", "hot/tests", "hot/session 3 min", "exclusive".
        static string JobShort(BrokerJob job)
        {
            if (job == null) return "";
            var name = job.lane == job.kind ? job.lane : job.lane + "/" + job.kind;
            if (job.kind == BrokerConstants.JobSession) name += " " + job.minutes.ToString(CultureInfo.InvariantCulture) + " min";
            return name;
        }

        // One line of at most `max` characters: line breaks become " / ".
        public static string Clip(string text, int max)
        {
            var line = string.Join(" / ", (text ?? "").Split('\n').Select(l => l.Trim()).Where(l => l.Length > 0).ToArray());
            return line.Length > max ? line.Substring(0, max - 3).TrimEnd() + "..." : line;
        }

        static List<string> Names(BrokerState state)
        {
            var names = new List<string>();
            Action<string> add = n =>
            {
                if (!string.IsNullOrEmpty(n) && !names.Any(x => BrokerOps.SameAgent(x, n))) names.Add(n);
            };
            foreach (var m in state.roster) add(m.agent);
            foreach (var l in state.leases) add(l.agent);
            foreach (var w in state.waiting) add(w.agent);
            foreach (var j in state.jobs.Where(j => j.status == BrokerConstants.JobQueued || j.status == BrokerConstants.JobRunning)) add(j.agent);
            return names;
        }

        // Everything one agent needs before its next step, kept short because it lands in the agent's
        // context: who else works here, the queue with a rough ETA, what blocks it and what is new on the
        // team board. Call inside TryUpdate: it records the agent and marks the board as read for it.
        public static string Brief(BrokerStore store, BrokerState state, BrokerEditorStatus editor, IEnumerable<BrokerTelemetry> history,
            string agent, long now, string role, string doing)
        {
            bool measured;
            var forecast = Forecast(state, history, now, out measured);
            var member = Touch(state, agent, "brief", now, role, doing);
            var entries = ReadBoard(store);
            var unread = Unread(entries, member.readId, agent);
            var othersNew = entries.Count(e => e.number > member.readId && !BrokerOps.SameAgent(e.from, agent) && !IsFor(e, agent));
            foreach (var e in entries) member.readId = Math.Max(member.readId, e.number);

            var text = new StringBuilder();
            var session = state.SessionActive ? "session " + state.sessionId + " (owner " + state.sessionOwner + ")" : "no session";
            var editorText = editor == null ? "Editor offline" : "Editor " + editor.phase + (editor.compileFailed ? ", COMPILE ERRORS" : "");
            text.AppendLine("Brief for " + agent + ": " + session + ", " + editorText + (state.paused ? ", broker PAUSED" : "") + ".");

            var names = Names(state);
            text.AppendLine("Team (" + names.Count + "):");
            foreach (var name in names)
            {
                var m = state.roster.FirstOrDefault(x => BrokerOps.SameAgent(x.agent, name));
                var you = BrokerOps.SameAgent(name, agent);
                var seenMs = m != null ? m.lastSeenMs : 0;
                var line = "  " + name + (you ? " [you]" : m != null && m.role.Length > 0 ? " [" + m.role + "]" : "");
                if (!you) line += seenMs > 0 ? " " + BrokerBoard.Age(now - seenMs) + " ago" : " not seen";
                if (!((seenMs > 0 && now - seenMs <= ActiveMs) || Busy(state, name, now))) line += " (quiet)";
                if (m != null && m.doing.Length > 0) line += ": " + m.doing;
                var leases = state.leases.Where(l => l.expiresMs > now && BrokerOps.SameAgent(l.agent, name))
                    .Select(l => l.kind + " " + l.path + (l.yielded ? " (yielded)" : "")).ToList();
                if (leases.Count > 0) line += " | " + string.Join(", ", leases.Take(3).ToArray()) + (leases.Count > 3 ? " +" + (leases.Count - 3) : "");
                var jobs = state.jobs.Where(j => (j.status == BrokerConstants.JobQueued || j.status == BrokerConstants.JobRunning) && BrokerOps.SameAgent(j.agent, name))
                    .Select(j => j.id + " " + JobShort(j) + (j.status == BrokerConstants.JobRunning ? " running" : "")).ToList();
                if (jobs.Count > 0) line += " | " + string.Join(", ", jobs.ToArray());
                text.AppendLine(line);
            }

            var unyielded = new List<string>();
            if (state.HasWindow)
            {
                var w = state.window;
                if (w.phase == BrokerConstants.PhaseDraining) unyielded = BrokerScheduler.Unyielded(state, now);
                text.AppendLine("Window: " + w.id + " " + w.lane + "/" + w.phase + (w.holder.Length > 0 ? " for " + w.holder : "") +
                                (unyielded.Count > 0 ? ", waits for " + string.Join(", ", unyielded.ToArray()) + " to yield" : "") + ".");
            }

            if (forecast.Count > 0)
            {
                text.AppendLine("Queue (start -> done, " + (measured ? "ETA from telemetry" : "ETA from defaults, no telemetry yet") + "):");
                foreach (var f in forecast)
                {
                    var start = f.startMs <= now ? "running" : "~" + BrokerBoard.Age(f.startMs - now);
                    text.AppendLine("  " + (f.order == 0 ? "now" : "#" + f.order) + " " + f.jobId + " " + f.agent + " " +
                                    JobShort(state.jobs.FirstOrDefault(j => j.id == f.jobId)) + ": " + start + " -> ~" + BrokerBoard.Age(f.doneMs - now) +
                                    (BrokerOps.SameAgent(f.agent, agent) ? " <- yours" : ""));
                }
            }
            else text.AppendLine("Queue: empty.");

            var mine = new List<string>();
            for (var i = 0; i < state.waiting.Count; i++)
            {
                var w = state.waiting[i];
                if (!BrokerOps.SameAgent(w.agent, agent)) continue;
                var behind = BrokerOps.Blockers(state, w, i, now);
                mine.Add("waiting " + w.id + " " + w.path + " #" + (i + 1) + (behind.Count > 0 ? " behind " + string.Join(", ", behind.ToArray()) : ""));
            }
            foreach (var l in state.leases.Where(l => l.expiresMs > now && l.expiresMs - now < 120000 && BrokerOps.SameAgent(l.agent, agent)))
                mine.Add(l.path + " expires in " + BrokerBoard.Age(l.expiresMs - now) + ", renew");
            if (mine.Count > 0) text.AppendLine("You: " + string.Join("; ", mine.ToArray()) + ".");

            text.AppendLine("Board: " + unread.Count + " new, " + othersNew + " other, " + entries.Count + " total (Library/UgaBroker/" + BoardFileName + ").");
            if (unread.Count > BriefMessages) text.AppendLine("  (" + (unread.Count - BriefMessages) + " older new in the file)");
            foreach (var e in unread.Skip(Math.Max(0, unread.Count - BriefMessages)))
                text.AppendLine("  " + e.id + " " + e.from + "->" + string.Join(",", e.to.ToArray()) + ": " + Clip(e.text, MessageLineChars));

            var next = new List<string>();
            if (unyielded.Any(a => BrokerOps.SameAgent(a, agent))) next.Add("save and yield, " + state.window.id + " waits for you");
            if (forecast.Any(f => BrokerOps.SameAgent(f.agent, agent))) next.Add("keep working, your jobs run without you");
            if (unread.Count > 0) next.Add("reply with say -To <agent> if needed");
            if (next.Count > 0) text.AppendLine("Next: " + string.Join("; ", next.ToArray()) + ".");
            return text.ToString().TrimEnd();
        }
    }
}
