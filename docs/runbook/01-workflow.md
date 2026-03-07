# Runbook 01: Standard Workflow

## Goal

Run AI coding in a stable, repeatable loop:
IDEATION -> PRD -> TRD -> task/DAG planning -> DAG orchestration -> atomic execution -> gate -> review -> merge -> eval.

## Operating Steps

Template maintenance commands are documented in `README.md` Quickstart.

Generated project loop (bootstrap output):

1. (Optional ideation stage) produce ideation artifact at `.blackboard/artifacts/ideation/<4digit>-<slug>.json`.
2. Create PRD with `create-prd` and save as `tasks/prd-<4digit>-<slug>.md`.
3. Create TRD and save as `tasks/trd-<4digit>-<slug>.md`.
4. Create atomic tasks + DAG with `plan-tasks` (TRD primary, PRD constraints-only) and save as:
   - `tasks/tasks-<4digit>-<slug>.md`
   - `tasks/dag-<4digit>-<slug>.json`
   - `tasks/dag-<4digit>-<slug>.md`
   - `.blackboard/artifacts/task-planning/<4digit>-<slug>.json`
5. Lead agent runs `orchestrate-tasks` to build deterministic wave execution from DAG.
6. Coordinator approves proposal and starts sub-agents only for ready tasks.
7. Each sub-agent executes exactly one task:
   - `process-task`
   - optional `fix-failing-checks` (only when gate fails)
   - `pr-review` after gate passes
8. Run QA/static hard gate after orchestration:
   - `./scripts/qa-pipeline.sh --project-dir . --stacks auto`
9. Create one PR per task and merge in dependency order.
10. Run `./evals/run-evals.sh` and add/adjust cases after failures.

## Required Contracts

1. Gate command: `./scripts/check.sh --stacks <csv|auto>`.
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
