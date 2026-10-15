# Unity MCP: Install & Enable

This file covers installing, enabling and safely routing Unity MCP. Do not duplicate tool/command
catalogs here: the live MCP server exposes its own tool schemas, and tool usage patterns belong to
the dedicated `unity-mcp-skill`. The provider-neutral workflow (preflight, capability map, fallback)
is in [tools/mcp-provider-neutral.md](tools/mcp-provider-neutral.md).

**Default adapter:** `com.coplaydev.unity-mcp` (CoplayDev / MCP for Unity).

## Install (manifest)

When the project has `Packages/manifest.json`, the adapter is missing, and installation is
within the authorized task, add it to `dependencies` (preserve an existing pinned version):

```json
"com.coplaydev.unity-mcp": "https://github.com/CoplayDev/unity-mcp.git?path=/MCPForUnity"
```

Rules:

- Parse `manifest.json` as JSON and update the `dependencies` object; no blind string insertion.
- Do not manually edit `Packages/packages-lock.json`; Unity updates it during package resolution.
- Do not add MCP to a non-Unity folder, a package subfolder, or a project without `Packages/manifest.json`.
- After editing the manifest, let Unity resolve packages, then retry MCP detection.

## Enable

Use the installed adapter's **Window → MCP for Unity** window to inspect connection status
and transport. Setup and auto-start behavior vary by version; package resolution alone
does not prove the server or client is connected. If tools are not visible:

1. Check the editor is actually running and finished importing.
2. Inspect the adapter window; start/connect through the controls supplied by that version.
3. Check the selected client's endpoint/transport. Configure only the intended client when
   configuration is authorized; preserve unrelated client settings.
4. Discover live tools/resources. With CoplayDev, read `mcpforunity://instances`, select the
   intended instance if needed, then read `mcpforunity://editor/state`. Use the live schema for
   `set_active_instance`; another adapter may expose different names.

See the official [installation guide](https://coplaydev.github.io/unity-mcp/getting-started/install)
and [multi-instance guide](https://coplaydev.github.io/unity-mcp/guides/multi-instance). Follow the
installed version's UI/schema when they differ from current online examples.

After a crash, inspect the launch log and exact project ownership before removing a suspected
stale `Temp/UnityLockfile`. Remove only a confirmed stale lock with no owning Editor/batch process
within the authorized repair. A lock file alone is not a diagnosis.

If MCP stays unavailable after install/resolve/retry, fall back to file-only mode per
[tools/mcp-provider-neutral.md](tools/mcp-provider-neutral.md) and report the limitation.

## Pin the workspace instance

Each [parallel workspace](tools/parallel-editors.md) runs its own Editor registration/MCP instance.
Read `mcpforunity://instances`, match the workspace project folder name from `.uga-workspace.json`
(`instanceName`) as a candidate, and pin with `set_active_instance`. HTTP instance listing does not
include project paths. Verify with a pinned read-only project-info call or read
`UnityEngine.Application.dataPath`, take its parent directory and compare the normalized absolute root
exactly with the workspace path before any mutation. Pass the verified identifier as `unity_instance`
on every routable call, according to the live tool schema.

Use per-call routing when agents share a client: another agent can change its active instance. Use
separate sessions with independently pinned state for resources that cannot be routed per call; if
state is shared across sessions, serialize selection, read-only verification and the affected call.
Reconnect/re-resolve after an Editor restart. Never mutate an unresolved or foreign instance, and
never substitute the canonical project for a missing workspace instance. Imports, assets, Play Mode
and tests remain serialized by one operator within that workspace, not globally across the machine.
