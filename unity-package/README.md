# Unity Game Agent - Editor Broker

`com.neoxider.uga-editor-broker` lets several AI agents work in **one** Unity Editor without
stepping on each other. Unity 6 (6000.0) or newer. Editor-only: nothing ships in player builds.

- **Leases** on scenes, prefabs, assets, folders and assemblies; a focus token for scene-graph edits.
- **Sync window**: every agent's staged scripts and heavy assets are published, imported and
  compiled once; compile errors go to the agent that wrote them.
- **Hot window**: queued test selections run in one Test Runner execution per mode, then Play Mode
  sessions one by one; cold work keeps priority.
- **Exclusive window** for packages, ProjectSettings, builds and merges.
- **Board**: Window > Unity Game Agent > Editor Broker.
- Optional `uga_broker` command for MCP for Unity (CoplayDev, 9.0+) and the Unity CLI (Pipeline
  package 0.8+), compiled only when those packages are installed.

Agents drive it with `tools/editor-broker.ps1` from the
[unity-game-agent](https://github.com/NeoXider/unity-game-agent) skill; the protocol is in
`tools/shared-editor.md`. State lives in `Library/UgaBroker/` (never imported, never committed).

## Install

```powershell
& <skill>/tools/editor-broker.ps1 install -ProjectRoot <project>            # embedded copy in Packages/
& <skill>/tools/editor-broker.ps1 install -Mode git -ProjectRoot <project>  # git URL that follows main
& <skill>/tools/editor-broker.ps1 install -Mode git -GitRef <tag|commit> -ProjectRoot <project>  # pinned
```

## Maintainers

Every file ships with a `.meta` (git installs cannot generate them). After adding files run
`tools/broker-package-meta.ps1`; `tools/test-editor-broker.ps1` fails on a missing or duplicate GUID.
Tests: `Tests/Editor` (EditMode, shared cases in `broker-vectors.json` with the PowerShell CLI) and
`tools/test-editor-broker-unity.ps1` (live Editor).
