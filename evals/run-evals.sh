#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
TRACE_HELPER_DIR="${REPO_ROOT}/evals/lib"
DEFAULT_CASES_DIR="${REPO_ROOT}/evals/cases"

source "${TRACE_HELPER_DIR}/case-profiles.sh"

CASES_DIR="${DEFAULT_CASES_DIR}"
RESULTS_DIR="${REPO_ROOT}/evals/results"
TRACE_MODE="hybrid"
MAX_RETRIES=3
MAX_LOOP_COUNT=8
TRACE_TIMEOUT_SECONDS=90
PROFILE="full"
PROFILE_EXPLICIT=false
LIST_CASES=false

usage() {
  cat <<'USAGE'
Usage: ./evals/run-evals.sh [options]

Options:
  --cases-dir <path>
  --results-dir <path>
  --profile <smoke|orchestration|full>
  --trace-mode <hybrid|trace-only|local-only>
  --max-retries <int>
  --max-loop-count <int>
  --trace-timeout-seconds <int>
  --list-cases

Result format (JSONL):
  {"case_id":"...","passed":true|false,"loop_count":0,"retries":0,"unexpected_files":0,"skill_triggered":false}
USAGE
}

error() {
  echo "[evals] ERROR: $*" >&2
}

is_integer() {
  [[ "$1" =~ ^[0-9]+$ ]]
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cases-dir)
      [[ $# -ge 2 ]] || { error "--cases-dir requires a value"; exit 2; }
      CASES_DIR="$2"
      shift 2
      ;;
    --results-dir)
      [[ $# -ge 2 ]] || { error "--results-dir requires a value"; exit 2; }
      RESULTS_DIR="$2"
      shift 2
      ;;
    --profile)
      [[ $# -ge 2 ]] || { error "--profile requires a value"; exit 2; }
      PROFILE="$2"
      PROFILE_EXPLICIT=true
      shift 2
      ;;
    --trace-mode)
      [[ $# -ge 2 ]] || { error "--trace-mode requires a value"; exit 2; }
      TRACE_MODE="$2"
      shift 2
      ;;
    --max-retries)
      [[ $# -ge 2 ]] || { error "--max-retries requires a value"; exit 2; }
      MAX_RETRIES="$2"
      shift 2
      ;;
    --max-loop-count)
      [[ $# -ge 2 ]] || { error "--max-loop-count requires a value"; exit 2; }
      MAX_LOOP_COUNT="$2"
      shift 2
      ;;
    --trace-timeout-seconds)
      [[ $# -ge 2 ]] || { error "--trace-timeout-seconds requires a value"; exit 2; }
      TRACE_TIMEOUT_SECONDS="$2"
      shift 2
      ;;
    --list-cases)
      LIST_CASES=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      error "unknown argument: $1"
      usage
      exit 2
      ;;
  esac
done

case "${TRACE_MODE}" in
  hybrid|trace-only|local-only)
    ;;
  *)
    error "Unsupported trace mode '${TRACE_MODE}'. Use: hybrid, trace-only, local-only"
    exit 2
    ;;
esac

if ! is_known_eval_profile "${PROFILE}"; then
  error "Unsupported profile '${PROFILE}'. Use: smoke, orchestration, full"
  exit 2
fi

is_integer "${MAX_RETRIES}" || { error "--max-retries must be an integer"; exit 2; }
is_integer "${MAX_LOOP_COUNT}" || { error "--max-loop-count must be an integer"; exit 2; }
is_integer "${TRACE_TIMEOUT_SECONDS}" || { error "--trace-timeout-seconds must be an integer"; exit 2; }

mkdir -p "${RESULTS_DIR}"
RESULT_FILE="${RESULTS_DIR}/$(date +%Y%m%d-%H%M%S)-$$.jsonl"

TOTAL=0
PASSED=0
FAILED=0

snapshot_repo_files() {
  local out_file="$1"
  (
    cd "${REPO_ROOT}"
    find . -type f -not -path './.git/*' | sort > "${out_file}"
  )
}

load_case_meta() {
  local meta_file="$1"
  META_LOOP_COUNT=0
  META_RETRIES=0
  META_SKILL_TRIGGERED=false
  META_ALLOW_UNEXPECTED_FILES=false

  if [[ ! -s "${meta_file}" ]]; then
    return 0
  fi

  if ! command -v jq >/dev/null 2>&1; then
    error "jq is required to parse eval metadata"
    return 1
  fi

  if ! META_LOOP_COUNT="$(jq -re '(.loop_count // 0) | tonumber' "${meta_file}" 2>/dev/null)"; then
    error "invalid loop_count in ${meta_file}"
    return 1
  fi
  if ! META_RETRIES="$(jq -re '(.retries // 0) | tonumber' "${meta_file}" 2>/dev/null)"; then
    error "invalid retries in ${meta_file}"
    return 1
  fi
  if ! META_SKILL_TRIGGERED="$(jq -re 'if (.skill_triggered // false) then "true" else "false" end' "${meta_file}" 2>/dev/null)"; then
    error "invalid skill_triggered in ${meta_file}"
    return 1
  fi
  if ! META_ALLOW_UNEXPECTED_FILES="$(jq -re 'if (.allow_unexpected_files // false) then "true" else "false" end' "${meta_file}" 2>/dev/null)"; then
    error "invalid allow_unexpected_files in ${meta_file}"
    return 1
  fi

  return 0
}

write_result() {
  local case_id="$1"
  local pass_flag="$2"
  local loop_count="$3"
  local retries="$4"
  local unexpected_files="$5"
  local skill_triggered="$6"

  printf '{"case_id":"%s","passed":%s,"loop_count":%s,"retries":%s,"unexpected_files":%s,"skill_triggered":%s}\n' \
    "$case_id" "$pass_flag" "$loop_count" "$retries" "$unexpected_files" "$skill_triggered" >> "${RESULT_FILE}"
}

cases_dir_has_scripts() {
  local case_script
  for case_script in "${CASES_DIR}"/*.case.sh; do
    [[ -e "${case_script}" ]] && return 0
  done
  return 1
}

collect_selected_case_scripts() {
  local case_file
  local case_script

  if ! cases_dir_has_scripts; then
    return 0
  fi

  if [[ "${CASES_DIR}" != "${DEFAULT_CASES_DIR}" ]] && [[ "${PROFILE_EXPLICIT}" != "true" ]]; then
    for case_script in "${CASES_DIR}"/*.case.sh; do
      [[ -e "${case_script}" ]] || continue
      printf '%s\n' "${case_script}"
    done
    return 0
  fi

  while IFS= read -r case_file; do
    [[ -n "${case_file}" ]] || continue
    case_script="${CASES_DIR}/${case_file}"
    if [[ -f "${case_script}" ]]; then
      printf '%s\n' "${case_script}"
      continue
    fi
    if [[ "${CASES_DIR}" == "${DEFAULT_CASES_DIR}" ]]; then
      error "profile '${PROFILE}' is missing case '${case_file}'"
      return 1
    fi
  done < <(print_eval_profile_cases "${PROFILE}")

  return 0
}

load_selected_case_scripts() {
  local selected_file
  local case_script

  selected_case_scripts=()
  selected_file="$(mktemp)"

  if ! collect_selected_case_scripts > "${selected_file}"; then
    rm -f "${selected_file}"
    return 1
  fi

  while IFS= read -r case_script; do
    [[ -n "${case_script}" ]] || continue
    selected_case_scripts+=("${case_script}")
  done < "${selected_file}"

  rm -f "${selected_file}"
  return 0
}

run_case_script() {
  local case_script="$1"
  local case_id="$2"

  local before_file
  local after_file
  local new_files_file
  local meta_file
  local case_status
  local unexpected_files
  local reasons=()
  local pass_flag=true

  before_file="$(mktemp)"
  after_file="$(mktemp)"
  new_files_file="$(mktemp)"
  meta_file="$(mktemp)"

  snapshot_repo_files "${before_file}"

  set +e
  EVAL_META_PATH="${meta_file}" \
  EVAL_TRACE_MODE="${TRACE_MODE}" \
  EVAL_TRACE_TIMEOUT_SECONDS="${TRACE_TIMEOUT_SECONDS}" \
  EVAL_MAX_RETRIES="${MAX_RETRIES}" \
  EVAL_MAX_LOOP_COUNT="${MAX_LOOP_COUNT}" \
  EVAL_REPO_ROOT="${REPO_ROOT}" \
  EVAL_TRACE_HELPER_DIR="${TRACE_HELPER_DIR}" \
  bash "${case_script}"
  case_status=$?
  set -e

  snapshot_repo_files "${after_file}"
  comm -13 "${before_file}" "${after_file}" > "${new_files_file}"
  unexpected_files="$(grep -c . "${new_files_file}" || true)"

  if ! load_case_meta "${meta_file}"; then
    pass_flag=false
    reasons+=("invalid_case_meta")
  fi

  if [[ "${case_status}" -ne 0 ]]; then
    pass_flag=false
    reasons+=("case_script_failed")
  fi

  if [[ "${META_RETRIES}" -gt "${MAX_RETRIES}" ]]; then
    pass_flag=false
    reasons+=("retries>${MAX_RETRIES}")
  fi
  if [[ "${META_LOOP_COUNT}" -gt "${MAX_LOOP_COUNT}" ]]; then
    pass_flag=false
    reasons+=("loop_count>${MAX_LOOP_COUNT}")
  fi
  if [[ "${unexpected_files}" -gt 0 ]] && [[ "${META_ALLOW_UNEXPECTED_FILES}" != "true" ]]; then
    pass_flag=false
    reasons+=("unexpected_files>0")
  fi

  if [[ "${pass_flag}" == "true" ]]; then
    PASSED=$((PASSED + 1))
    write_result "${case_id}" true "${META_LOOP_COUNT}" "${META_RETRIES}" "${unexpected_files}" "${META_SKILL_TRIGGERED}"
    echo "[evals] PASS: ${case_id}"
  else
    FAILED=$((FAILED + 1))
    write_result "${case_id}" false "${META_LOOP_COUNT}" "${META_RETRIES}" "${unexpected_files}" "${META_SKILL_TRIGGERED}"
    echo "[evals] FAIL: ${case_id} (${reasons[*]})"
    if [[ "${unexpected_files}" -gt 0 ]]; then
      echo "[evals] INFO: unexpected files:"
      sed 's/^/  - /' "${new_files_file}"
    fi
  fi

  rm -f "${before_file}" "${after_file}" "${new_files_file}" "${meta_file}"
}

echo "[evals] Profile: ${PROFILE}"

FOUND_EXTERNAL_CASES=0
selected_case_scripts=()
if cases_dir_has_scripts; then
  if ! load_selected_case_scripts; then
    exit 2
  fi

  if [[ "${#selected_case_scripts[@]}" -eq 0 ]]; then
    error "no cases matched profile '${PROFILE}' under ${CASES_DIR}"
    exit 2
  fi

  FOUND_EXTERNAL_CASES=1
fi

if [[ "${LIST_CASES}" == "true" ]]; then
  if [[ "${FOUND_EXTERNAL_CASES}" -eq 0 ]]; then
    error "--list-cases requires at least one *.case.sh file under ${CASES_DIR}"
    exit 2
  fi
  for case_script in "${selected_case_scripts[@]}"; do
    basename "${case_script}" .case.sh
  done
  exit 0
fi

for case_script in "${selected_case_scripts[@]}"; do
  case_id="$(basename "${case_script}" .case.sh)"
  TOTAL=$((TOTAL + 1))
  run_case_script "${case_script}" "${case_id}"
done

if [[ "${FOUND_EXTERNAL_CASES}" -eq 0 ]]; then
  echo "[evals] INFO: no *.case.sh files found; running default baseline evals"

  inline_case() {
    local case_id="$1"
    shift

    TOTAL=$((TOTAL + 1))
    if "$@"; then
      PASSED=$((PASSED + 1))
      write_result "${case_id}" true 0 0 0 false
      echo "[evals] PASS: ${case_id}"
    else
      FAILED=$((FAILED + 1))
      write_result "${case_id}" false 0 0 0 false
      echo "[evals] FAIL: ${case_id}"
    fi
  }

  inline_case "required_path_agents" test -f "${REPO_ROOT}/AGENTS.md"
  inline_case "required_path_check_script" test -f "${REPO_ROOT}/scripts/check.sh"
  inline_case "required_path_process_rules" test -f "${REPO_ROOT}/tasks/process-rules.md"
  inline_case "check_cli_contract" bash -c "${REPO_ROOT}/scripts/check.sh --help >/dev/null"
fi

echo "[evals] Result file: ${RESULT_FILE}"
echo "[evals] Summary: total=${TOTAL} passed=${PASSED} failed=${FAILED}"

if [[ "${FAILED}" -gt 0 ]]; then
  exit 1
fi

exit 0
