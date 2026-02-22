# Runbook 04: Ralph Loop

## Configuration

Use `ralph/loop-config.yaml` to enforce:

- completion signal: `LOOP_COMPLETE`
- max iterations
- max runtime
- gate command template

## Role Expectations

- Planner: bound scope + verify commands.
- Builder: implement minimal slice + iterate on failures.
- Tester: enforce gate and acceptance criteria.

## Safety

Never emit completion signal before gate pass.
