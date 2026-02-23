#!/usr/bin/env bash
set -euo pipefail

ROOT="${EVAL_REPO_ROOT:-$(pwd)}"

required_paths=(
  "AGENTS.md"
  "scripts/check.sh"
  "scripts/validate-contracts.sh"
  "tasks/process-rules.md"
  "tasks/templates/prd.template.md"
  "tasks/templates/tasks.template.md"
  ".agents/skills/create-prd/SKILL.md"
  ".agents/skills/generate-tasks/SKILL.md"
  ".agents/skills/process-task/SKILL.md"
  ".agents/skills/fix-failing-checks/SKILL.md"
  ".agents/skills/pr-review/SKILL.md"
  "evals/run-evals.sh"
  "evals/lib/collect-trace.sh"
  "evals/lib/parse-trace.sh"
  "evals/cases/07-bootstrap-artifact-hygiene.case.sh"
  "docs/runbook/01-workflow.md"
  "docs/runbook/05-evals.md"
)

for rel in "${required_paths[@]}"; do
  if [[ ! -e "${ROOT}/${rel}" ]]; then
    echo "[case-01] missing required artifact: ${rel}" >&2
    exit 1
  fi
done
