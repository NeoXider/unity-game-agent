# Feature: [FEAT-NNN Name]

**Status:** planned | in_progress | qa | done | blocked
**Requirements:** [existing TZ/GDD lines/link; no replacement spec]
**Write scope:** [exact files/systems; exclusions and serialized contracts]
**Risk / rollback:** [affected contract and rollback surface]

## Acceptance And Tasks

- [ ] [Observable player/user outcome and relevant edge/lifecycle behavior]
- [ ] [TASK-NNN-name](../Tasks/TASK-NNN-name.md) - [short purpose]

## Reuse Decision (before implementation)

| Candidate/source + version | License / asset permission | Mode | Decision / exact gap + cost rationale |
|---|---|---|---|
| [project/Neo/package/allowed slice; cached evidence if valid] | [source/permission] | direct reuse / adapt / reference-only / reject | [fit; custom only after demonstrated miss/poor fit and narrower/faster rationale, or explicit from-scratch request] |

Stop if this receipt is missing or a suitable ready solution would be replaced. Tiny glue needs local
discovery only. A clone is not integration; package-code permission does not license included models.

## Verification Plan

- Verification Driver: [smallest driver proving the changed outcome; runtime interaction must be driven]
- Tests Required: EditMode | PlayMode | Both | Not Needed; [named contract / reason]
- Screenshot Required: yes | no | on-failure; [state/timing when relevant]
- Automation Gap: none | [missing driver; next owner/action]
- Max QA Attempts: 2 genuine failed attempts per path; then concise fail/blocked handoff
- Broad suite/build/platform checks: [actual risk/request or not needed]; docs-only invokes no Unity

## Developer Handoff (Developer owns)

- Source-final revision / changed paths: [commit + dirty hashes or task-scoped source identity]
- Actual reused API/asset + integration path: [call/import/wiring; or justified custom exit]
- Relevant compile/selfcheck: [result + evidence/revision/scope/environment]
- Remaining risk / skipped checks: [reason]; ready for independent QA, not final acceptance

## Independent QA Result (QA owns)

- Result: pending | pass | fail | blocked
- Checked revision / scope / environment: [source + driver/target]
- Actual reuse verified: [diff/API/import/wiring evidence or defect]
- Changed outcome / affected contract checks: [observed state/action + evidence]
- Unchanged evidence retained: [original source/scope/environment and why diff cannot invalidate it]
- Unverified required scope: [reason + next owner/action; never pass/done]
- Defect: [one repro; expected/actual; revision/evidence; next owner/action]

After correction, rerun failed/affected checks only; uncertainty/changed dependencies invalidate the
relevant old evidence. Optional post-QA GDD alignment cites existing requirements, not a rewritten spec.

## Tracking

[TRACKING_LINKS]
