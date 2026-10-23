# Benchmark: three agents build a clicker, without and with this skill

The question: when several agents build one Unity game on one computer at the same time, does this
skill's shared-editor protocol make them faster and more reliable than agents left to organize
themselves? The game is small on purpose. A team should finish it in roughly 5-15 minutes.

Two runs build the same small game ([brief.md](brief.md)), with the same three roles working in
parallel (`core`, `ui`, `scene`):

| | Run A: no skill | Run B: with the skill |
|---|---|---|
| Starting project | The same template copy | The same template copy |
| Agents | Codex CLI, `gpt-6.1-sol`, reasoning `xhigh`, three at once | Same |
| Skill and helpers | Forbidden: the unity-game-agent skill and its tools, neoxider-agents, any sub-agent (checked afterwards in the launcher's task tree) | Explicitly asked to use everything the unity-game-agent skill offers |
| Brief | [brief.md](brief.md) | [brief.md](brief.md) |
| How to work | "Work however you think best." Unity Editor path and Unity CLI given | Read the skill; the orchestrator ran `doctor -Fix` and `session start`; one Editor is open |
| Editor | None open; agents start Unity as they see fit | One Editor, opened by the orchestrator (its start counts toward the time) |

The template project has the Unity Test Framework, uGUI and the Unity Pipeline package, so both runs
can drive an open Editor with `unity command`. Run B also has the broker package, which the
orchestrator installed during the run.

## Criteria

Development time is the main criterion. The rest explain where the time went and whether the result
is any good.

| # | Criterion | How it is measured | Better |
|---|---|---|---|
| 1 | **Development time** | Wall clock from the first orchestrator action to the last agent's final reply | Lower |
| 2 | Acceptance | Hidden acceptance tests ([acceptance/](acceptance/)) run after the run, identical for A and B: economy rules, save/load, scene contract, 10 clicks through the EventSystem, upgrade buying, no error logs | More passed |
| 3 | Agents' own tests | Count and result of the tests the agents wrote | More, all green |
| 4 | Fix rounds | Extra rounds needed to make acceptance pass, and their time | Fewer |
| 5 | Unity launches | Distinct Unity Editor processes started for the project (sampled every 2 s) | Fewer |
| 6 | Peak memory | Highest total private memory of the project's Unity processes; lowest free commit memory | Lower |
| 7 | Conflicts | Locked-project failures, compile errors caused by another agent, files changed underneath an agent; from Unity logs where possible, otherwise from the agents' reports | Fewer |
| 8 | Waiting | Minutes agents report waiting on Unity or each other | Lower |
| 9 | Tokens and tool calls | Usage reported by the agent tool for each agent | Lower |
| 10 | Extra disk | Size of the run folder at the end minus the template size (clones show up here) | Lower |
| 11 | Human help | Times the owner had to step in | Zero |

Self-reported numbers (8, part of 7) are marked as such in the results.

## Procedure

1. `prepare.ps1` creates the template once and copies it to `run-a/` and `run-b/` under a work
   folder outside the repository.
2. Start `sample-metrics.ps1` for the run's project (Unity processes, memory, launches).
3. Run A: launch the three agents at once with the brief and the run A "How to work" text.
4. Run B: as orchestrator run `editor-broker.ps1 install`, start the Editor, `doctor -Fix`,
   `session start`, then launch the three agents with the brief and the run B text.
5. When the last agent replies, stop the sampler, close every Unity process of that run, and run
   `run-acceptance.ps1` on the project.
6. If acceptance fails, one fix round with the same agents, told only which acceptance checks failed.
7. Record everything in [results.md](results.md).

The runs go one after the other on the same machine, never at the same time. Close other Unity
projects first if memory is short. An Editor that cannot start distorts the times.

## Run texts ("How to work")

Run A:

> Work however you think best. Unity Editor: `{UNITY_EXE}`. The Unity CLI (`unity`) is installed,
> and the project has the Unity Pipeline package, so `unity command ...` can drive an open Editor.
> The other agents may be using Unity at the same time as you. Forbidden: the unity-game-agent skill
> and anything in its folder (`{SKILL}`), neoxider-agents (`neoxider`, `agent.ps1`, `agent.sh`) and
> starting any other AI agent or sub-agent. Do the work yourself.

Run B:

> Use everything the unity-game-agent skill offers for this task: read `{SKILL}/SKILL.md`, then
> `{SKILL}/tools/shared-editor.md`, and follow them. The orchestrator has opened the Editor and
> started a shared-editor session for this project; use `{SKILL}/tools/editor-broker.ps1` with
> `-ProjectRoot {PROJECT}` and agent name `{ROLE}` (leases, staging, sync and hot windows,
> background waits, the board). The Unity CLI (`unity command ...`) reaches the open Editor through
> the Pipeline package.
