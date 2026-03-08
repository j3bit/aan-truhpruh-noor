#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

assert_file() {
  local path="$1"
  [[ -f "$path" ]] || { echo "[smoke] ERROR: missing file: $path" >&2; exit 1; }
}

stack_runtime_ready() {
  local stack="$1"
  case "${stack}" in
    python)
      command -v python3 >/dev/null 2>&1 || command -v python >/dev/null 2>&1
      ;;
    node)
      command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1
      ;;
    go)
      command -v go >/dev/null 2>&1
      ;;
    *)
      return 0
      ;;
  esac
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
  assert_file "${target}/.agents/skills/develop-concept/SKILL.md"
  assert_file "${target}/.agents/skills/develop-concept/references/concept-contract.md"
  assert_file "${target}/.agents/skills/create-trd/SKILL.md"
  assert_file "${target}/.agents/skills/create-trd/references/trd-contract.md"
  assert_file "${target}/evals/run-evals.sh"
  assert_file "${target}/evals/lib/collect-trace.sh"
  assert_file "${target}/evals/lib/parse-trace.sh"
  assert_file "${target}/evals/cases/01-required-artifacts.case.sh"
  assert_file "${target}/evals/cases/02-contract-trace-rule.case.sh"
  assert_file "${target}/evals/cases/03-gate-filename-enforcement.case.sh"
  assert_file "${target}/evals/cases/04-gate-done-definition-enforcement.case.sh"
  assert_file "${target}/evals/cases/05-trace-hybrid-fallback.case.sh"
  assert_file "${target}/evals/cases/06-metrics-thrash-unexpected.case.sh"
  assert_file "${target}/evals/cases/07-bootstrap-artifact-hygiene.case.sh"
  assert_file "${target}/evals/cases/08-prd-required-sections.case.sh"
  assert_file "${target}/evals/cases/09-lead-orchestration-contract.case.sh"
  assert_file "${target}/evals/cases/10-lead-orchestration-e2e.case.sh"
  assert_file "${target}/evals/cases/11-stage-adjacency-enforcement.case.sh"
  assert_file "${target}/evals/cases/12-dag-contract-enforcement.case.sh"
  assert_file "${target}/evals/cases/13-integration-artifact-generation.case.sh"
  assert_file "${target}/evals/cases/14-qa-strict-relay.case.sh"
  assert_file "${target}/evals/cases/15-fast-profile-fallback.case.sh"
  assert_file "${target}/evals/cases/16-parallel-safe-wave-enforcement.case.sh"
  assert_file "${target}/evals/cases/17-planning-pipeline-contract.case.sh"
  assert_file "${target}/evals/cases/18-plan-tasks-trd-primary-contract.case.sh"
  assert_file "${target}/evals/cases/19-task-dag-artifact-metadata-contract.case.sh"
  assert_file "${target}/evals/cases/20-worker-result-contract.case.sh"
  assert_file "${target}/evals/cases/21-qa-static-hard-gate.case.sh"
  assert_file "${target}/evals/cases/22-ci-qa-release-readiness.case.sh"
  assert_file "${target}/docs/runbook/03-multi-agent.md"
  assert_file "${target}/docs/runbook/04-ralph.md"

  if command -v bash >/dev/null 2>&1; then
    runnable_stacks=()
    missing_stacks=()
    while IFS= read -r stack_name; do
      stack_name="$(printf '%s' "${stack_name}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
      [[ -n "${stack_name}" ]] || continue
      if stack_runtime_ready "${stack_name}"; then
        runnable_stacks+=("${stack_name}")
      else
        missing_stacks+=("${stack_name}")
      fi
    done < <(printf '%s\n' "${stacks}" | tr ',' '\n')

    if [[ "${#missing_stacks[@]}" -gt 0 ]]; then
      echo "[smoke] INFO: skipping unavailable stack toolchains for ${target}: $(printf '%s\n' "${missing_stacks[@]}" | paste -sd ',' -)"
    fi

    if [[ "${#runnable_stacks[@]}" -eq 0 ]]; then
      echo "[smoke] INFO: no runnable stacks for ${target}; skipping gate run"
    else
      runnable_csv="$(printf '%s\n' "${runnable_stacks[@]}" | paste -sd ',' -)"
      (cd "${target}" && bash ./scripts/check.sh --stacks "${runnable_csv}")
    fi
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
