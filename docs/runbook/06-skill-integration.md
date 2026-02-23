# Runbook 06: Skill Baseline

This repository includes five baseline skills as part of the default template contract.

## Baseline Skill Set

- `create-prd`
- `generate-tasks`
- `process-task`
- `fix-failing-checks`
- `pr-review`

## Integration Point

- Baseline skills live under `.agents/skills/`.
- Keep each skill self-contained (`SKILL.md`, optional scripts/assets/references).
- Additional skills are optional extensions and must not weaken contract or gate behavior.
- Recommended execution chain per task:
  - `process-task`
  - `fix-failing-checks` only when gate fails
  - `pr-review` after gate passes

## Validation Checklist

1. Baseline skill files exist at `.agents/skills/<skill-name>/SKILL.md`.
2. Skill output paths match repository contracts (`tasks/`, `scripts/check.sh`).
3. Skill instructions do not bypass gate rules.
