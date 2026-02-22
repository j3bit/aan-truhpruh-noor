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
  "evals/run-evals.sh"
  "evals/lib/collect-trace.sh"
  "evals/lib/parse-trace.sh"
  "docs/runbook/01-workflow.md"
  "docs/runbook/05-evals.md"
)

for rel in "${required_paths[@]}"; do
  if [[ ! -e "${ROOT}/${rel}" ]]; then
    echo "[case-01] missing required artifact: ${rel}" >&2
    exit 1
  fi
done
