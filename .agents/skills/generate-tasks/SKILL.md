---
name: generate-tasks
description: This skill should be used when a user needs to transform a repository-compliant PRD into a repository-compliant atomic task file under tasks/tasks-fourdigit-slug.md.
---

# Generate Tasks Skill

## Purpose

Generate one repository-compliant atomic task file from a PRD while enforcing naming, task-block structure, dependency order, and gate-safe process behavior.

## When To Use

Use this skill when the request includes one of these intents:

- Generate a new task file from an existing PRD.
- Draft or complete `tasks/tasks-*.md`.
- Refine atomic task breakdown before implementation starts.

Do not use this skill to create PRDs or implement product code.

## Inputs

Collect or infer these inputs before writing:

1. Source PRD path (`tasks/prd-<4digit>-<slug>.md`).
2. Task decomposition boundaries and delivery phases.
3. Acceptance and verification expectations from PRD goals/metrics.
4. Owner and update metadata.
5. Target stack hint (`python|node|go`) for gate command examples.

If id/slug is missing, derive from PRD filename:

- Reuse PRD 4-digit id.
- Reuse PRD slug.
- Output paired path `tasks/tasks-<4digit>-<slug>.md`.

If PRD path is not explicitly given, inspect `tasks/prd-*.md` and select the newest relevant file.

## Output Contract

- Output path: `tasks/tasks-<4digit>-<slug>.md`
- Source template: `tasks/templates/tasks.template.md`
- Required task block signals for each `### T-...` block:
  - `- Dependencies:`
  - `- Acceptance Criteria:`
  - `- Test Plan:`
  - `- Done Definition:`

Reference contract details from `references/tasks-contract.md`.

## Procedure

1. Inspect existing `tasks/tasks-*.md` files to avoid id/slug collision and unintended overwrite.
2. Read source PRD and extract scope, non-goals, constraints, risks, and rollout assumptions.
3. Read `tasks/templates/tasks.template.md` and preserve its structure.
4. Materialize `tasks/tasks-<4digit>-<slug>.md` from template.
5. Decompose work into atomic tasks:
   - Keep each task independently verifiable.
   - Express dependency order explicitly.
   - Mark `Parallel-safe: no` unless independence is demonstrable.
6. Fill each task with concrete, testable details:
   - measurable acceptance criteria
   - executable test plan steps
   - done definition aligned with gate requirement
   - metadata `Gate Stack` aligned to the execution target (`python|node|go`)
7. Keep scope bounded to PRD:
   - move overflow items to notes or follow-up tasks
   - do not add unapproved feature expansion
8. Validate contract compatibility:
   - run `./scripts/validate-contracts.sh --project-dir .` when available
9. If validation fails, revise task file and rerun validation.

## Completion Conditions

Mark completion only when all conditions are true:

1. Exactly one target task file is created or updated at `tasks/tasks-<4digit>-<slug>.md`.
2. Every `### T-...` block includes required contract signals.
3. Task dependency order is explicit and coherent.
4. No unrelated files are changed.
5. Contract validation passes (or a blocked reason is recorded if command execution is unavailable).

## Failure And Retry Rules

If generation fails, retry with minimal bounded corrections:

1. Filename mismatch:
   - Rename to `tasks/tasks-<4digit>-<slug>.md`.
2. Missing required task block fields:
   - Add missing `Dependencies`, `Acceptance Criteria`, `Test Plan`, or `Done Definition` sections.
3. Non-atomic or over-scoped tasks:
   - Split into smaller tasks and correct dependencies.
4. Weak verification language:
   - Rewrite acceptance criteria and test plan with concrete commands/outcomes.

Retry limit: 3 attempts per task-generation request.
After the third failure, stop and report:

- failing rule
- attempted fixes
- exact blocker

## Safety Rules

1. Do not write outside `tasks/` for task-file generation.
2. Do not bypass repository process rules in `tasks/process-rules.md`.
3. Do not implement product code; this skill only produces task artifacts.
4. Do not mark implementation complete from planning artifacts alone.
