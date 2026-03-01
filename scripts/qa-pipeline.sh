#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

PROJECT_DIR="${PWD}"
STACK=""
TASKS_FILE=""
TRD_FILE=""
PRD_FILE=""
REPORT_DIR=""

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/qa-pipeline.sh \
    --project-dir <path> \
    --stack <python|node|go> \
    [--tasks-file <path>] \
    [--trd-file <path>] \
    [--prd-file <path>] \
    [--report-dir <path>]
USAGE
}

error() {
  echo "[qa-pipeline] ERROR: $*" >&2
}

to_abs() {
  local path="$1"
  if [[ "${path}" == /* ]]; then
    printf '%s' "${path}"
  else
    printf '%s/%s' "${PROJECT_DIR}" "${path}"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-dir)
      PROJECT_DIR="$2"
      shift 2
      ;;
    --stack)
      STACK="$2"
      shift 2
      ;;
    --tasks-file)
      TASKS_FILE="$2"
      shift 2
      ;;
    --trd-file)
      TRD_FILE="$2"
      shift 2
      ;;
    --prd-file)
      PRD_FILE="$2"
      shift 2
      ;;
    --report-dir)
      REPORT_DIR="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      error "Unknown argument: $1"
      usage
      exit 2
      ;;
  esac
done

if [[ -z "${STACK}" ]]; then
  error "--stack is required"
  exit 2
fi

case "${STACK}" in
  python|node|go) ;;
  *)
    error "Unsupported stack '${STACK}'"
    exit 2
    ;;
esac

if [[ ! -d "${PROJECT_DIR}" ]]; then
  error "Project directory does not exist: ${PROJECT_DIR}"
  exit 2
fi
PROJECT_DIR="$(cd -- "${PROJECT_DIR}" && pwd -P)"

if [[ -z "${REPORT_DIR}" ]]; then
  REPORT_DIR="${PROJECT_DIR}/.orchestration/reports"
fi
REPORT_DIR="$(to_abs "${REPORT_DIR}")"
mkdir -p "${REPORT_DIR}" "${PROJECT_DIR}/.blackboard/feedback/qa"

if [[ -z "${TASKS_FILE}" ]]; then
  candidates=("${PROJECT_DIR}"/tasks/tasks-*.md)
  if [[ -e "${candidates[0]}" ]] && [[ "${#candidates[@]}" -eq 1 ]]; then
    TASKS_FILE="${candidates[0]}"
  fi
fi

qa_scenario_cmd=(
  bash "${REPO_ROOT}/scripts/qa-generate-scenarios.sh"
  --project-dir "${PROJECT_DIR}"
)
if [[ -n "${TASKS_FILE}" ]]; then
  qa_scenario_cmd+=(--tasks-file "${TASKS_FILE}")
fi
if [[ -n "${TRD_FILE}" ]]; then
  qa_scenario_cmd+=(--trd-file "${TRD_FILE}")
fi
if [[ -n "${PRD_FILE}" ]]; then
  qa_scenario_cmd+=(--prd-file "${PRD_FILE}")
fi

QA_SCENARIO_PATH="$("${qa_scenario_cmd[@]}")"

QA_COMMANDS_FILE="$(mktemp)"
QA_FAILURES_FILE="$(mktemp)"
trap 'rm -f "${QA_COMMANDS_FILE}" "${QA_FAILURES_FILE}"' EXIT

run_test_shell() {
  local label="$1"
  local command="$2"
  echo "${label} :: ${command}" >> "${QA_COMMANDS_FILE}"
  if bash -lc "${command}"; then
    return 0
  fi
  echo "${label}" >> "${QA_FAILURES_FILE}"
  return 1
}

cd "${PROJECT_DIR}"

case "${STACK}" in
  python)
    if command -v pytest >/dev/null 2>&1; then
      integration_targets="$(find . -type f \( -name 'test_*integration*.py' -o -name '*integration*_test.py' \) -not -path './.git/*' | sort | tr '\n' ' ')"
      e2e_targets="$(find . -type f \( -name 'test_*e2e*.py' -o -name '*e2e*_test.py' \) -not -path './.git/*' | sort | tr '\n' ' ')"

      if [[ -n "${integration_targets}" ]]; then
        run_test_shell "integration-tests" "pytest -q ${integration_targets}" || true
      else
        echo "integration-tests :: skipped(no matching files)" >> "${QA_COMMANDS_FILE}"
      fi

      if [[ -n "${e2e_targets}" ]]; then
        run_test_shell "e2e-tests" "pytest -q ${e2e_targets}" || true
      else
        echo "e2e-tests :: skipped(no matching files)" >> "${QA_COMMANDS_FILE}"
      fi
    else
      echo "integration-tests :: skipped(pytest missing)" >> "${QA_COMMANDS_FILE}"
      echo "e2e-tests :: skipped(pytest missing)" >> "${QA_COMMANDS_FILE}"
    fi
    ;;
  node)
    if [[ -f package.json ]]; then
      if node -e "const fs=require('node:fs');const pkg=JSON.parse(fs.readFileSync('package.json','utf8'));process.exit(pkg.scripts && pkg.scripts['test:integration'] ? 0 : 1);"; then
        run_test_shell "integration-tests" "npm run --silent test:integration" || true
      else
        echo "integration-tests :: skipped(script missing)" >> "${QA_COMMANDS_FILE}"
      fi

      if node -e "const fs=require('node:fs');const pkg=JSON.parse(fs.readFileSync('package.json','utf8'));process.exit(pkg.scripts && pkg.scripts['test:e2e'] ? 0 : 1);"; then
        run_test_shell "e2e-tests" "npm run --silent test:e2e" || true
      else
        echo "e2e-tests :: skipped(script missing)" >> "${QA_COMMANDS_FILE}"
      fi
    else
      echo "integration-tests :: skipped(package.json missing)" >> "${QA_COMMANDS_FILE}"
      echo "e2e-tests :: skipped(package.json missing)" >> "${QA_COMMANDS_FILE}"
    fi
    ;;
  go)
    integration_targets="$(find . -type f -name '*integration*_test.go' -not -path './.git/*' | sort | tr '\n' ' ')"
    e2e_targets="$(find . -type f -name '*e2e*_test.go' -not -path './.git/*' | sort | tr '\n' ' ')"

    if [[ -n "${integration_targets}" ]]; then
      run_test_shell "integration-tests" "go test ${integration_targets}" || true
    else
      echo "integration-tests :: skipped(no matching files)" >> "${QA_COMMANDS_FILE}"
    fi

    if [[ -n "${e2e_targets}" ]]; then
      run_test_shell "e2e-tests" "go test ${e2e_targets}" || true
    else
      echo "e2e-tests :: skipped(no matching files)" >> "${QA_COMMANDS_FILE}"
    fi
    ;;
esac

STATIC_REPORT="${REPORT_DIR}/static-review.json"
if ! bash "${REPO_ROOT}/scripts/static-review.sh" --project-dir "${PROJECT_DIR}" --stack "${STACK}" --out-file "${STATIC_REPORT}"; then
  echo "static-review" >> "${QA_FAILURES_FILE}"
fi

FAIL_COUNT="$(grep -c . "${QA_FAILURES_FILE}" || true)"
NOW_UTC="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
QA_REPORT="${REPORT_DIR}/qa-report.json"

COMMANDS_JSON="$(perl -MJSON::PP -e '
  use strict;
  use warnings;
  my ($path) = @ARGV;
  my @rows;
  if (open my $fh, "<", $path) {
    while (my $line = <$fh>) {
      chomp $line;
      next if $line eq "";
      push @rows, $line;
    }
    close $fh;
  }
  print encode_json(\@rows);
' "${QA_COMMANDS_FILE}")"

FAILS_JSON="$(perl -MJSON::PP -e '
  use strict;
  use warnings;
  my ($path) = @ARGV;
  my @rows;
  if (open my $fh, "<", $path) {
    while (my $line = <$fh>) {
      chomp $line;
      next if $line eq "";
      push @rows, $line;
    }
    close $fh;
  }
  print encode_json(\@rows);
' "${QA_FAILURES_FILE}")"

cat > "${QA_REPORT}" <<EOF_JSON
{
  "generated_at": "${NOW_UTC}",
  "stack": "${STACK}",
  "scenario_path": "${QA_SCENARIO_PATH#${PROJECT_DIR}/}",
  "commands": ${COMMANDS_JSON},
  "failures": ${FAILS_JSON},
  "passed": $([[ "${FAIL_COUNT}" -eq 0 ]] && echo true || echo false)
}
EOF_JSON

if [[ "${FAIL_COUNT}" -gt 0 ]]; then
  FAILURE_BUNDLE="${PROJECT_DIR}/.blackboard/feedback/qa/qa-failure-$(date +%s).json"
  cat > "${FAILURE_BUNDLE}" <<EOF_JSON
{
  "generated_at": "${NOW_UTC}",
  "stack": "${STACK}",
  "qa_report": "${QA_REPORT#${PROJECT_DIR}/}",
  "failed_checks": ${FAILS_JSON},
  "reason": "qa_pipeline_failed"
}
EOF_JSON
  cat "${QA_REPORT}"
  exit 1
fi

cat "${QA_REPORT}"
exit 0
