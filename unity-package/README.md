# Unity Game Agent - Editor Broker

`com.neoxider.uga-editor-broker` lets several AI agents work in **one** Unity Editor without
stepping on each other. Unity 6 (6000.0) or newer. Editor-only: nothing ships in player builds.

- **Leases** on scenes, prefabs, assets, folders and assemblies. A focus token covers scene-graph edits.
- **Sync window**: every agent's staged scripts and heavy assets are published, imported and
  compiled once. Compile errors go to the agent that wrote them.
- **Hot window**: queued test selections run in one Test Runner execution per mode, then Play Mode
  sessions one by one. Cold work keeps priority.
- **Exclusive window** for changes that recompile or reimport for everyone: packages, scripting
  defines, build target, builds and merges. Build Settings, tags and layers are leased like assets.
- **Team**: agents see each other (roster with role, current work, leases and jobs), the queue with a
  rough ETA from the project's telemetry, and a Markdown team board (`Library/UgaBroker/team-board.md`)
  for handoffs and questions.
- **Board**: Window > Unity Game Agent > Editor Broker. The human can post to the team board from it.
- Optional `uga_broker` command for MCP for Unity (CoplayDev, 9.0+) and the Unity CLI (Pipeline
  package 0.8+). It is compiled only when those packages are installed.

Agents drive it with `tools/editor-broker.ps1` from the
[unity-game-agent](https://github.com/NeoXider/unity-game-agent) skill. The protocol is in
`tools/shared-editor.md`. State lives in `Library/UgaBroker/` (never imported, never committed).

## Install

```powershell
& <skill>/tools/editor-broker.ps1 install -ProjectRoot <project>            # embedded copy in Packages/
& <skill>/tools/editor-broker.ps1 install -Mode git -ProjectRoot <project>  # git URL that follows main
& <skill>/tools/editor-broker.ps1 install -Mode git -GitRef <tag|commit> -ProjectRoot <project>  # pinned
```

## Maintainers

Every file ships with a `.meta`, because git installs cannot generate them. After adding files, run
`tools/broker-package-meta.ps1`. `tools/test-editor-broker.ps1` fails on a missing or duplicate GUID.
Tests: `Tests/Editor` (EditMode, shared cases in `broker-vectors.json` with the PowerShell CLI) and
`tools/test-editor-broker-unity.ps1` (live Editor).
