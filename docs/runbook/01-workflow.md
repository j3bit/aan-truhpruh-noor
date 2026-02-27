# Runbook 01: Standard Workflow

## Goal

Run AI coding in a stable, repeatable loop:
PRD -> TRD -> task/DAG planning -> DAG orchestration -> atomic execution -> gate -> review -> merge -> eval.

## Operating Steps

Template maintenance commands are documented in `README.md` Quickstart.

Generated project loop (bootstrap output):

1. Create PRD with `create-prd` and save as `tasks/prd-<4digit>-<slug>.md`.
2. Create TRD and save as `tasks/trd-<4digit>-<slug>.md`.
3. Create atomic tasks + DAG with `plan-tasks` and save as:
   - `tasks/tasks-<4digit>-<slug>.md`
   - `tasks/dag-<4digit>-<slug>.json`
4. Lead agent runs `orchestrate-tasks` to build deterministic wave execution from DAG.
5. Coordinator approves proposal and starts sub-agents only for ready tasks.
6. Each sub-agent executes exactly one task:
   - `process-task`
   - optional `fix-failing-checks` (only when gate fails)
   - `pr-review` after gate passes
7. Create one PR per task and merge in dependency order.
8. Run `./evals/run-evals.sh` and add/adjust cases after failures.

## Required Contracts

1. Gate command: `./scripts/check.sh --stack <python|node|go>`.
2. One-task-at-a-time per sub-agent.
3. Lead agent is propose-only (read/analyze/propose, no file writes).
4. Replan is allowed only for failure/blocker cases.
5. Stage routing is adjacency-only in the canonical actor pipeline.
6. QA feedback relay must be `QA -> IMPLEMENTATION -> ORCHESTRATION`.

## Done Criteria

- Acceptance criteria satisfied.
- Test plan executed.
- Gate passed.
- Review findings resolved or tracked.
- Risks/follow-ups captured.
