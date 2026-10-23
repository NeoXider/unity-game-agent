using System;
using System.Text.RegularExpressions;

namespace UnityGameAgent.EditorBroker
{
    // Resource syntax shared with tools/editor-broker.ps1 (see Tests/Editor/broker-vectors.json):
    //   scene:Assets/Levels/Arena.unity   prefab:Assets/UI/Menu.prefab   asset:Assets/Data/Enemy.asset
    //   folder:Assets/UI/                 asmdef:Game.Combat | asmdef:Assets/Combat/Game.Combat.asmdef
    // A folder lease covers everything below it; overlap and coverage ignore case on every platform.
    public static class BrokerPaths
    {
        static readonly Regex AgentPattern = new Regex("^[A-Za-z0-9][A-Za-z0-9._-]{0,47}$");

        public static bool IsValidAgent(string agent)
        {
            return !string.IsNullOrEmpty(agent) && AgentPattern.IsMatch(agent);
        }

        public static bool TryParse(string resource, Func<string, string> asmdefResolver,
            out string type, out string path, out string error)
        {
            type = "";
            path = "";
            error = "";
            if (string.IsNullOrWhiteSpace(resource))
            {
                error = "Resource is empty.";
                return false;
            }
            var separator = resource.IndexOf(':');
            if (separator <= 0)
            {
                error = "Resource must look like type:path (scene, prefab, asset, folder, asmdef).";
                return false;
            }
            type = resource.Substring(0, separator).Trim().ToLowerInvariant();
            var value = resource.Substring(separator + 1).Trim();
            switch (type)
            {
                case "scene":
                    path = NormalizePath(value, false);
                    if (path == null || !path.EndsWith(".unity", StringComparison.OrdinalIgnoreCase))
                        return Fail("A scene resource needs an Assets/ or Packages/ path ending in .unity.", out path, out error);
                    return true;
                case "prefab":
                    path = NormalizePath(value, false);
                    if (path == null || !path.EndsWith(".prefab", StringComparison.OrdinalIgnoreCase))
                        return Fail("A prefab resource needs an Assets/ or Packages/ path ending in .prefab.", out path, out error);
                    return true;
                case "asset":
                    path = NormalizePath(value, false);
                    if (path == null)
                        return Fail("An asset resource needs an Assets/ or Packages/ file path.", out path, out error);
                    return true;
                case "folder":
                    path = NormalizePath(value, true);
                    if (path == null)
                        return Fail("A folder resource needs an Assets/ or Packages/ folder path.", out path, out error);
                    return true;
                case "asmdef":
                    var asmdefPath = value.EndsWith(".asmdef", StringComparison.OrdinalIgnoreCase)
                        ? value
                        : asmdefResolver != null ? asmdefResolver(value) : null;
                    if (string.IsNullOrEmpty(asmdefPath))
                        return Fail("Unknown assembly definition: " + value, out path, out error);
                    var normalized = NormalizePath(asmdefPath, false);
                    if (normalized == null)
                        return Fail("Assembly definition is outside Assets/ or Packages/: " + asmdefPath, out path, out error);
                    var slash = normalized.LastIndexOf('/');
                    path = normalized.Substring(0, slash + 1);
                    return true;
                default:
                    error = "Unknown resource type '" + type + "'. Use scene, prefab, asset, folder or asmdef.";
                    return false;
            }
        }

        static bool Fail(string message, out string path, out string error)
        {
            path = "";
            error = message;
            return false;
        }

        // Returns a project-relative path with forward slashes, or null when the value is not a
        // safe path under Assets/ or Packages/. Folders always end with '/', files never do.
        public static string NormalizePath(string raw, bool folder)
        {
            if (string.IsNullOrWhiteSpace(raw)) return null;
            var value = raw.Trim().Replace('\\', '/');
            while (value.Contains("//")) value = value.Replace("//", "/");
            while (value.StartsWith("./", StringComparison.Ordinal)) value = value.Substring(2);
            var endsWithSlash = value.EndsWith("/", StringComparison.Ordinal);
            if (endsWithSlash && !folder) return null;
            value = value.TrimEnd('/');
            if (value.Length == 0 || value.StartsWith("/", StringComparison.Ordinal) || value.Contains(":")) return null;
            var segments = value.Split('/');
            foreach (var segment in segments)
            {
                if (segment.Length == 0 || segment == "." || segment == "..") return null;
            }
            var root = segments[0];
            if (!root.Equals("Assets", StringComparison.OrdinalIgnoreCase) &&
                !root.Equals("Packages", StringComparison.OrdinalIgnoreCase)) return null;
            if (!folder && segments.Length < 2) return null;
            segments[0] = root.Equals("Assets", StringComparison.OrdinalIgnoreCase) ? "Assets" : "Packages";
            var joined = string.Join("/", segments);
            return folder ? joined + "/" : joined;
        }

        public static bool Overlaps(string a, string b)
        {
            if (string.IsNullOrEmpty(a) || string.IsNullOrEmpty(b)) return false;
            if (string.Equals(a, b, StringComparison.OrdinalIgnoreCase)) return true;
            if (a.EndsWith("/", StringComparison.Ordinal) && b.StartsWith(a, StringComparison.OrdinalIgnoreCase)) return true;
            if (b.EndsWith("/", StringComparison.Ordinal) && a.StartsWith(b, StringComparison.OrdinalIgnoreCase)) return true;
            return false;
        }

        // True when the lease path grants ownership of assetPath (a file or folder).
        public static bool Covers(string leasePath, string assetPath)
        {
            if (string.IsNullOrEmpty(leasePath) || string.IsNullOrEmpty(assetPath)) return false;
            var asset = assetPath.Replace('\\', '/');
            if (string.Equals(leasePath, asset, StringComparison.OrdinalIgnoreCase)) return true;
            if (leasePath.EndsWith("/", StringComparison.Ordinal) && asset.StartsWith(leasePath, StringComparison.OrdinalIgnoreCase)) return true;
            // A .meta file belongs to whoever owns its asset.
            if (asset.EndsWith(".meta", StringComparison.OrdinalIgnoreCase))
                return Covers(leasePath, asset.Substring(0, asset.Length - 5));
            return false;
        }
    }
}
