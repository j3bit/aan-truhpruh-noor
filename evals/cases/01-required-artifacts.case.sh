#!/usr/bin/env bash
set -euo pipefail

ROOT="${EVAL_REPO_ROOT:-$(pwd)}"

required_paths=(
  "AGENTS.md"
  "scripts/check.sh"
  "scripts/lead-orchestrate.sh"
  "scripts/run-sub-agent.sh"
  "scripts/qa-generate-scenarios.sh"
  "scripts/qa-pipeline.sh"
  "scripts/static-review.sh"
  "scripts/validate-contracts.sh"
  "scripts/lib/blackboard.sh"
  "scripts/lib/stage-router.sh"
  "tasks/process-rules.md"
  "tasks/templates/prd.template.md"
  "tasks/templates/trd.template.md"
  "tasks/templates/tasks.template.md"
  "tasks/templates/dag.template.md"
  "tasks/templates/dag.template.json"
  ".codex/config.toml"
  ".agents/skills/create-prd/SKILL.md"
  ".agents/skills/plan-tasks/SKILL.md"
  ".agents/skills/orchestrate-tasks/SKILL.md"
  ".agents/skills/process-task/SKILL.md"
  ".agents/skills/fix-failing-checks/SKILL.md"
  ".agents/skills/pr-review/SKILL.md"
  "evals/run-evals.sh"
  "evals/lib/collect-trace.sh"
  "evals/lib/parse-trace.sh"
  "evals/cases/07-bootstrap-artifact-hygiene.case.sh"
  "evals/cases/08-prd-required-sections.case.sh"
  "evals/cases/09-lead-orchestration-contract.case.sh"
  "evals/cases/10-lead-orchestration-e2e.case.sh"
  "evals/cases/11-stage-adjacency-enforcement.case.sh"
  "evals/cases/12-dag-contract-enforcement.case.sh"
  "evals/cases/13-integration-artifact-generation.case.sh"
  "evals/cases/14-qa-strict-relay.case.sh"
  "evals/cases/15-fast-profile-fallback.case.sh"
  "evals/cases/20-worker-result-contract.case.sh"
  "evals/cases/21-qa-static-hard-gate.case.sh"
  "evals/cases/22-ci-qa-release-readiness.case.sh"
  "docs/runbook/01-workflow.md"
  "docs/runbook/03-multi-agent.md"
  "docs/runbook/04-ralph.md"
  "docs/runbook/05-evals.md"
)

for rel in "${required_paths[@]}"; do
  if [[ ! -e "${ROOT}/${rel}" ]]; then
    echo "[case-01] missing required artifact: ${rel}" >&2
    exit 1
  fi
done
