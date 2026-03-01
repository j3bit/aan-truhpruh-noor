#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

if [[ ! -f "${REPO_ROOT}/scripts/lib/stack-registry.sh" ]]; then
  echo "[qa-pipeline] ERROR: missing stack registry library" >&2
  exit 2
fi

# shellcheck source=/dev/null
source "${REPO_ROOT}/scripts/lib/stack-registry.sh"

PROJECT_DIR="${PWD}"
STACKS_ARG=""
REGISTRY_PATH="tasks/stacks.json"
TASKS_FILE=""
TRD_FILE=""
PRD_FILE=""
REPORT_DIR=""

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/qa-pipeline.sh \
    --project-dir <path> \
    --stacks <csv|auto> \
    [--registry <path>] \
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
    --stacks)
      STACKS_ARG="$2"
      shift 2
      ;;
    --registry)
      REGISTRY_PATH="$2"
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

if [[ -z "${STACKS_ARG}" ]]; then
  error "--stacks is required"
  exit 2
fi

if [[ ! -d "${PROJECT_DIR}" ]]; then
  error "Project directory does not exist: ${PROJECT_DIR}"
  exit 2
fi
PROJECT_DIR="$(cd -- "${PROJECT_DIR}" && pwd -P)"

REGISTRY_ABS="$(stack_registry_resolve_path "${PROJECT_DIR}" "${REGISTRY_PATH}")"
if [[ ! -f "${REGISTRY_ABS}" ]]; then
  error "Stack registry not found: ${REGISTRY_ABS}"
  exit 2
fi
if ! stack_registry_validate "${REGISTRY_ABS}" "${PROJECT_DIR}"; then
  error "Invalid stack registry: ${REGISTRY_ABS}"
  exit 2
fi

STACKS_FILE="$(mktemp)"
QA_COMMANDS_FILE="$(mktemp)"
QA_FAILURES_FILE="$(mktemp)"
STATIC_REPORT_INDEX_FILE="$(mktemp)"
cleanup() {
  rm -f "${STACKS_FILE}" "${QA_COMMANDS_FILE}" "${QA_FAILURES_FILE}" "${STATIC_REPORT_INDEX_FILE}"
}
trap cleanup EXIT

if [[ "${STACKS_ARG}" == "auto" ]]; then
  stack_registry_list_names "${REGISTRY_ABS}" > "${STACKS_FILE}"
else
  : > "${STACKS_FILE}"
  while IFS= read -r stack_name; do
    [[ -z "${stack_name}" ]] && continue
    if ! stack_registry_stack_exists "${REGISTRY_ABS}" "${stack_name}"; then
      error "Unknown stack '${stack_name}' in --stacks"
      exit 2
    fi
    echo "${stack_name}" >> "${STACKS_FILE}"
  done < <(stack_registry_csv_normalize "${STACKS_ARG}")
fi

if [[ ! -s "${STACKS_FILE}" ]]; then
  error "No stacks selected"
  exit 2
fi

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

if [[ -n "${TASKS_FILE}" ]]; then
  qa_scenario_cmd=(
    bash "${REPO_ROOT}/scripts/qa-generate-scenarios.sh"
    --project-dir "${PROJECT_DIR}"
    --tasks-file "${TASKS_FILE}"
  )
  if [[ -n "${TRD_FILE}" ]]; then
    qa_scenario_cmd+=(--trd-file "${TRD_FILE}")
  fi
  if [[ -n "${PRD_FILE}" ]]; then
    qa_scenario_cmd+=(--prd-file "${PRD_FILE}")
  fi
  QA_SCENARIO_PATH="$("${qa_scenario_cmd[@]}")"
else
  QA_SCENARIO_PATH="${PROJECT_DIR}/.blackboard/artifacts/qa/scenarios-unbound.json"
  mkdir -p "$(dirname "${QA_SCENARIO_PATH}")"
  NOW_SCENARIO_UTC="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  cat > "${QA_SCENARIO_PATH}" <<EOF_JSON
{
  "id": "",
  "slug": "",
  "generated_at": "${NOW_SCENARIO_UTC}",
  "tasks_path": "",
  "trd_path": "",
  "prd_path": "",
  "scenario_types": ["integration", "e2e"],
  "task_ids": [],
  "notes": "Generated without tasks/tasks-*.md; using stack-registry-only QA mode"
}
EOF_JSON
fi

