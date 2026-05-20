# NeoxiderTools Reuse Policy

Use this file when a Unity project or task may benefit from ready systems in NeoxiderTools. Reuse is opt-in, not forced.

## When To Ask

Ask whether to use NeoxiderTools when `ask_about_neoxider_tools` is true and any of these apply:

- project is new or mostly empty;
- task mentions UI, pages, settings, save, quests, cards, audio, docs, editor tooling, or reusable game systems;
- existing project already references `Neoxider`, `Neo.`, `NeoxiderTools`, or similar namespaces/assets;
- user asks to build a system that appears to exist in NeoxiderTools.

Question:

```text
Use ready systems from NeoxiderTools, or build standalone for this project?
```

Default if the user does not answer: standalone, unless the project already depends on NeoxiderTools.

## Discovery Before Use

If the user opts in, discover available systems before planning implementation:

```text
1. Inspect Packages/manifest.json and Assets/ for NeoxiderTools references.
2. Search for relevant namespaces, asmdefs, ScriptableObjects, prefabs, samples, and docs.
3. Identify the smallest reusable system or adapter point.
4. Confirm missing package/assets before depending on them.
5. Record the decision in Docs/DEV_PROFILE.json and Docs/AGENT_MEMORY.md.
```

Prefer project-local NeoxiderTools code over assumptions from memory.

## Reuse Targets

Likely matches:

| Task area | Look for |
|---|---|
| UI/pages | page settings, page views, UI navigation, UI Toolkit/uGUI wrappers |
| Settings | game settings, settings groups, settings views, localization hooks |
| Save | save provider settings, save keys, persistent config |
| Quests | quest config, quest flow config, quest editors |
| Cards/decks | deck config, card animation config, card layout/runtime |
| Audio | audio manager/settings systems |
| Tooling/docs | editor windows, custom inspectors, generated docs |

Do not import or copy whole systems when a small adapter/reference is enough.

## Implementation Rules

- Keep game-specific code outside NeoxiderTools unless the task is explicitly to modify NeoxiderTools itself.
- Prefer adapters/facades that let the game use NeoxiderTools without hardcoding unrelated systems.
- Do not silently add NeoxiderTools to a clean project. Ask first.
- Do not replace an existing standalone system with NeoxiderTools unless the user requested reuse or migration.
- If NeoxiderTools is unavailable after opt-in, fall back to standalone and report the limitation.

## Docs Updates

When a decision is made, update:

- `Docs/DEV_PROFILE.json`: `neoxider_tools` as `"use"`, `"standalone"`, or `"unavailable"`.
- `Docs/AGENT_MEMORY.md`: short rationale and systems reused or skipped.
- `Docs/DEV_LOG/iteration-*.md`: implementation-level reuse notes.

If Docs/ does not exist because this is a Quick Fix, report the decision in the final response instead.
