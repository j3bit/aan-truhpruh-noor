# __PROJECT_NAME__ AI Coding Bootstrap Template

This repository is a stack-neutral bootstrap template for running AI coding workflows with consistent process controls.

## What This Template Provides

- Contract layer: PRD + atomic task templates + process rules
- Procedure layer: `AGENTS.md` operating policy
- Execution layer: lead-orchestrated Codex multi-agent workflow + stack adapters
- Quality layer: CI gates + eval runner + runbooks
- Bootstrap UX: script to generate a new repository with chosen starter stack

## Quickstart (10 Minutes)

1. Validate this template repository:

```bash
./scripts/validate-contracts.sh --project-dir .
./scripts/smoke-test.sh
./evals/run-evals.sh
```

2. Bootstrap a new project:

```bash
./scripts/bootstrap-new-project.sh --name my-app --stack python
```

3. Enter the generated project and run gate:

```bash
cd ./my-app
./scripts/check.sh --stack python
```

4. Create your first PRD and task list from templates in `tasks/templates/`.

## Standard Routine

1. Write PRD (`tasks/prd-<4digit>-<slug>.md`)
2. Write atomic task list (`tasks/tasks-<4digit>-<slug>.md`)
3. Lead agent proposes dependency DAG from code + PRD + tasks
4. Execute one task per sub-agent
5. Pass gate (`scripts/check.sh`) (includes contract validation)
6. Diff-first review and merge in dependency order
7. Run evals (`evals/run-evals.sh`)

Local orchestration command:

```bash
./scripts/lead-orchestrate.sh \
  --project-dir . \
  --tasks-file tasks/tasks-<4digit>-<slug>.md \
  --approve
```

## PR Automated Review

PR automated review is handled by Codex Web GitHub integration (not GitHub Actions in this template).

## Directory Guide

- `AGENTS.md`: non-negotiable operating rules
- `tasks/`: PRD/task contracts and templates
- `scripts/`: gate/bootstrap/smoke scripts
- `templates/stacks/`: stack-specific gate adapters
- `ralph/`: loop config and role prompts
- `.github/workflows/`: CI workflows
- `evals/`: regression checks for process quality
- `docs/runbook/`: operational guidance
- `.codex/config.toml`: multi-agent orchestration defaults
- `.agents/skills/`: baseline SOP skills (`create-prd`, `generate-tasks`, `process-task`, `fix-failing-checks`, `pr-review`)
- `examples/`: stack starter samples

## Core Skills Baseline

This template ships with five baseline skills under `.agents/skills/`:

- `create-prd`: idea -> `tasks/prd-*.md`
- `generate-tasks`: PRD -> `tasks/tasks-*.md`
- `process-task`: one task execution + gate verification
- `fix-failing-checks`: recover failing gate with bounded fixes
- `pr-review`: risk-first diff review

## check.sh Contract

```bash
./scripts/check.sh --stack <python|node|go> [--changed-only] [--project-dir <path>]
```

`--project-dir` is useful when running the gate from the template root against a generated project path.

Contract rules validated by the gate:

- `tasks/process-rules.md` includes `Trace logging required`
- Task files use `tasks/tasks-<4digit>-<slug>.md`
- PRD files use `tasks/prd-<4digit>-<slug>.md`
- PRD files include section headings for `Problem`, `Goals`, `Non-goals`, `Success Metrics`, `Constraints`, `Test Strategy`, and `Rollout`
- Every `### T-...` block includes `Dependencies`, `Acceptance Criteria`, `Test Plan`, and `Done Definition`

Exit codes:

- `0`: pass
- `1`: check failure
- `2`: configuration/input error

## Troubleshooting

- `ERROR: adapter not found`: verify `templates/stacks/<stack>/check.adapter.sh` exists.
- `ERROR: <tool> not found`: install required runtime (Python/Node/Go).
- CI failure on smoke test: run `./scripts/smoke-test.sh` locally and inspect missing files.
- CI now runs root gate only when it detects root stack markers (`go.mod`, `package.json`, Python project markers).