run_test_shell() {
  local label="$1"
  local command="$2"
  local workdir="$3"

  echo "${label} :: (cd ${workdir} && ${command})" >> "${QA_COMMANDS_FILE}"
  if (cd "${workdir}" && bash -lc "${command}"); then
    return 0
  fi
  echo "${label}" >> "${QA_FAILURES_FILE}"
  return 1
}

run_stack_tests_for_project() {
  local stack="$1"
  local target_dir="$2"

  case "${stack}" in
    python)
      if command -v pytest >/dev/null 2>&1; then
        integration_targets="$(find "${target_dir}" -type f \( -name 'test_*integration*.py' -o -name '*integration*_test.py' \) -not -path '*/.git/*' | sort | tr '\n' ' ')"
        e2e_targets="$(find "${target_dir}" -type f \( -name 'test_*e2e*.py' -o -name '*e2e*_test.py' \) -not -path '*/.git/*' | sort | tr '\n' ' ')"

        if [[ -n "${integration_targets}" ]]; then
          run_test_shell "${stack}:${target_dir}:integration-tests" "pytest -q ${integration_targets}" "${PROJECT_DIR}" || true
        else
          echo "${stack}:${target_dir}:integration-tests :: skipped(no matching files)" >> "${QA_COMMANDS_FILE}"
        fi

        if [[ -n "${e2e_targets}" ]]; then
          run_test_shell "${stack}:${target_dir}:e2e-tests" "pytest -q ${e2e_targets}" "${PROJECT_DIR}" || true
        else
          echo "${stack}:${target_dir}:e2e-tests :: skipped(no matching files)" >> "${QA_COMMANDS_FILE}"
        fi
      else
        echo "${stack}:${target_dir}:integration-tests :: skipped(pytest missing)" >> "${QA_COMMANDS_FILE}"
        echo "${stack}:${target_dir}:e2e-tests :: skipped(pytest missing)" >> "${QA_COMMANDS_FILE}"
      fi
      ;;
    node)
      if [[ -f "${target_dir}/package.json" ]]; then
        if (cd "${target_dir}" && node -e "const fs=require('node:fs');const pkg=JSON.parse(fs.readFileSync('package.json','utf8'));process.exit(pkg.scripts && pkg.scripts['test:integration'] ? 0 : 1);"); then
          run_test_shell "${stack}:${target_dir}:integration-tests" "npm run --silent test:integration" "${target_dir}" || true
        else
          echo "${stack}:${target_dir}:integration-tests :: skipped(script missing)" >> "${QA_COMMANDS_FILE}"
        fi

        if (cd "${target_dir}" && node -e "const fs=require('node:fs');const pkg=JSON.parse(fs.readFileSync('package.json','utf8'));process.exit(pkg.scripts && pkg.scripts['test:e2e'] ? 0 : 1);"); then
          run_test_shell "${stack}:${target_dir}:e2e-tests" "npm run --silent test:e2e" "${target_dir}" || true
        else
          echo "${stack}:${target_dir}:e2e-tests :: skipped(script missing)" >> "${QA_COMMANDS_FILE}"
        fi
      else
        echo "${stack}:${target_dir}:integration-tests :: skipped(package.json missing)" >> "${QA_COMMANDS_FILE}"
        echo "${stack}:${target_dir}:e2e-tests :: skipped(package.json missing)" >> "${QA_COMMANDS_FILE}"
      fi
      ;;
    go)
      integration_packages="$(find "${target_dir}" -type f -name '*integration*_test.go' -not -path '*/.git/*' | awk '{
        dir=$0
        sub(/\/[^\/]+$/, "", dir)
        if (dir == "") dir="."
        print dir
      }' | sort -u | tr '\n' ' ')"
      e2e_packages="$(find "${target_dir}" -type f -name '*e2e*_test.go' -not -path '*/.git/*' | awk '{
        dir=$0
        sub(/\/[^\/]+$/, "", dir)
        if (dir == "") dir="."
        print dir
      }' | sort -u | tr '\n' ' ')"

      if [[ -n "${integration_packages}" ]]; then
        run_test_shell "${stack}:${target_dir}:integration-tests" "go test ${integration_packages}" "${target_dir}" || true
      else
        echo "${stack}:${target_dir}:integration-tests :: skipped(no matching files)" >> "${QA_COMMANDS_FILE}"
      fi

      if [[ -n "${e2e_packages}" ]]; then
        run_test_shell "${stack}:${target_dir}:e2e-tests" "go test ${e2e_packages}" "${target_dir}" || true
      else
        echo "${stack}:${target_dir}:e2e-tests :: skipped(no matching files)" >> "${QA_COMMANDS_FILE}"
      fi
      ;;
    *)
      echo "${stack}:${target_dir}:integration-tests :: skipped(no built-in runner for stack)" >> "${QA_COMMANDS_FILE}"
      echo "${stack}:${target_dir}:e2e-tests :: skipped(no built-in runner for stack)" >> "${QA_COMMANDS_FILE}"
      ;;
  esac
}

