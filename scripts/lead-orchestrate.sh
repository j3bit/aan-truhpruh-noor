#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

PROJECT_DIR="${PWD}"
TASKS_FILE=""
STACK=""
OUT_DIR=""
APPROVE=0
PLAN_ONLY=0
REPLAN_ON_FAILURE=1
MAX_FIX_RETRIES=3

TASK_IDS=()
TASK_STATUSS=()
TASK_DEPSS=()
TASK_PARALLELS=()
DONE_IDS=()

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/lead-orchestrate.sh \
    --project-dir <path> \
    [--tasks-file <path>] \
    [--stack <python|node|go>] \
    [--out-dir <path>] \
    [--approve] \
    [--plan-only]

Description:
  Lead-driven orchestration runner that:
  1) builds a deterministic task dependency plan (DAG proposal),
  2) optionally executes one-task-per-sub-agent gate loops,
  3) writes plan/status artifacts for end-to-end verification.

Output artifacts:
  <out-dir>/plan.jsonl
  <out-dir>/status.jsonl
  <out-dir>/summary.json

Notes:
  - Execution requires explicit coordinator approval via --approve.
  - Replanning is allowed only after failure/blocker events.
USAGE
}

error() {
  echo "[lead-orchestrate] ERROR: $*" >&2
}

normalize_value() {
  local value="$1"
  value="${value//\`/}"
  value="$(printf '%s' "${value}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  printf '%s' "${value}"
}

to_lower() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

