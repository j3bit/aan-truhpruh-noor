#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="${PWD}"
CHANGED_ONLY=0

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/validate-contracts.sh --project-dir <path> [--changed-only]

Exit Codes:
  0: contract checks passed (or skipped because no contract layer exists)
  1: contract rule violation
  2: configuration or input error
USAGE
}

error() {
  echo "[contracts] ERROR: $*" >&2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-dir)
      [[ $# -ge 2 ]] || { error "--project-dir requires a value"; usage; exit 2; }
      PROJECT_DIR="$2"
      shift 2
      ;;
    --changed-only)
      CHANGED_ONLY=1
      shift
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

if [[ ! -d "${PROJECT_DIR}" ]]; then
  error "Project directory does not exist: ${PROJECT_DIR}"
  exit 2
fi

PROJECT_DIR="$(cd "${PROJECT_DIR}" && pwd)"
TASKS_DIR="${PROJECT_DIR}/tasks"
PROCESS_RULES_FILE="${TASKS_DIR}/process-rules.md"
REQUIRED_SKILL_FILES=(
  ".agents/skills/create-prd/SKILL.md"
  ".agents/skills/generate-tasks/SKILL.md"
  ".agents/skills/process-task/SKILL.md"
  ".agents/skills/fix-failing-checks/SKILL.md"
  ".agents/skills/pr-review/SKILL.md"
)
REQUIRED_TEMPLATE_FILES=(
  ".codex/config.toml"
  "docs/runbook/03-multi-agent.md"
)

if [[ ! -d "${TASKS_DIR}" ]]; then
  echo "[contracts] INFO: no tasks/ directory in ${PROJECT_DIR}; skipping contract checks"
  exit 0
fi

if [[ ! -f "${PROCESS_RULES_FILE}" ]]; then
  error "Missing required process rules file: ${PROCESS_RULES_FILE}"
  exit 1
fi

FAILED=0

for rel_path in "${REQUIRED_SKILL_FILES[@]}"; do
  if [[ ! -f "${PROJECT_DIR}/${rel_path}" ]]; then
    echo "[contracts] FAIL: missing required skill file: ${rel_path}" >&2
    FAILED=1
  fi
done

for rel_path in "${REQUIRED_TEMPLATE_FILES[@]}"; do
  if [[ ! -f "${PROJECT_DIR}/${rel_path}" ]]; then
    echo "[contracts] FAIL: missing required template artifact: ${rel_path}" >&2
    FAILED=1
  fi
done

CHANGED_FILES_FILE="$(mktemp)"
cleanup() {
  rm -f "${CHANGED_FILES_FILE}"
}
trap cleanup EXIT

if [[ "${CHANGED_ONLY}" -eq 1 ]] && command -v git >/dev/null 2>&1; then
  if git -C "${PROJECT_DIR}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    {
      {
        git -C "${PROJECT_DIR}" diff --name-only --diff-filter=ACMRTUXB
        git -C "${PROJECT_DIR}" diff --cached --name-only --diff-filter=ACMRTUXB
        git -C "${PROJECT_DIR}" ls-files --others --exclude-standard
      } | sed '/^$/d' | sort -u
    } > "${CHANGED_FILES_FILE}"
  else
    echo "[contracts] INFO: --changed-only requested but project is not in a git worktree; running full checks"
  fi
fi

should_check_file() {
  local rel_path="$1"
  if [[ "${CHANGED_ONLY}" -eq 0 ]]; then
    return 0
  fi
  if [[ ! -s "${CHANGED_FILES_FILE}" ]]; then
    return 0
  fi
  grep -Fxq "${rel_path}" "${CHANGED_FILES_FILE}"
}

if ! grep -qi "Trace logging required" "${PROCESS_RULES_FILE}"; then
  echo "[contracts] FAIL: tasks/process-rules.md must include 'Trace logging required'" >&2
  FAILED=1
fi

check_filename_contract() {
  local rel_path="$1"
  local regex="$2"
  if [[ ! "${rel_path}" =~ ${regex} ]]; then
    echo "[contracts] FAIL: file name does not match required pattern: ${rel_path}" >&2
    FAILED=1
  fi
}

while IFS= read -r -d '' abs_path; do
  rel_path="${abs_path#${PROJECT_DIR}/}"
  if should_check_file "${rel_path}"; then
    check_filename_contract "${rel_path}" '^tasks/prd-[0-9]{4}-[a-z0-9][a-z0-9-]*\.md$'
  fi
done < <(find "${TASKS_DIR}" -maxdepth 1 -type f -name 'prd-*.md' -print0)