while IFS= read -r stack_name; do
  [[ -z "${stack_name}" ]] && continue

  project_index=0
  while IFS='|' read -r project_path _owned; do
    [[ -z "${project_path}" ]] && continue
    project_index=$((project_index + 1))

    if [[ "${project_path}" == /* ]]; then
      target_dir="${project_path}"
    else
      target_dir="${PROJECT_DIR}/${project_path}"
    fi

    if [[ ! -d "${target_dir}" ]]; then
      echo "${stack_name}:${project_path}:project-not-found" >> "${QA_FAILURES_FILE}"
      continue
    fi

    run_stack_tests_for_project "${stack_name}" "${target_dir}"

    static_report_file="${REPORT_DIR}/static-review-${stack_name}-${project_index}.json"
    if bash "${REPO_ROOT}/scripts/static-review.sh" --project-dir "${target_dir}" --stack "${stack_name}" --out-file "${static_report_file}" >/dev/null; then
      echo "${stack_name}|${project_path}|${static_report_file}|true" >> "${STATIC_REPORT_INDEX_FILE}"
    else
      echo "${stack_name}|${project_path}|${static_report_file}|false" >> "${STATIC_REPORT_INDEX_FILE}"
      echo "${stack_name}:${project_path}:static-review" >> "${QA_FAILURES_FILE}"
    fi
  done < <(stack_registry_project_rows "${REGISTRY_ABS}" "${stack_name}")
done < "${STACKS_FILE}"

FAIL_COUNT="$(grep -c . "${QA_FAILURES_FILE}" || true)"
NOW_UTC="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
QA_REPORT="${REPORT_DIR}/qa-report.json"
STATIC_REPORT="${REPORT_DIR}/static-review.json"

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

STACKS_JSON="$(perl -MJSON::PP -e '
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
' "${STACKS_FILE}")"

STATIC_REPORTS_JSON="$(perl -MJSON::PP -e '
  use strict;
  use warnings;
  my ($path) = @ARGV;
  my @rows;
  if (open my $fh, "<", $path) {
    while (my $line = <$fh>) {
      chomp $line;
      next if $line eq "";
      my ($stack, $project, $report, $passed) = split /\|/, $line, 4;
      push @rows, {
        stack => $stack,
        project_path => $project,
        report_path => $report,
        passed => ($passed && $passed eq "true") ? JSON::PP::true : JSON::PP::false,
      };
    }
    close $fh;
  }
  print encode_json(\@rows);
' "${STATIC_REPORT_INDEX_FILE}")"

cat > "${STATIC_REPORT}" <<EOF_JSON
{
  "generated_at": "${NOW_UTC}",
  "stacks": ${STACKS_JSON},
  "reports": ${STATIC_REPORTS_JSON}
}
EOF_JSON

cat > "${QA_REPORT}" <<EOF_JSON
{
  "generated_at": "${NOW_UTC}",
  "stacks": ${STACKS_JSON},
  "scenario_path": "${QA_SCENARIO_PATH#${PROJECT_DIR}/}",
  "commands": ${COMMANDS_JSON},
  "failures": ${FAILS_JSON},
  "static_review_report": "${STATIC_REPORT#${PROJECT_DIR}/}",
  "passed": $([[ "${FAIL_COUNT}" -eq 0 ]] && echo true || echo false)
}
EOF_JSON

if [[ "${FAIL_COUNT}" -gt 0 ]]; then
  FAILURE_BUNDLE="${PROJECT_DIR}/.blackboard/feedback/qa/qa-failure-$(date +%s).json"
  cat > "${FAILURE_BUNDLE}" <<EOF_JSON
{
  "generated_at": "${NOW_UTC}",
  "stacks": ${STACKS_JSON},
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
