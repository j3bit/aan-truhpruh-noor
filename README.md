# __PROJECT_NAME__ AI Coding Bootstrap Template

This repository is a stack-neutral bootstrap template for running AI coding workflows with consistent process controls.

## What This Template Provides

- Contract layer: PRD + TRD + atomic task/DAG templates + process rules
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

4. Create your first PRD/TRD/task/DAG artifacts from templates in `tasks/templates/`.

## Standard Routine

1. (Optional placeholder stage) Produce ideation artifact at `.blackboard/artifacts/ideation/<4digit>-<slug>.json`
2. Write PRD (`tasks/prd-<4digit>-<slug>.md`)
3. Write TRD (`tasks/trd-<4digit>-<slug>.md`)
4. Plan tasks and DAG from TRD (`tasks/tasks-<4digit>-<slug>.md`, `tasks/dag-<4digit>-<slug>.json`, `tasks/dag-<4digit>-<slug>.md`)
5. Record task planning artifact at `.blackboard/artifacts/task-planning/<4digit>-<slug>.json`
6. Lead orchestrates wave execution from DAG
7. Sub-agents execute one task each (`process-task`, TDD-first)
8. Pass gate (`scripts/check.sh`) (includes contract validation)
9. Diff-first review and merge in dependency order
10. Run evals (`evals/run-evals.sh`)

Local orchestration command:

```bash
./scripts/lead-orchestrate.sh \
  --project-dir . \
  --tasks-file tasks/tasks-<4digit>-<slug>.md \
  --dag-file tasks/dag-<4digit>-<slug>.json \
  --approve
```

## PR Automated Review

PR automated review is handled by Codex Web GitHub integration (not GitHub Actions in this template).

## Directory Guide

- `AGENTS.md`: non-negotiable operating rules
- `tasks/`: PRD/TRD/task/DAG contracts and templates
- `tasks/contracts/blackboard/`: JSON schemas for planning-stage blackboard artifacts
- `scripts/`: gate/bootstrap/smoke/orchestration scripts
- `scripts/lib/`: blackboard and stage-routing helpers
- `templates/stacks/`: stack-specific gate adapters
- `ralph/`: loop config and role prompts
- `.github/workflows/`: CI workflows
- `evals/`: regression checks for process quality
- `docs/runbook/`: operational guidance
- `.codex/config.toml`: multi-agent orchestration defaults
- `.agents/skills/`: baseline SOP skills (`create-prd`, `plan-tasks`, `orchestrate-tasks`, `process-task`, `fix-failing-checks`, `pr-review`)
- `.agents/skills/ideation-consultant`, `.agents/skills/trd-architect`: placeholder pipeline contracts for future skill-generated implementations
- `.blackboard/`: runtime blackboard artifacts/events (generated at orchestration time)
- `examples/`: stack starter samples

## Core Skills Baseline

This template ships with six baseline skills under `.agents/skills/`:

- `create-prd`: idea -> `tasks/prd-*.md`
- `plan-tasks`: TRD -> `tasks/tasks-*.md` + `tasks/dag-*.{md,json}`
- `orchestrate-tasks`: DAG/wave orchestration + blackboard integration artifacts
- `process-task`: one task execution (TDD-first) + gate verification
- `fix-failing-checks`: recover failing gate with bounded fixes
- `pr-review`: risk-first diff review

Planning pipeline placeholder skills:

- `ideation-consultant`: ideation artifact contract for upstream product storytelling output
- `trd-architect`: TRD artifact contract for architecture-complete downstream planning input

## check.sh Contract

```bash
./scripts/check.sh --stack <python|node|go> [--changed-only] [--project-dir <path>]
```

`--project-dir` is useful when running the gate from the template root against a generated project path.

Contract rules validated by the gate:

- `tasks/process-rules.md` includes `Trace logging required`
- Task files use `tasks/tasks-<4digit>-<slug>.md`
- PRD files use `tasks/prd-<4digit>-<slug>.md`
- TRD files use `tasks/trd-<4digit>-<slug>.md`
- DAG files use `tasks/dag-<4digit>-<slug>.json` and `tasks/dag-<4digit>-<slug>.md`
- PRD files include section headings for `Problem`, `Goals`, `Non-goals`, `Success Metrics`, `Constraints`, `Test Strategy`, and `Rollout`
- TRD files include architecture sections (`Context`, `Clean Architecture`, `Component Catalog`, `Interface Contracts`, `Dependency Graph`)
- Task metadata includes `TRD`, `Task DAG`, `Task DAG Markdown`, and `Planning Artifact`
- Every `### T-...` block includes `Dependencies`, `Acceptance Criteria`, `Test Plan`, and `Done Definition`
- Task dependencies and DAG JSON dependencies must match exactly
- `Task DAG` and `Task DAG Markdown` metadata paths must match task file id/slug
- Planning artifact metadata path must match `.blackboard/artifacts/task-planning/<4digit>-<slug>.json`
- Blackboard schema files under `tasks/contracts/blackboard/` must exist and be valid JSON

Exit codes:

- `0`: pass
- `1`: check failure
- `2`: configuration/input error

## Troubleshooting

- `ERROR: adapter not found`: verify `templates/stacks/<stack>/check.adapter.sh` exists.
- `ERROR: <tool> not found`: install required runtime (Python/Node/Go).
- CI failure on smoke test: run `./scripts/smoke-test.sh` locally and inspect missing files.
- CI now runs root gate only when it detects root stack markers (`go.mod`, `package.json`, Python project markers).