while IFS= read -r -d '' abs_path; do
  rel_path="${abs_path#${PROJECT_DIR}/}"
  if should_check_file "${rel_path}"; then
    check_filename_contract "${rel_path}" '^tasks/tasks-[0-9]{4}-[a-z0-9][a-z0-9-]*\.md$'
  fi
done < <(find "${TASKS_DIR}" -maxdepth 1 -type f -name 'tasks-*.md' -print0)

validate_task_file_block_contract() {
  local file="$1"
  local rel_path="$2"

  if ! awk '
    function flush_task() {
      if (!in_task) {
        return
      }

      missing = ""
      if (!has_dependencies) {
        missing = missing " Dependencies"
      }
      if (!has_acceptance) {
        missing = missing " Acceptance Criteria"
      }
      if (!has_test_plan) {
        missing = missing " Test Plan"
      }
      if (!has_done_definition) {
        missing = missing " Done Definition"
      }

      if (missing != "") {
        printf("[contracts] FAIL: %s %s missing:%s\n", file_path, current_task, missing) > "/dev/stderr"
        failed = 1
      }
    }

    BEGIN {
      failed = 0
      in_task = 0
      current_task = ""
      has_dependencies = 0
      has_acceptance = 0
      has_test_plan = 0
      has_done_definition = 0
    }

    /^### T-[0-9]+:/ {
      flush_task()
      in_task = 1
      current_task = $0
      has_dependencies = 0
      has_acceptance = 0
      has_test_plan = 0
      has_done_definition = 0
      next
    }

    in_task {
      if ($0 ~ /^- Dependencies:/) {
        has_dependencies = 1
      } else if ($0 ~ /^- Acceptance Criteria:/) {
        has_acceptance = 1
      } else if ($0 ~ /^- Test Plan:/) {
        has_test_plan = 1
      } else if ($0 ~ /^- Done Definition:/) {
        has_done_definition = 1
      }
    }

    END {
      flush_task()
      exit failed
    }
  ' "file_path=${rel_path}" "${file}"; then
    FAILED=1
  fi
}

validate_prd_file_required_sections() {
  local file="$1"
  local rel_path="$2"

  if ! awk '
    BEGIN {
      has_problem = 0
      has_goals = 0
      has_non_goals = 0
      has_success_metrics = 0
      has_constraints = 0
      has_test_strategy = 0
      has_rollout = 0
      failed = 0
    }

    /^##[[:space:]]/ {
      heading = tolower($0)

      if (index(heading, "problem") > 0) {
        has_problem = 1
      }
      if (index(heading, "non-goals") > 0 || index(heading, "non goals") > 0) {
        has_non_goals = 1
      }
      if (index(heading, "goal") > 0 && index(heading, "non-goals") == 0 && index(heading, "non goals") == 0) {
        has_goals = 1
      }
      if (index(heading, "success metrics") > 0) {
        has_success_metrics = 1
      }
      if (index(heading, "constraints") > 0) {
        has_constraints = 1
      }
      if (index(heading, "test strategy") > 0) {
        has_test_strategy = 1
      }
      if (index(heading, "rollout") > 0) {
        has_rollout = 1
      }
    }

    END {
      missing = ""

      if (!has_problem) {
        missing = missing " Problem"
      }
      if (!has_goals) {
        missing = missing " Goals"
      }
      if (!has_non_goals) {
        missing = missing " Non-goals"
      }
      if (!has_success_metrics) {
        missing = missing " Success Metrics"
      }
      if (!has_constraints) {
        missing = missing " Constraints"
      }
      if (!has_test_strategy) {
        missing = missing " Test Strategy"
      }
      if (!has_rollout) {
        missing = missing " Rollout"
      }

      if (missing != "") {
        printf("[contracts] FAIL: %s missing PRD sections:%s\n", file_path, missing) > "/dev/stderr"
        failed = 1
      }

      exit failed
    }
  ' "file_path=${rel_path}" "${file}"; then
    FAILED=1
  fi
}

while IFS= read -r -d '' abs_path; do
  rel_path="${abs_path#${PROJECT_DIR}/}"
  if should_check_file "${rel_path}"; then
    validate_prd_file_required_sections "${abs_path}" "${rel_path}"
  fi
done < <(find "${TASKS_DIR}" -maxdepth 1 -type f -name 'prd-*.md' -print0)

while IFS= read -r -d '' abs_path; do
  rel_path="${abs_path#${PROJECT_DIR}/}"
  if should_check_file "${rel_path}"; then
    validate_task_file_block_contract "${abs_path}" "${rel_path}"
  fi
done < <(find "${TASKS_DIR}" -maxdepth 1 -type f -name 'tasks-*.md' -print0)

if [[ "${FAILED}" -eq 0 ]]; then
  echo "[contracts] PASS"
  exit 0
fi

echo "[contracts] FAIL"
exit 1
