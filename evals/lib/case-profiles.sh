#!/usr/bin/env bash
set -euo pipefail

readonly EVAL_SMOKE_CASES=(
  "01-required-artifacts.case.sh"
  "02-contract-trace-rule.case.sh"
  "03-gate-filename-enforcement.case.sh"
  "04-gate-done-definition-enforcement.case.sh"
  "07-bootstrap-artifact-hygiene.case.sh"
  "08-prd-required-sections.case.sh"
  "12-dag-contract-enforcement.case.sh"
  "23-registry-required-validation.case.sh"
  "24-changed-only-stack-selection.case.sh"
  "25-unmatched-changes-fallback-all-stacks.case.sh"
  "26-dag-gate-stacks-validation.case.sh"
  "27-bootstrap-multi-stack.case.sh"
  "28-migration-regression.case.sh"
  "29-deleted-file-stack-selection.case.sh"
  "30-cross-stack-rename-selection.case.sh"
  "31-owned-path-comma-glob-selection.case.sh"
  "32-custom-registry-path-contract.case.sh"
)

readonly EVAL_ORCHESTRATION_EXTRA_CASES=(
  "09-lead-orchestration-contract.case.sh"
  "10-lead-orchestration-e2e.case.sh"
  "11-stage-adjacency-enforcement.case.sh"
  "13-integration-artifact-generation.case.sh"
  "14-qa-strict-relay.case.sh"
  "15-fast-profile-fallback.case.sh"
  "16-parallel-safe-wave-enforcement.case.sh"
  "17-planning-pipeline-contract.case.sh"
  "18-plan-tasks-trd-primary-contract.case.sh"
  "19-task-dag-artifact-metadata-contract.case.sh"
  "20-worker-result-contract.case.sh"
  "21-qa-static-hard-gate.case.sh"
  "22-ci-qa-release-readiness.case.sh"
  "33-sub-agent-custom-registry.case.sh"
)

readonly EVAL_FULL_EXTRA_CASES=(
  "05-trace-hybrid-fallback.case.sh"
  "06-metrics-thrash-unexpected.case.sh"
)

is_known_eval_profile() {
  local profile="${1:-}"
  case "${profile}" in
    smoke|orchestration|full)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

print_eval_profile_cases() {
  local profile="${1:-}"
  case "${profile}" in
    smoke)
      printf '%s\n' "${EVAL_SMOKE_CASES[@]}"
      ;;
    orchestration)
      printf '%s\n' "${EVAL_SMOKE_CASES[@]}"
      printf '%s\n' "${EVAL_ORCHESTRATION_EXTRA_CASES[@]}"
      ;;
    full)
      printf '%s\n' "${EVAL_SMOKE_CASES[@]}"
      printf '%s\n' "${EVAL_ORCHESTRATION_EXTRA_CASES[@]}"
      printf '%s\n' "${EVAL_FULL_EXTRA_CASES[@]}"
      ;;
    *)
      echo "[evals] ERROR: unknown profile '${profile}'" >&2
      return 1
      ;;
  esac
}
