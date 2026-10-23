using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;

namespace UnityGameAgent.EditorBroker
{
    // Test selection syntax: clauses separated by ';', each "name:Full.Test.Name",
    // "group:<regex on full name>", "category:<category>" or "assembly:<assembly name>".
    // Values of one clause type are alternatives; different clause types must all match,
    // which mirrors a Unity Test Framework Filter.
    public sealed class BrokerTestFilter
    {
        public readonly List<string> names = new List<string>();
        public readonly List<string> groups = new List<string>();
        public readonly List<string> categories = new List<string>();
        public readonly List<string> assemblies = new List<string>();

        public static BrokerTestFilter Parse(string spec, out string error)
        {
            error = "";
            var filter = new BrokerTestFilter();
            if (string.IsNullOrWhiteSpace(spec))
            {
                error = "Test selection is empty.";
                return null;
            }
            foreach (var rawClause in spec.Split(';'))
            {
                var clause = rawClause.Trim();
                if (clause.Length == 0) continue;
                var separator = clause.IndexOf(':');
                var type = separator > 0 ? clause.Substring(0, separator).Trim().ToLowerInvariant() : "name";
                var value = separator > 0 ? clause.Substring(separator + 1).Trim() : clause;
                if (value.Length == 0)
                {
                    error = "Empty value in test clause '" + clause + "'.";
                    return null;
                }
                switch (type)
                {
                    case "name": filter.names.Add(value); break;
                    case "category": filter.categories.Add(value); break;
                    case "assembly": filter.assemblies.Add(value); break;
                    case "group":
                        try { new Regex(value); }
                        catch (ArgumentException e)
                        {
                            error = "Invalid group regex '" + value + "': " + e.Message;
                            return null;
                        }
                        filter.groups.Add(value);
                        break;
                    default:
                        error = "Unknown test clause type '" + type + "'. Use name, group, category or assembly.";
                        return null;
                }
            }
            if (filter.names.Count + filter.groups.Count + filter.categories.Count + filter.assemblies.Count == 0)
            {
                error = "Test selection is empty.";
                return null;
            }
            return filter;
        }

        public bool Matches(string fullName, string assembly, IEnumerable<string> testCategories)
        {
            if (names.Count > 0 && !names.Contains(fullName ?? "")) return false;
            if (groups.Count > 0 && !groups.Any(g => Regex.IsMatch(fullName ?? "", g))) return false;
            if (assemblies.Count > 0 && !assemblies.Contains(assembly ?? "", StringComparer.OrdinalIgnoreCase)) return false;
            if (categories.Count > 0)
            {
                var own = testCategories != null ? testCategories.ToList() : new List<string>();
                if (!categories.Any(c => own.Contains(c))) return false;
            }
            return true;
        }
    }
}
