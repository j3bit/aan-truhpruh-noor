---
name: orchestrate-tasks
description: This skill should be used when a user needs to orchestrate atomic task execution from tasks + DAG artifacts with blackboard events, integration artifacts, and self-healing relay.
---

# Orchestrate Tasks Skill

## Purpose

Orchestrate task execution from repository contracts (`tasks/tasks-*.md` + `tasks/dag-*.json`) using blackboard-backed state and adjacency-restricted actor messaging.

## When To Use

Use this skill when the request includes one of these intents:

- Execute task DAG waves with dependency-safe ordering.
- Run lead orchestration with integration management artifacts.
- Run self-healing relay from QA feedback to orchestration replanning.

Do not use this skill to implement an individual task. Sub-agents use `process-task` for single-task execution.

## Inputs

1. Task file path (`tasks/tasks-<4digit>-<slug>.md`)
2. DAG json path (`tasks/dag-<4digit>-<slug>.json`)
3. Stack registry path (`tasks/stacks.json`) and DAG node `gate_stacks`
4. Project dir root used to resolve fixed contract paths (`.orchestration/` and `.blackboard/`)

## Output Contract

Primary orchestration outputs:

- `.orchestration/plan.jsonl`
- `.orchestration/status.jsonl`
- `.orchestration/summary.json`
- `.orchestration/workers/<task_id>.result.json`
- `.orchestration/reports/qa-report.json`
- `.orchestration/reports/static-review.json`

Blackboard outputs:

- `.blackboard/artifacts/`
- `.blackboard/events/events.jsonl`
- `.blackboard/jobs/<task_id>.json`
- `.blackboard/integration/waves/wave-<n>.json`
- `.blackboard/integration/tasks/<task_id>.json`
- `.blackboard/feedback/qa/*.json`
- `.blackboard/feedback/integration/<task_id>.json`
- `.blackboard/artifacts/qa/scenarios-<id>-<slug>.json`
- `.blackboard/state/`

Reference contract details from `references/orchestrate-contract.md`.

## Procedure

1. Resolve and validate task + DAG artifacts.
2. Build topological waves from DAG.
3. Initialize required blackboard structure before writing wave/task artifacts.
4. For each wave:
   - write wave integration artifact
   - dispatch per-task job manifests (`preferred_profile=fast`, `fallback_allowed=true`)
   - run dependency-safe workers in parallel when DAG allows
   - parse worker result contracts and update status
   - apply integration feedback loop on conflicts
5. Emit stage-routed events only through adjacent stages.
6. If QA failure bundle exists:
   - allow `QA -> IMPLEMENTATION` event
   - relay `IMPLEMENTATION -> ORCHESTRATION` replan request
7. Persist status and summary records.
8. Emit `LOOP_COMPLETE` only on full success.

## Completion Conditions

1. Plan/status/summary contracts are generated.
2. Blackboard events and integration artifacts are generated.
3. Non-adjacent stage routes are blocked and recorded.
4. DAG order is respected.
5. `LOOP_COMPLETE` is emitted only when all tasks complete with passing gate records.

## Safety Rules

1. Orchestrator does not execute multiple unrelated DAGs in one run.
2. Non-adjacent stage communication is rejected.
3. Do not mark completion when unresolved blockers exist.
