# Orchestrate Tasks Contract Reference

## Required Inputs

1. `tasks/tasks-<4digit>-<slug>.md`
2. `tasks/dag-<4digit>-<slug>.json`
3. `- Gate Stack:` metadata in task file or explicit `--stack`

## Required Orchestration Artifacts

- Plan: `.orchestration/plan.jsonl`
- Status: `.orchestration/status.jsonl`
- Summary: `.orchestration/summary.json`
- Worker results: `.orchestration/workers/<task_id>.result.json`
- QA report: `.orchestration/reports/qa-report.json`
- Static review report: `.orchestration/reports/static-review.json`

## Required Blackboard Structure

- `.blackboard/artifacts/`
- `.blackboard/events/events.jsonl`
- `.blackboard/integration/waves/`
- `.blackboard/integration/tasks/`
- `.blackboard/feedback/qa/`
- `.blackboard/feedback/integration/`
- `.blackboard/artifacts/qa/`
- `.blackboard/jobs/`
- `.blackboard/state/`

## Stage Routing Rules

Allowed stage transitions are adjacent only for:

- `IDEATION <-> PRD`
- `PRD <-> TRD`
- `TRD <-> TASK_PLANNING`
- `TASK_PLANNING <-> ORCHESTRATION`
- `ORCHESTRATION <-> IMPLEMENTATION`
- `IMPLEMENTATION <-> QA`
- `QA <-> DEPLOYMENT`

Any other route must be blocked with `blocked_reason=non_adjacent_stage_route`.

## Self-Healing Relay Rule

Strict relay only:

1. QA emits failure to IMPLEMENTATION.
2. IMPLEMENTATION relays replan request to ORCHESTRATION.
3. QA must not emit direct event to ORCHESTRATION.
