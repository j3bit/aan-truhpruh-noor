# Runbook 01: Standard Workflow

## Goal

Run AI coding in a stable, repeatable loop:
contract -> lead planning -> atomic execution -> gate -> review -> merge -> eval.

## Operating Steps

Template maintenance commands are documented in `README.md` Quickstart.

Generated project loop (bootstrap output):

1. Create PRD with `create-prd` and save as `tasks/prd-<4digit>-<slug>.md`.
2. Create atomic tasks with `generate-tasks` and save as `tasks/tasks-<4digit>-<slug>.md`.
3. Lead agent builds a dependency DAG from code + PRD + tasks and proposes execution order.
4. Coordinator approves proposal and starts sub-agents only for ready tasks.
5. Each sub-agent executes exactly one task:
   - `process-task`
   - optional `fix-failing-checks` (only when gate fails)
   - `pr-review` after gate passes
6. Create one PR per task and merge in dependency order.
7. Run `./evals/run-evals.sh` and add/adjust cases after failures.

## Required Contracts

1. Gate command: `./scripts/check.sh --stack <python|node|go>`.
2. One-task-at-a-time per sub-agent.
3. Lead agent is propose-only (read/analyze/propose, no file writes).
4. Replan is allowed only for failure/blocker cases.

## Done Criteria

- Acceptance criteria satisfied.
- Test plan executed.
- Gate passed.
- Review findings resolved or tracked.
- Risks/follow-ups captured.
