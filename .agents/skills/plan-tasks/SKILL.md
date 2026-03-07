---
name: plan-tasks
description: This skill should be used when a user needs to transform a repository-compliant TRD into a repository-compliant atomic task file and task DAG under tasks/.
---

# Plan Tasks Skill

## Purpose

Generate a repository-compliant atomic task list and task DAG from a TRD while enforcing naming, dependency consistency, and gate-safe process behavior.

## When To Use

Use this skill when the request includes one of these intents:

- Generate a task plan from a TRD.
- Draft or update `tasks/tasks-*.md` and matching `tasks/dag-*.{md,json}`.
- Refine atomic decomposition and execution DAG before orchestration starts.

Do not use this skill to create PRDs/TRDs or implement product code.

## Inputs

Collect or infer these inputs before writing:

1. Source TRD path (`tasks/trd-<4digit>-<slug>.md`) as the primary input.
2. Source PRD path (`tasks/prd-<4digit>-<slug>.md`) for goals/non-goals/constraints validation only.
3. Task decomposition boundaries and delivery phases.
4. Owner and update metadata.
5. Stack registry path and per-task `gate_stacks` assignment for completion checks.

If id/slug is missing, derive from TRD filename:

- Reuse TRD 4-digit id.
- Reuse TRD slug.
- Output paired paths:
  - `tasks/tasks-<4digit>-<slug>.md`
  - `tasks/dag-<4digit>-<slug>.md`
  - `tasks/dag-<4digit>-<slug>.json`

If TRD path is not explicitly given, resolve deterministically:

- Inspect `tasks/trd-*.md`.
- If exactly one file exists, use it.
- If multiple files exist, stop and request explicit TRD selection before writing artifacts.
- If no file exists, stop and report a blocker.

## Output Contract

- Output task file path: `tasks/tasks-<4digit>-<slug>.md`
- Output DAG file paths:
  - `tasks/dag-<4digit>-<slug>.md`
  - `tasks/dag-<4digit>-<slug>.json`
- Output planning artifact path:
  - `.blackboard/artifacts/task-planning/<4digit>-<slug>.json`
- Source templates:
  - `tasks/templates/tasks.template.md`
  - `tasks/templates/dag.template.md`
  - `tasks/templates/dag.template.json`
- Required task block signals for each `### T-...` block:
  - `- Dependencies:`
  - `- Acceptance Criteria:`
  - `- Test Plan:`
  - `- Done Definition:`

Reference contract details from `references/tasks-contract.md`.

## Procedure

1. Inspect existing `tasks/tasks-*.md` and `tasks/dag-*.json` files to avoid id/slug collision and unintended overwrite.
2. Resolve source TRD deterministically when TRD path is omitted:
   - inspect `tasks/trd-*.md`
   - if exactly one file exists, use it
   - if multiple files exist, stop and request explicit TRD selection
   - if no file exists, stop and report a blocker
3. Read source TRD first and use it as the decomposition source of truth.
4. Read source PRD only for goals/non-goals/constraints checks and reject scope expansion that is not justified by TRD architecture.
5. Read `tasks/templates/tasks.template.md` and DAG templates; preserve structure.
6. Materialize target files from templates.
7. Decompose work into atomic tasks:
   - Keep each task independently verifiable.
   - Express dependency order explicitly.
   - Mark `Parallel-safe: no` unless independence is demonstrable.
8. Build DAG JSON as source of truth:
   - one node per task id
   - explicit `depends_on` edges
   - `parallel_safe` and `stage` fields per node
9. Reflect the same dependencies in task file and DAG markdown.
10. Write or update planning artifact at `.blackboard/artifacts/task-planning/<4digit>-<slug>.json` with paths for TRD/PRD/tasks/DAG and generation timestamp.
11. Keep scope bounded to TRD/PRD:
   - move overflow items to notes or follow-up tasks
   - do not add unapproved feature expansion
12. Validate contract compatibility as preflight:
   - run `./scripts/validate-contracts.sh --project-dir .` when available
13. Run full gate for completion:
   - run `./scripts/check.sh --stacks <csv|auto> --project-dir .`
14. If validation or gate fails, revise artifacts and rerun checks.

## Completion Conditions

Mark completion only when all conditions are true:

1. Exactly one target task file and one DAG pair are created or updated.
2. Every `### T-...` block includes required contract signals.
3. DAG dependencies and task dependencies are identical.
4. Metadata fields are populated in generated artifacts:
   - `Owner`
   - `Last Updated`
   - `Stack Registry`
   - `Task DAG`
   - `Task DAG Markdown`
   - `Planning Artifact`
5. No unrelated files are changed.
6. Contract validation passes (or a blocked reason is recorded if command execution is unavailable).
7. `./scripts/check.sh --stacks <csv|auto> --project-dir .` exits with code `0` (or a blocked reason is recorded if command execution is unavailable).

## Failure And Retry Rules

If planning fails, retry with minimal bounded corrections:

1. Filename mismatch:
   - Rename to contract-compliant paths.
2. Missing required task block fields:
   - Add missing `Dependencies`, `Acceptance Criteria`, `Test Plan`, or `Done Definition`.
3. DAG/task mismatch:
   - Align both artifacts to the same edge set.
4. Non-atomic or over-scoped tasks:
   - Split into smaller tasks and correct dependencies.

Retry limit: 3 attempts per planning request.
After the third failure, stop and report:

- failing rule
- attempted fixes
- exact blocker

## Safety Rules

1. Do not write outside `tasks/` for planning artifacts except the required planning artifact under `.blackboard/artifacts/task-planning/`.
2. Do not bypass repository process rules in `tasks/process-rules.md`.
3. Do not implement product code; this skill only produces planning artifacts.
4. Do not mark implementation complete from planning artifacts alone.
