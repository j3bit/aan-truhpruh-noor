#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

assert_file() {
  local path="$1"
  [[ -f "$path" ]] || { echo "[smoke] ERROR: missing file: $path" >&2; exit 1; }
}

run_bootstrap_check() {
  local stacks="$1"
  local root_dir="$2"
  local name_suffix
  name_suffix="$(printf '%s' "${stacks}" | tr ',' '-')"
  local target="${root_dir}/bootstrap-${name_suffix}"

  bash "${REPO_ROOT}/scripts/bootstrap-new-project.sh" \
    --name "bootstrap-${name_suffix}" \
    --stacks "${stacks}" \
    --dest "${target}"

  assert_file "${target}/AGENTS.md"
  assert_file "${target}/.codex/config.toml"
  assert_file "${target}/tasks/process-rules.md"
  assert_file "${target}/tasks/stacks.json"
  assert_file "${target}/tasks/templates/trd.template.md"
  assert_file "${target}/tasks/templates/dag.template.md"
  assert_file "${target}/tasks/templates/dag.template.json"
  assert_file "${target}/tasks/contracts/blackboard/ideation-output.schema.json"
  assert_file "${target}/tasks/contracts/blackboard/trd-output.schema.json"
  assert_file "${target}/tasks/contracts/blackboard/task-planning-output.schema.json"
  assert_file "${target}/scripts/check.sh"
  assert_file "${target}/scripts/lead-orchestrate.sh"
  assert_file "${target}/scripts/run-sub-agent.sh"
  assert_file "${target}/scripts/qa-generate-scenarios.sh"
  assert_file "${target}/scripts/qa-pipeline.sh"
  assert_file "${target}/scripts/static-review.sh"
  assert_file "${target}/scripts/validate-contracts.sh"
  assert_file "${target}/scripts/lib/stack-registry.sh"
  assert_file "${target}/scripts/lib/blackboard.sh"
  assert_file "${target}/scripts/lib/stage-router.sh"
  assert_file "${target}/.github/workflows/check.yml"
  assert_file "${target}/.agents/skills/plan-tasks/SKILL.md"
  assert_file "${target}/.agents/skills/orchestrate-tasks/SKILL.md"
  assert_file "${target}/.agents/skills/process-task/SKILL.md"
  assert_file "${target}/.agents/skills/ideation-consultant/SKILL.md"
  assert_file "${target}/.agents/skills/ideation-consultant/references/ideation-contract.md"
  assert_file "${target}/.agents/skills/trd-architect/SKILL.md"
  assert_file "${target}/.agents/skills/trd-architect/references/trd-contract.md"
  assert_file "${target}/evals/run-evals.sh"
  assert_file "${target}/evals/lib/collect-trace.sh"
  assert_file "${target}/evals/lib/parse-trace.sh"

  if command -v bash >/dev/null 2>&1; then
    (cd "${target}" && bash ./scripts/check.sh --stacks auto)
  fi
}

echo "[smoke] Running shell syntax checks"
while IFS= read -r -d '' file; do
  bash -n "$file"
done < <(find "${REPO_ROOT}/scripts" "${REPO_ROOT}/templates/stacks" "${REPO_ROOT}/evals" -type f -name '*.sh' -print0)

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

run_bootstrap_check "python" "${TMP_DIR}"
run_bootstrap_check "node" "${TMP_DIR}"
run_bootstrap_check "go" "${TMP_DIR}"
run_bootstrap_check "python,node" "${TMP_DIR}"

echo "[smoke] PASS"
