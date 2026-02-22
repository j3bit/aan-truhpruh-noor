#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

CASES_DIR="${REPO_ROOT}/evals/cases"
RESULTS_DIR="${REPO_ROOT}/evals/results"

usage() {
  cat <<'USAGE'
Usage:
  ./evals/run-evals.sh [--cases-dir <path>] [--results-dir <path>]

Result format (JSONL):
  {"case_id":"...","passed":true|false,"loop_count":0,"retries":0,"unexpected_files":0}
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cases-dir)
      [[ $# -ge 2 ]] || { echo "[evals] ERROR: --cases-dir requires a value" >&2; exit 2; }
      CASES_DIR="$2"
      shift 2
      ;;
    --results-dir)
      [[ $# -ge 2 ]] || { echo "[evals] ERROR: --results-dir requires a value" >&2; exit 2; }
      RESULTS_DIR="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[evals] ERROR: unknown argument: $1" >&2
      usage
      exit 2
      ;;
  esac
done

mkdir -p "${RESULTS_DIR}"
RESULT_FILE="${RESULTS_DIR}/$(date +%Y%m%d-%H%M%S).jsonl"

TOTAL=0
PASSED=0
FAILED=0

write_result() {
  local case_id="$1"
  local pass_flag="$2"
  local loop_count="$3"
  local retries="$4"
  local unexpected_files="$5"

  printf '{"case_id":"%s","passed":%s,"loop_count":%s,"retries":%s,"unexpected_files":%s}\n' \
    "$case_id" "$pass_flag" "$loop_count" "$retries" "$unexpected_files" >> "${RESULT_FILE}"
}

run_case_cmd() {
  local case_id="$1"
  shift

  TOTAL=$((TOTAL + 1))
  if "$@"; then
    PASSED=$((PASSED + 1))
    write_result "$case_id" true 0 0 0
    echo "[evals] PASS: $case_id"
  else
    FAILED=$((FAILED + 1))
    write_result "$case_id" false 0 0 0
    echo "[evals] FAIL: $case_id"
  fi
}

FOUND_EXTERNAL_CASES=0
for case_script in "${CASES_DIR}"/*.case.sh; do
  if [[ ! -e "${case_script}" ]]; then
    break
  fi

  FOUND_EXTERNAL_CASES=1
  case_id="$(basename "${case_script}" .case.sh)"
  TOTAL=$((TOTAL + 1))

  if bash "${case_script}"; then
    PASSED=$((PASSED + 1))
    write_result "$case_id" true 0 0 0
    echo "[evals] PASS: $case_id"
  else
    FAILED=$((FAILED + 1))
    write_result "$case_id" false 0 0 0
    echo "[evals] FAIL: $case_id"
  fi
done

if [[ "${FOUND_EXTERNAL_CASES}" -eq 0 ]]; then
  echo "[evals] INFO: no *.case.sh files found; running default baseline evals"

  run_case_cmd "required_path_agents" test -f "${REPO_ROOT}/AGENTS.md"
  run_case_cmd "required_path_check_script" test -f "${REPO_ROOT}/scripts/check.sh"
  run_case_cmd "required_path_process_rules" test -f "${REPO_ROOT}/tasks/process-rules.md"
  run_case_cmd "check_cli_contract" bash -c "${REPO_ROOT}/scripts/check.sh --help >/dev/null"
fi

echo "[evals] Result file: ${RESULT_FILE}"
echo "[evals] Summary: total=${TOTAL} passed=${PASSED} failed=${FAILED}"

if [[ "${FAILED}" -gt 0 ]]; then
  exit 1
fi

exit 0
