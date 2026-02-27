# Runbook 03: Codex Multi-Agent Operating Model

## Goal

Use a lead-orchestrated multi-agent model that maximizes parallelism while preserving dependency safety, stage-safe messaging, and blackboard-backed integration control.

## Roles

1. Lead agent:
   - collects inputs from code + PRD + TRD + tasks + DAG
   - proposes deterministic wave execution from DAG
   - does not modify product code; may write orchestration artifacts
2. Coordinator:
   - validates/approves lead proposal
   - spawns sub-agents for ready tasks
   - tracks execution status contract
3. Sub-agent:
   - owns one task only
   - executes `process-task`
   - follows TDD-first implementation loop
   - consumes integration artifact from `.blackboard/integration/tasks/<task_id>.json`
   - calls `fix-failing-checks` only when needed
   - runs `pr-review` after gate pass

## SSOT Inputs For Lead Proposal

1. `tasks/prd-*.md`
2. `tasks/trd-*.md`
3. `tasks/tasks-*.md`
4. `tasks/dag-*.json`
5. current code and interfaces in repository

## Proposal Contract

The lead proposal output must include all fields below for each task:

- `task_id`
- `dependencies`
- `parallel_safe`
- `gate_stack`
- `risk_level`
- `ready`
- `stage`
- `wave`

Stored at: `.orchestration/plan.jsonl` (or `--out-dir` override).

Example:

```json
{
  "task_id": "T-003",
  "dependencies": ["T-001", "T-002"],
  "parallel_safe": false,
  "gate_stack": "python",
  "risk_level": "medium",
  "ready": true,
  "stage": "IMPLEMENTATION",
  "wave": 2
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
- `stage`
- `wave`
- `profile`
- `profile_fallback`

Stored at: `.orchestration/status.jsonl` (or `--out-dir` override).

Example:

```json
{
  "task_id": "T-003",
  "agent_id": "sub-17",
  "status": "blocked",
  "attempt": 2,
  "gate_passed": false,
  "pr_review_passed": false,
  "blocked_reason": "dependency_not_ready",
  "stage": "IMPLEMENTATION",
  "wave": 2,
  "profile": "default",
  "profile_fallback": true
}
```

## Orchestration Rules

1. Sub-agent scope is one task id per run.
2. Start tasks only when all dependencies are complete.
3. Parallel start is allowed only when `parallel_safe` is `true`.
4. Task completion requires gate pass and review pass.
5. PR granularity is one task per PR.
6. Merge order follows dependency order only.
7. Actor events must use adjacent stage routes only.
8. Integration directives and conflicts are persisted on blackboard artifacts.
9. QA feedback relay must be `QA -> IMPLEMENTATION -> ORCHESTRATION`.

## Local E2E Command

```bash
./scripts/lead-orchestrate.sh \
  --project-dir . \
  --tasks-file tasks/tasks-<4digit>-<slug>.md \
  --dag-file tasks/dag-<4digit>-<slug>.json \
  --approve
```

## Replan Policy

1. Replan trigger is limited to failure or blocker.
2. Successful runs must not trigger DAG regeneration.
3. Lead can propose alternative DAG for blocked tasks.
4. Coordinator applies replan only after explicit approval.

## Safety And Security

1. Lead agent permissions are read-only.
2. Changes to `tasks`/`prd`/code are made by execution sub-agents only.
3. Automated PR review jobs remain read-only.
4. Privilege escalation remains approval-gated.

## Validation Scenarios

1. lead proposal is deterministic for identical inputs
2. dependency violations are rejected before task start
3. replan triggers only on failure/blocker
4. proposal/status mismatch causes safe stop
5. one-task-one-PR rule is enforced
6. `LOOP_COMPLETE` before gate pass is rejected
7. non-adjacent stage messages are rejected with `non_adjacent_stage_route`
8. QA direct-to-orchestration route is rejected