find_task_index() {
  local target_id="$1"
  local i
  for ((i=0; i<${#TASK_IDS[@]}; i++)); do
    if [[ "${TASK_IDS[$i]}" == "${target_id}" ]]; then
      echo "${i}"
      return 0
    fi
  done
  return 1
}

is_done() {
  local target_id="$1"
  local i
  for ((i=0; i<${#DONE_IDS[@]}; i++)); do
    if [[ "${DONE_IDS[$i]}" == "${target_id}" ]]; then
      return 0
    fi
  done
  return 1
}

mark_done() {
  local target_id="$1"
  if ! is_done "${target_id}"; then
    DONE_IDS+=("${target_id}")
  fi
}

deps_to_lines_cmd() {
  local deps_raw
  deps_raw="$(normalize_value "$1")"
  if [[ -z "${deps_raw}" || "$(to_lower "${deps_raw}")" == "none" ]]; then
    return 0
  fi
  printf '%s' "${deps_raw}" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed '/^$/d'
}

deps_to_json() {
  local deps_raw="$1"
  local output="["
  local first=1
  local dep

  while IFS= read -r dep; do
    [[ -z "${dep}" ]] && continue
    if [[ "${first}" -eq 0 ]]; then
      output+=","
    fi
    output+="\"${dep}\""
    first=0
  done < <(deps_to_lines_cmd "${deps_raw}")

  output+="]"
  printf '%s' "${output}"
}

parallel_to_bool() {
  local value
  value="$(to_lower "$1")"
  if [[ "${value}" == "yes" || "${value}" == "true" ]]; then
    printf 'true'
  else
    printf 'false'
  fi
}

risk_level_for_task() {
  local deps_raw="$1"
  local parallel_raw="$2"
  local dep_count=0
  local _dep

  while IFS= read -r _dep; do
    [[ -z "${_dep}" ]] && continue
    dep_count=$((dep_count + 1))
  done < <(deps_to_lines_cmd "${deps_raw}")

  if [[ "${dep_count}" -ge 2 ]]; then
    printf 'high'
    return 0
  fi
  if [[ "$(parallel_to_bool "${parallel_raw}")" == "true" ]]; then
    printf 'low'
  else
    printf 'medium'
  fi
}

deps_are_done() {
  local deps_raw="$1"
  local dep
  while IFS= read -r dep; do
    [[ -z "${dep}" ]] && continue
    if ! is_done "${dep}"; then
      return 1
    fi
  done < <(deps_to_lines_cmd "${deps_raw}")
  return 0
}

write_status_record() {
  local status_file="$1"
  local task_id="$2"
  local agent_id="$3"
  local status="$4"
  local attempt="$5"
  local gate_passed="$6"
  local review_passed="$7"
  local blocked_reason="$8"
  local escaped_reason="${blocked_reason//\"/\\\"}"

  printf '{"task_id":"%s","agent_id":"%s","status":"%s","attempt":%s,"gate_passed":%s,"pr_review_passed":%s,"blocked_reason":"%s"}\n' \
    "${task_id}" "${agent_id}" "${status}" "${attempt}" "${gate_passed}" "${review_passed}" "${escaped_reason}" >> "${status_file}"
}

load_tasks() {
  local row task_id status deps parallel idx

  TASK_IDS=()
  TASK_STATUSS=()
  TASK_DEPSS=()
  TASK_PARALLELS=()
  DONE_IDS=()

  while IFS= read -r row; do
    [[ -z "${row}" ]] && continue
    IFS='|' read -r task_id status deps parallel <<<"${row}"
    task_id="$(normalize_value "${task_id}")"
    status="$(normalize_value "${status}")"
    deps="$(normalize_value "${deps}")"
    parallel="$(normalize_value "${parallel}")"

    if find_task_index "${task_id}" >/dev/null 2>&1; then
      error "Duplicate task id in tasks file: ${task_id}"
      exit 2
    fi

    TASK_IDS+=("${task_id}")
    TASK_STATUSS+=("${status}")
    TASK_DEPSS+=("${deps}")
    TASK_PARALLELS+=("${parallel}")
  done < <(awk '
    function trim(v) {
      gsub(/`/, "", v)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
      return v
    }
    function flush_task() {
      if (task_id != "") {
        print task_id "|" status "|" deps "|" parallel
      }
    }
    /^### T-[0-9]+:/ {
      flush_task()
      task_id = $2
      sub(/:/, "", task_id)
      status = "todo"
      deps = "none"
      parallel = "no"
      next
    }
    task_id != "" && /^- Status:/ {
      line = $0
      sub(/^- Status:[[:space:]]*/, "", line)
      status = trim(line)
      next
    }
    task_id != "" && /^- Dependencies:/ {
      line = $0
      sub(/^- Dependencies:[[:space:]]*/, "", line)
      deps = trim(line)
      next
    }
    task_id != "" && /^- Parallel-safe:/ {
      line = $0
      sub(/^- Parallel-safe:[[:space:]]*/, "", line)
      parallel = trim(line)
      next
    }
    END {
      flush_task()
    }
  ' "${TASKS_FILE}")

  if [[ "${#TASK_IDS[@]}" -eq 0 ]]; then
    error "No task blocks found in ${TASKS_FILE}"
    exit 2
  fi

  for ((idx=0; idx<${#TASK_IDS[@]}; idx++)); do
    if [[ "$(to_lower "${TASK_STATUSS[$idx]}")" == "done" ]]; then
      mark_done "${TASK_IDS[$idx]}"
    fi
  done
}

write_plan() {
  local plan_file="$1"
  local idx task_id status deps parallel deps_json ready parallel_bool risk

  : > "${plan_file}"

  for ((idx=0; idx<${#TASK_IDS[@]}; idx++)); do
    task_id="${TASK_IDS[$idx]}"
    status="${TASK_STATUSS[$idx]}"
    deps="${TASK_DEPSS[$idx]}"
    parallel="${TASK_PARALLELS[$idx]}"

    deps_json="$(deps_to_json "${deps}")"
    parallel_bool="$(parallel_to_bool "${parallel}")"
    risk="$(risk_level_for_task "${deps}" "${parallel}")"

    if [[ "$(to_lower "${status}")" == "done" ]]; then
      ready="false"
    elif deps_are_done "${deps}"; then
      ready="true"
    else
      ready="false"
    fi

    printf '{"task_id":"%s","dependencies":%s,"parallel_safe":%s,"gate_stack":"%s","risk_level":"%s","ready":%s}\n' \
      "${task_id}" "${deps_json}" "${parallel_bool}" "${STACK}" "${risk}" "${ready}" >> "${plan_file}"
  done
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-dir)
      [[ $# -ge 2 ]] || { error "--project-dir requires a value"; usage; exit 2; }
      PROJECT_DIR="$2"
      shift 2
      ;;
    --tasks-file)
      [[ $# -ge 2 ]] || { error "--tasks-file requires a value"; usage; exit 2; }
      TASKS_FILE="$2"
      shift 2
      ;;
    --stack)
      [[ $# -ge 2 ]] || { error "--stack requires a value"; usage; exit 2; }
      STACK="$2"
      shift 2
      ;;
    --out-dir)
      [[ $# -ge 2 ]] || { error "--out-dir requires a value"; usage; exit 2; }
      OUT_DIR="$2"
      shift 2
      ;;
    --approve)
      APPROVE=1
      shift
      ;;
    --plan-only)
      PLAN_ONLY=1
      shift
      ;;
    --replan-on-failure)
      [[ $# -ge 2 ]] || { error "--replan-on-failure requires true|false"; usage; exit 2; }
      case "$2" in
        true) REPLAN_ON_FAILURE=1 ;;
        false) REPLAN_ON_FAILURE=0 ;;
        *) error "--replan-on-failure must be true or false"; exit 2 ;;
      esac
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

if [[ ! -d "${PROJECT_DIR}" ]]; then
  error "Project directory does not exist: ${PROJECT_DIR}"
  exit 2
fi
PROJECT_DIR="$(cd -- "${PROJECT_DIR}" && pwd -P)"

if [[ -z "${TASKS_FILE}" ]]; then
  tasks_found=0
  selected_tasks_file=""
  while IFS= read -r found_file; do
    [[ -z "${found_file}" ]] && continue
    tasks_found=$((tasks_found + 1))
    selected_tasks_file="${found_file}"
  done < <(find "${PROJECT_DIR}/tasks" -maxdepth 1 -type f -name 'tasks-*.md' | sort)

  if [[ "${tasks_found}" -eq 0 ]]; then
    error "No tasks/tasks-*.md found under ${PROJECT_DIR}/tasks"
    exit 2
  fi
  if [[ "${tasks_found}" -gt 1 ]]; then
    error "Multiple tasks files found. Specify one with --tasks-file"
    exit 2
  fi
  TASKS_FILE="${selected_tasks_file}"
fi

if [[ ! -f "${TASKS_FILE}" ]]; then
  error "Tasks file not found: ${TASKS_FILE}"
  exit 2
fi
TASKS_FILE="$(cd -- "$(dirname -- "${TASKS_FILE}")" && pwd -P)/$(basename -- "${TASKS_FILE}")"

if [[ -z "${STACK}" ]]; then
  STACK="$(awk '
    /^- Gate Stack:/ {
      line=$0
      sub(/^- Gate Stack:[[:space:]]*/, "", line)
      gsub(/`/, "", line)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
      print line
      exit
    }
  ' "${TASKS_FILE}")"
fi

case "${STACK}" in
  python|node|go)
    ;;
  *)
    error "Unsupported or missing stack '${STACK}'. Use --stack <python|node|go> or add '- Gate Stack:' metadata."
    exit 2
    ;;
esac

if [[ -z "${OUT_DIR}" ]]; then
  OUT_DIR="${PROJECT_DIR}/.orchestration"
fi
mkdir -p "${OUT_DIR}"

PLAN_FILE="${OUT_DIR}/plan.jsonl"
STATUS_FILE="${OUT_DIR}/status.jsonl"
SUMMARY_FILE="${OUT_DIR}/summary.json"

load_tasks
write_plan "${PLAN_FILE}"

if [[ "${PLAN_ONLY}" -eq 1 ]]; then
  : > "${STATUS_FILE}"
  cat > "${SUMMARY_FILE}" <<EOF_SUMMARY
{"approved":false,"plan_only":true,"stack":"${STACK}","loop_complete":false,"replan_triggered":false}
EOF_SUMMARY
  echo "[lead-orchestrate] plan written: ${PLAN_FILE}"
  exit 0
fi

if [[ "${APPROVE}" -ne 1 ]]; then
  error "Coordinator approval required. Re-run with --approve or use --plan-only."
  exit 2
fi

: > "${STATUS_FILE}"

replan_triggered=false
agent_seq=0
loop_complete=false
failed_task=""

while true; do
  pending_ids=()
  ready_ids=()

  for ((idx=0; idx<${#TASK_IDS[@]}; idx++)); do
    task_id="${TASK_IDS[$idx]}"
    if ! is_done "${task_id}"; then
      pending_ids+=("${task_id}")
    fi
  done

  if [[ "${#pending_ids[@]}" -eq 0 ]]; then
    loop_complete=true
    break
  fi

  for task_id in "${pending_ids[@]}"; do
    idx="$(find_task_index "${task_id}")"
    deps="${TASK_DEPSS[$idx]}"
    if deps_are_done "${deps}"; then
      ready_ids+=("${task_id}")
    fi
  done

  if [[ "${#ready_ids[@]}" -eq 0 ]]; then
    for task_id in "${pending_ids[@]}"; do
      agent_seq=$((agent_seq + 1))
      write_status_record "${STATUS_FILE}" "${task_id}" "sub-${agent_seq}" "blocked" 1 false false "dependency_not_ready"
    done
    failed_task="${pending_ids[0]}"
    if [[ "${REPLAN_ON_FAILURE}" -eq 1 ]]; then
      replan_triggered=true
      write_plan "${PLAN_FILE}"
    fi
    break
  fi

  local_failure=0

  for task_id in "${ready_ids[@]}"; do
    agent_seq=$((agent_seq + 1))
    agent_id="sub-${agent_seq}"

    gate_passed=false
    attempt=0

    while [[ "${attempt}" -lt "${MAX_FIX_RETRIES}" ]]; do
      attempt=$((attempt + 1))
      if bash "${REPO_ROOT}/scripts/check.sh" --stack "${STACK}" --project-dir "${PROJECT_DIR}" >/dev/null 2>&1; then
        gate_passed=true
        break
      fi
    done

    if [[ "${gate_passed}" == "true" ]]; then
      write_status_record "${STATUS_FILE}" "${task_id}" "${agent_id}" "done" "${attempt}" true true ""
      mark_done "${task_id}"
      idx="$(find_task_index "${task_id}")"
      TASK_STATUSS[$idx]="done"
    else
      write_status_record "${STATUS_FILE}" "${task_id}" "${agent_id}" "blocked" "${attempt}" false false "gate_failed_after_${MAX_FIX_RETRIES}_attempts"
      failed_task="${task_id}"
      local_failure=1
      break
    fi
  done

  if [[ "${local_failure}" -eq 1 ]]; then
    if [[ "${REPLAN_ON_FAILURE}" -eq 1 ]]; then
      replan_triggered=true
      write_plan "${PLAN_FILE}"
    fi
    break
  fi
done

cat > "${SUMMARY_FILE}" <<EOF_SUMMARY
{"approved":true,"plan_only":false,"stack":"${STACK}","loop_complete":${loop_complete},"replan_triggered":${replan_triggered},"failed_task":"${failed_task}"}
EOF_SUMMARY

echo "[lead-orchestrate] plan: ${PLAN_FILE}"
echo "[lead-orchestrate] status: ${STATUS_FILE}"
echo "[lead-orchestrate] summary: ${SUMMARY_FILE}"

if [[ "${loop_complete}" == "true" ]]; then
  echo "LOOP_COMPLETE"
  exit 0
fi

exit 1
