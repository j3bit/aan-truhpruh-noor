# Runbook 06: Skill Baseline

This repository includes six baseline skills as part of the default template contract.

## Baseline Skill Set

- `create-prd`
- `plan-tasks`
- `orchestrate-tasks`
- `process-task`
- `fix-failing-checks`
- `pr-review`

## Planning Pipeline Skills

The template includes planning-pipeline skills for concept and architecture stages:

- `trd-architect`

## Integration Point

- Baseline skills live under `.agents/skills/`.
- Keep each skill self-contained (`SKILL.md`, optional scripts/assets/references).
- Additional skills are optional extensions and must not weaken contract or gate behavior.
- Planning pipeline skills must keep outputs schema-compatible with:
  - `tasks/contracts/blackboard/ideation-output.schema.json`
  - `tasks/contracts/blackboard/trd-output.schema.json`
  - `tasks/contracts/blackboard/task-planning-output.schema.json`
- Recommended execution chain per delivery slice:
  - `develop-concept`
  - `create-prd`
  - `trd-architect` (placeholder stage or implementation replacement)
  - `plan-tasks` (TRD primary, PRD constraints-only)
  - `orchestrate-tasks`
  - `process-task`
  - `fix-failing-checks` only when gate fails
  - `pr-review` after gate passes

## Validation Checklist

1. Baseline skill files exist at `.agents/skills/<skill-name>/SKILL.md`.
2. Planning pipeline skill files exist at:
   - `.agents/skills/develop-concept/SKILL.md`
   - `.agents/skills/trd-architect/SKILL.md`
3. Skill output paths match repository contracts (`tasks/`, `.blackboard/`, `scripts/check.sh`).
4. Skill instructions do not bypass gate rules.
