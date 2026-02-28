# Runbook 04: Ralph Loop

## Configuration

Use `ralph/loop-config.yaml` to enforce:

- completion signal: `LOOP_COMPLETE`
- max iterations
- max runtime
- gate command template

Ralph loop is executed inside each sub-agent, not as a global coordinator loop.

## Sub-Agent Loop Chain

1. Run `process-task` for one active task id.
2. If gate fails, run `fix-failing-checks` (max 3 retries).
3. Re-run gate command after every fix.
4. After gate pass, run `pr-review`.
5. If review contains `P1` or `P2`, perform one bounded rework cycle.
6. Emit `LOOP_COMPLETE` only after gate and review conditions are satisfied.

Execution profile notes:

- Sub-agents prefer `profiles.fast` when available.
- If `profiles.fast` is unavailable, execution falls back to default profile and records fallback in orchestration status.

## Role Expectations

- Planner: bound scope + verify commands.
- Builder: implement minimal slice + iterate on failures.
- Tester: enforce gate and acceptance criteria.

## Safety

1. Never emit completion signal before gate pass.
2. Never process more than one task per loop.
3. Stop safely when loop limits are reached.
