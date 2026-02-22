# Runbook 06: Skill Integration (Deferred)

This repository intentionally excludes concrete skill bundles.

## Integration Point

- Place generated skills under `.agents/skills/`.
- Keep each skill self-contained (`SKILL.md`, optional scripts/assets/references).

## Recommended Skill Set

- create-prd
- generate-tasks
- process-task
- fix-failing-checks
- pr-review

## Validation Checklist

1. Skill output paths match repository contracts (`tasks/`, `scripts/check.sh`).
2. Skill instructions do not bypass gate rules.
3. Skill behavior is covered by eval cases where possible.
