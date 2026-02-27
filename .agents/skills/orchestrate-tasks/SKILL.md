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
3. Gate stack (`python|node|go`)
4. Optional output dir for orchestration artifacts

## Output Contract

Primary orchestration outputs:

- `<out-dir>/plan.jsonl`
- `<out-dir>/status.jsonl`
- `<out-dir>/summary.json`

Blackboard outputs:

- `.blackboard/events/events.jsonl`
- `.blackboard/jobs/<task_id>.json`
- `.blackboard/integration/waves/wave-<n>.json`
- `.blackboard/integration/tasks/<task_id>.json`
- `.blackboard/feedback/qa/*.json`

Reference contract details from `references/orchestrate-contract.md`.

## Procedure

1. Resolve and validate task + DAG artifacts.
2. Build topological waves from DAG.
3. For each wave:
   - write wave integration artifact
   - dispatch per-task job manifests (`preferred_profile=fast`, `fallback_allowed=true`)
   - run dependency-safe execution records and gate checks
4. Emit stage-routed events only through adjacent stages.
5. If QA failure bundle exists:
   - allow `QA -> IMPLEMENTATION` event
   - relay `IMPLEMENTATION -> ORCHESTRATION` replan request
6. Persist status and summary records.
7. Emit `LOOP_COMPLETE` only on full success.

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
