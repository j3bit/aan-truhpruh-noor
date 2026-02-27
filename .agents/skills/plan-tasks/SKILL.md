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

1. Source TRD path (`tasks/trd-<4digit>-<slug>.md`).
2. Source PRD path (`tasks/prd-<4digit>-<slug>.md`) for product constraints.
3. Task decomposition boundaries and delivery phases.
4. Owner and update metadata.
5. Target stack hint (`python|node|go`) for gate command examples.

If id/slug is missing, derive from TRD filename:

- Reuse TRD 4-digit id.
- Reuse TRD slug.
- Output paired paths:
  - `tasks/tasks-<4digit>-<slug>.md`
  - `tasks/dag-<4digit>-<slug>.md`
  - `tasks/dag-<4digit>-<slug>.json`

If TRD path is not explicitly given, inspect `tasks/trd-*.md` and select the newest relevant file.

## Output Contract

- Output task file path: `tasks/tasks-<4digit>-<slug>.md`
- Output DAG file paths:
  - `tasks/dag-<4digit>-<slug>.md`
  - `tasks/dag-<4digit>-<slug>.json`
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
2. Read source TRD first, then PRD, and extract architecture constraints, components, interfaces, and risk boundaries.
3. Read `tasks/templates/tasks.template.md` and DAG templates; preserve structure.
4. Materialize target files from templates.
5. Decompose work into atomic tasks:
   - Keep each task independently verifiable.
   - Express dependency order explicitly.
   - Mark `Parallel-safe: no` unless independence is demonstrable.
6. Build DAG JSON as source of truth:
   - one node per task id
   - explicit `depends_on` edges
   - `parallel_safe` and `stage` fields per node
7. Reflect the same dependencies in task file and DAG markdown.
8. Keep scope bounded to TRD/PRD:
   - move overflow items to notes or follow-up tasks
   - do not add unapproved feature expansion
9. Validate contract compatibility:
   - run `./scripts/validate-contracts.sh --project-dir .` when available
10. If validation fails, revise artifacts and rerun validation.

## Completion Conditions

Mark completion only when all conditions are true:

1. Exactly one target task file and one DAG pair are created or updated.
2. Every `### T-...` block includes required contract signals.
3. DAG dependencies and task dependencies are identical.
4. No unrelated files are changed.
5. Contract validation passes (or a blocked reason is recorded if command execution is unavailable).

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

1. Do not write outside `tasks/` for planning artifacts.
2. Do not bypass repository process rules in `tasks/process-rules.md`.
3. Do not implement product code; this skill only produces planning artifacts.
4. Do not mark implementation complete from planning artifacts alone.
