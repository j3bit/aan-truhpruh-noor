# Runbook 01: Standard Workflow

## Goal

Run AI coding in a stable, repeatable loop:
contract -> atomic execution -> gate -> review -> merge -> eval.

## Operating Steps

1. Create PRD from `tasks/templates/prd.template.md`.
2. Create atomic tasks from `tasks/templates/tasks.template.md`.
3. Start one unblocked task only.
4. Implement and run `./scripts/check.sh --stack <stack>`.
5. Review diff first, then merge in dependency order.
6. Run `./evals/run-evals.sh` and add/adjust cases after failures.

## Done Criteria

- Acceptance criteria satisfied.
- Test plan executed.
- Gate passed.
- Risks/follow-ups captured.
