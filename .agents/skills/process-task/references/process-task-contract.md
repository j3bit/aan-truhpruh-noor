# Process Task Contract Reference

Use this reference to keep task execution behavior aligned with repository rules and gate expectations.

## Input Resolution

Required input signals:

1. Task id pattern: `T-[0-9]+`
2. Task file pattern: `tasks/tasks-<4digit>-<slug>.md`
3. Paired PRD pattern: `tasks/prd-<4digit>-<slug>.md`
4. Paired TRD pattern: `tasks/trd-<4digit>-<slug>.md`
5. Paired DAG pattern: `tasks/dag-<4digit>-<slug>.json`

If task file path is missing, resolve by searching `tasks/tasks-*.md` for the exact task id heading.
If task id resolution returns zero matches, do not mutate any task status; report `task id not found` as a request-level blocker and stop.
If task id resolution returns multiple matches, do not mutate any task status; report ambiguity with candidate task file paths as a request-level blocker and stop.
If paired artifact files (`PRD`, `TRD`, `DAG`) are missing, set task status to `blocked`, record missing paths, and stop.

## Task Block Requirements

Before implementation, confirm target task block includes:

1. `- Dependencies:`
2. `- Acceptance Criteria:`
3. `- Test Plan:`
4. `- Done Definition:`

If any required field is missing, treat as contract issue and fix task artifact before marking completion.

## TDD Expectation

For behavior changes, the task should include:

1. Failing test introduction or update aligned to acceptance criteria.
2. Minimal implementation to satisfy tests.
3. Final gate pass evidence.

## Status And Evidence Expectations

Expected status progression per processed task:

- `todo` -> `in_progress` -> `done`
- Use `blocked` only after a unique target task is resolved, when required paired artifacts are missing, when progress cannot continue because of external dependency, or when failures remain unresolved after retry limit.

Record execution evidence in task notes:

1. Commands executed
2. Pass/fail outcomes
3. Relevant output artifact paths (if any)
4. Integration artifact references when conflict directives were consumed.
5. Integration feedback bundle references when conflict feedback was provided.
6. Contract/interface documentation update evidence when interfaces changed, or explicit `none`.
7. Follow-up/risk capture entries, or explicit `none`.

## Gate Commands

Primary gate command:

```bash
./scripts/check.sh --stacks <csv|auto>
```

Optional project-path variant:

```bash
./scripts/check.sh --stacks <csv|auto> --project-dir <path>
```

Contract-only validation:

```bash
./scripts/validate-contracts.sh --project-dir .
```

## Execution Profile Selection

When execution profile selection is required:

1. Read `${HOME}/.codex/config.toml`.
2. Use `fast` only when `[profiles.fast]` exists.
3. Otherwise use `default` and record fallback in task evidence.

## Retry Policy

Retry limit: 3 attempts per task-processing request.

Each retry should:

1. Target first failing signal.
2. Apply minimal correction.
3. Re-run relevant checks and full gate.

If still failing after limit, stop and report blocker instead of forcing completion.
