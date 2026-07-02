# Unity MCP: Install & Enable

This file covers ONLY how to get Unity MCP installed and running. Do not duplicate tool/command
catalogs here: the live MCP server exposes its own tool schemas, and tool usage patterns belong to
the dedicated `unity-mcp-skill`. The provider-neutral workflow (preflight, capability map, fallback)
is in [tools/mcp-provider-neutral.md](tools/mcp-provider-neutral.md).

**Default adapter:** `com.coplaydev.unity-mcp` (CoplayDev / MCP for Unity).

## Install (manifest)

When the project has `Packages/manifest.json` and the adapter is missing, add it to `dependencies`:

```json
"com.coplaydev.unity-mcp": "https://github.com/CoplayDev/unity-mcp.git?path=/MCPForUnity"
```

Rules:

- Parse `manifest.json` as JSON and update the `dependencies` object; no blind string insertion.
- Do not manually edit `Packages/packages-lock.json`; Unity updates it during package resolution.
- Do not add MCP to a non-Unity folder, a package subfolder, or a project without `Packages/manifest.json`.
- After editing the manifest, let Unity resolve packages, then retry MCP detection.

## Enable

Recent adapter versions auto-start the MCP server when the Unity Editor opens the project —
usually nothing to enable manually. If tools are not visible:

1. Check the editor is actually running and finished importing.
2. Unity menu: **Window → MCP for Unity → Start Server** (and check the window for the port/status).
3. Check your MCP client config points at the same host/port.
4. Verify with a session-start read: `mcpforunity://editor/state` (readiness), `mcpforunity://instances`
   (pick one instance when several editors run).

If the editor crashed, a stale `Temp/UnityLockfile` can make relaunches exit instantly — delete it,
then relaunch the project.

If MCP stays unavailable after install/resolve/retry, fall back to file-only mode per
[tools/mcp-provider-neutral.md](tools/mcp-provider-neutral.md) and report the limitation.
