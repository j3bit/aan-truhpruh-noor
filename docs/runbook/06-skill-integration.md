# Runbook 06: Skill Baseline

This repository includes a stable skill baseline for planning, orchestration, implementation, and review.

## Skill Set

- `ideation-consultant`
- `create-prd`
- `create-trd`
- `plan-tasks`
- `orchestrate-tasks`
- `process-task`
- `fix-failing-checks`
- `pr-review`

## Integration Point

- Skills live under `.agents/skills/`.
- Keep each skill self-contained (`SKILL.md`, optional scripts/assets/references).
- Additional skills are optional extensions and must not weaken contract or gate behavior.
- Skill outputs must remain schema-compatible with contracts under `tasks/contracts/blackboard/` when emitting blackboard artifacts.
- Recommended execution chain per delivery slice:
  - `ideation-consultant`
  - `create-prd`
  - `create-trd`
  - `plan-tasks` (TRD primary, PRD constraints-only)
  - `orchestrate-tasks`
  - `process-task`
  - `fix-failing-checks` only when gate fails
  - `pr-review` after gate passes

## Validation Checklist

1. Required skill files exist at `.agents/skills/<skill-name>/SKILL.md`.
2. Required support files referenced by each skill exist.
3. Skill output paths match repository contracts (`tasks/`, `.blackboard/`, `scripts/check.sh`).
4. Skill instructions do not bypass gate rules.
