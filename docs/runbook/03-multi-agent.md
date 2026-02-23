# Runbook 03: Codex Multi-Agent Operating Model

## Goal

Use a lead-orchestrated multi-agent model that maximizes parallelism while preserving task dependency safety and gate quality.

## Roles

1. Lead agent:
   - collects inputs from code + PRD + tasks
   - proposes dependency DAG and execution waves
   - does not modify repository files
2. Coordinator:
   - validates/approves lead proposal
   - spawns sub-agents for ready tasks
   - tracks execution status contract
3. Sub-agent:
   - owns one task only
   - executes `process-task`
   - calls `fix-failing-checks` only when needed
   - runs `pr-review` after gate pass

## SSOT Inputs For Lead Proposal

1. `tasks/prd-*.md`
2. `tasks/tasks-*.md`
3. current code and interfaces in repository

## Proposal Contract

The lead proposal output must include all fields below for each task:

- `task_id`
- `dependencies`
- `parallel_safe`
- `gate_stack`
- `risk_level`
- `ready`

Example:

```json
{
  "task_id": "T-003",
  "dependencies": ["T-001", "T-002"],
  "parallel_safe": false,
  "gate_stack": "python",
  "risk_level": "medium",
  "ready": true
}
```

## Execution Status Contract

Coordinator and sub-agents must report status records with:

- `task_id`
- `agent_id`
- `status`
- `attempt`
- `gate_passed`
- `pr_review_passed`
- `blocked_reason`

Example:

```json
{
  "task_id": "T-003",
  "agent_id": "sub-17",
  "status": "blocked",
  "attempt": 2,
  "gate_passed": false,
  "pr_review_passed": false,
  "blocked_reason": "dependency_not_ready"
}
```

## Orchestration Rules

1. Sub-agent scope is one task id per run.
2. Start tasks only when all dependencies are complete.
3. Parallel start is allowed only when `parallel_safe` is `true`.
4. Task completion requires gate pass and review pass.
5. PR granularity is one task per PR.
6. Merge order follows dependency order only.

## Replan Policy

1. Replan trigger is limited to failure or blocker.
2. Successful runs must not trigger DAG regeneration.
3. Lead can propose alternative DAG for blocked tasks.
4. Coordinator applies replan only after explicit approval.

## Safety And Security

1. Lead agent permissions are read-only.
2. Changes to `tasks`/`prd`/code are made by execution sub-agents only.
3. CI review jobs remain read-only.
4. Privilege escalation remains approval-gated.

## Validation Scenarios

1. lead proposal is deterministic for identical inputs
2. dependency violations are rejected before task start
3. replan triggers only on failure/blocker
4. proposal/status mismatch causes safe stop
5. one-task-one-PR rule is enforced
6. `LOOP_COMPLETE` before gate pass is rejected
