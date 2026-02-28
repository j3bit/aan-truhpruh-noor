#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

if [[ ! -f "${REPO_ROOT}/scripts/lib/stage-router.sh" ]]; then
  echo "[lead-orchestrate] ERROR: missing stage-router library" >&2
  exit 2
fi
if [[ ! -f "${REPO_ROOT}/scripts/lib/blackboard.sh" ]]; then
  echo "[lead-orchestrate] ERROR: missing blackboard library" >&2
  exit 2
fi

# shellcheck source=/dev/null
source "${REPO_ROOT}/scripts/lib/stage-router.sh"
# shellcheck source=/dev/null
source "${REPO_ROOT}/scripts/lib/blackboard.sh"

PROJECT_DIR="${PWD}"
TASKS_FILE=""
DAG_FILE=""
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

DAG_TASK_IDS=()
DAG_DEPSS=()
DAG_PARALLELS=()
DAG_STAGES=()
UNIQUE_DAG_TASK_IDS=()

WAVE_TASKS=()

DAG_GATE_STACK=""
DAG_TASKS_PATH=""
DAG_TRD_PATH=""
DAG_PRD_PATH=""

PROFILE_SELECTED="default"
PROFILE_FALLBACK=true

PLAN_FILE=""
STATUS_FILE=""
SUMMARY_FILE=""

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/lead-orchestrate.sh \
    --project-dir <path> \
    [--tasks-file <path>] \
    [--dag-file <path>] \
    [--stack <python|node|go>] \
    [--out-dir <path>] \
    [--approve] \
    [--plan-only]

Description:
  Lead-driven orchestration runner that:
  1) validates tasks + DAG contracts,
  2) builds deterministic topological execution waves,
  3) executes wave-by-wave with blackboard artifacts and stage-safe events,
  4) emits orchestration contracts.

Output artifacts:
  <out-dir>/plan.jsonl
  <out-dir>/status.jsonl
  <out-dir>/summary.json
USAGE
}

error() {
  echo "[lead-orchestrate] ERROR: $*" >&2
}

allowed_stages_csv() {
  stage_router_stages | paste -sd ',' -
}

ensure_valid_stage() {
  local stage="$1"
  local task_id="${2:-unknown}"

  if ! stage_router_index_of "${stage}" >/dev/null 2>&1; then
    error "Invalid DAG stage '${stage}' for task ${task_id}. Allowed stages: $(allowed_stages_csv)"
    exit 2
  fi
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

deps_to_lines_cmd() {
  local deps_raw
  deps_raw="$(normalize_value "$1")"
  if [[ -z "${deps_raw}" || "$(to_lower "${deps_raw}")" == "none" ]]; then
    return 0
  fi
  printf '%s\n' "${deps_raw}" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed '/^$/d'
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

array_contains() {
  local needle="$1"
  shift || true
  local item
  for item in "$@"; do
    if [[ "${item}" == "${needle}" ]]; then
      return 0
    fi
  done
  return 1
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

find_dag_index() {
  local target_id="$1"
  local i
  for ((i=0; i<${#DAG_TASK_IDS[@]}; i++)); do
    if [[ "${DAG_TASK_IDS[$i]}" == "${target_id}" ]]; then
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

dag_deps_are_done() {
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

load_dag() {
  local node_task_id node_deps node_parallel node_stage

  DAG_TASK_IDS=()
  DAG_DEPSS=()
  DAG_PARALLELS=()
  DAG_STAGES=()

  while IFS='|' read -r kind a b c d; do
    [[ -z "${kind}" ]] && continue
    if [[ "${kind}" == "META" ]]; then
      DAG_GATE_STACK="$(normalize_value "${a}")"
      DAG_TASKS_PATH="$(normalize_value "${b}")"
      DAG_TRD_PATH="$(normalize_value "${c}")"
      DAG_PRD_PATH="$(normalize_value "${d}")"
      continue
    fi
    if [[ "${kind}" == "NODE" ]]; then
      node_task_id="$(normalize_value "${a}")"
      node_deps="$(normalize_value "${b}")"
      node_parallel="$(normalize_value "${c}")"
      node_stage="$(normalize_value "${d}")"

      ensure_valid_stage "${node_stage}" "${node_task_id}"

      DAG_TASK_IDS+=("${node_task_id}")
      DAG_DEPSS+=("${node_deps}")
      DAG_PARALLELS+=("${node_parallel}")
      DAG_STAGES+=("${node_stage}")
    fi
  done < <(perl -MJSON::PP -e '
    use strict;
    use warnings;
    my ($path) = @ARGV;
    local $/;
    open my $fh, "<", $path or die "open_failed\n";
    my $json = <$fh>;
    close $fh;
    my $obj = decode_json($json);

    die "missing_metadata\n" unless ref($obj->{metadata}) eq "HASH";
    for my $k (qw(id slug prd trd tasks gate_stack)) {
      die "missing_metadata_key_$k\n" unless defined $obj->{metadata}{$k};
    }
    die "missing_nodes\n" unless ref($obj->{nodes}) eq "ARRAY";

    print join("|", "META", $obj->{metadata}{gate_stack}, $obj->{metadata}{tasks}, $obj->{metadata}{trd}, $obj->{metadata}{prd}) . "\n";

    for my $node (@{$obj->{nodes}}) {
      die "invalid_node\n" unless ref($node) eq "HASH";
      die "missing_task_id\n" unless defined $node->{task_id};
      die "missing_depends_on\n" unless ref($node->{depends_on}) eq "ARRAY";
      die "missing_parallel_safe\n" unless exists $node->{parallel_safe};
      my @deps = sort @{$node->{depends_on}};
      my $parallel = $node->{parallel_safe} ? "true" : "false";
      my $stage = defined $node->{stage} ? $node->{stage} : "IMPLEMENTATION";
      print join("|", "NODE", $node->{task_id}, join(",", @deps), $parallel, $stage) . "\n";
    }
  ' "${DAG_FILE}" 2>/dev/null)

  if [[ "${#DAG_TASK_IDS[@]}" -eq 0 ]]; then
    error "Invalid or empty DAG: ${DAG_FILE}"
    exit 2
  fi
}

build_unique_dag_task_ids() {
  local task_id
  UNIQUE_DAG_TASK_IDS=()
  for task_id in "${DAG_TASK_IDS[@]}"; do
    if array_contains "${task_id}" ${UNIQUE_DAG_TASK_IDS+"${UNIQUE_DAG_TASK_IDS[@]}"}; then
      error "Duplicate DAG task id detected: ${task_id}"
      return 1
    fi
    UNIQUE_DAG_TASK_IDS+=("${task_id}")
  done
  return 0
}

sorted_dep_string() {
  local dep_raw="$1"
  local dep
  local out=""
  local first=1

  while IFS= read -r dep; do
    [[ -z "${dep}" ]] && continue
    if [[ "${first}" -eq 0 ]]; then
      out+=","
    fi
    out+="${dep}"
    first=0
  done < <(deps_to_lines_cmd "${dep_raw}" | sort -u)

  printf '%s' "${out}"
}

validate_task_dag_alignment() {
  local i task_id dag_idx task_deps dag_deps

  for ((i=0; i<${#TASK_IDS[@]}; i++)); do
    task_id="${TASK_IDS[$i]}"
    if ! dag_idx="$(find_dag_index "${task_id}")"; then
      error "Task ${task_id} exists in tasks file but missing in DAG"
      exit 2
    fi

    task_deps="$(sorted_dep_string "${TASK_DEPSS[$i]}")"
    dag_deps="$(sorted_dep_string "${DAG_DEPSS[$dag_idx]}")"

    if [[ "${task_deps}" != "${dag_deps}" ]]; then
      error "Dependency mismatch for ${task_id}: tasks='${task_deps}' dag='${dag_deps}'"
      exit 2
    fi
  done

  for ((i=0; i<${#DAG_TASK_IDS[@]}; i++)); do
    task_id="${DAG_TASK_IDS[$i]}"
    if ! find_task_index "${task_id}" >/dev/null 2>&1; then
      error "DAG task ${task_id} missing in tasks file"
      exit 2
    fi
  done
}

compute_waves() {
  local remaining=()
  local resolved=()
  local task_id dag_idx deps dep parallel
  local ready_wave=()
  local ready_safe=()
  local ready_unsafe=()
  local rem_idx

  WAVE_TASKS=()

  for task_id in "${UNIQUE_DAG_TASK_IDS[@]}"; do
    if ! is_done "${task_id}"; then
      remaining+=("${task_id}")
    fi
  done

  # nounset-safe copy for empty arrays
  resolved=(${DONE_IDS+"${DONE_IDS[@]}"})

  while [[ "${#remaining[@]}" -gt 0 ]]; do
    ready_wave=()
    ready_safe=()
    ready_unsafe=()

    for task_id in "${remaining[@]}"; do
      dag_idx="$(find_dag_index "${task_id}")"
      deps="${DAG_DEPSS[$dag_idx]}"

      dep_ready=true
      while IFS= read -r dep; do
        [[ -z "${dep}" ]] && continue
        if ! array_contains "${dep}" ${resolved+"${resolved[@]}"}; then
          dep_ready=false
          break
        fi
      done < <(deps_to_lines_cmd "${deps}")

      if [[ "${dep_ready}" == "true" ]]; then
        parallel="$(parallel_to_bool "${DAG_PARALLELS[$dag_idx]}")"
        if [[ "${parallel}" == "true" ]]; then
          ready_safe+=("${task_id}")
        else
          ready_unsafe+=("${task_id}")
        fi
      fi
    done

    if [[ "${#ready_safe[@]}" -eq 0 ]] && [[ "${#ready_unsafe[@]}" -eq 0 ]]; then
      return 1
    fi

    if [[ "${#ready_safe[@]}" -gt 0 ]]; then
      ready_wave=(${ready_safe+"${ready_safe[@]}"})
    else
      # non-parallel-safe tasks must not start in parallel.
      ready_wave=("${ready_unsafe[0]}")
    fi

    WAVE_TASKS+=("$(printf '%s' "${ready_wave[*]}" | tr ' ' ',')")

    for task_id in "${ready_wave[@]}"; do
      resolved+=("${task_id}")
    done

    new_remaining=()
    for task_id in "${remaining[@]}"; do
      keep=true
      for rem_idx in "${ready_wave[@]}"; do
        if [[ "${task_id}" == "${rem_idx}" ]]; then
          keep=false
          break
        fi
      done
      if [[ "${keep}" == "true" ]]; then
        new_remaining+=("${task_id}")
      fi
    done
    remaining=(${new_remaining+"${new_remaining[@]}"})
  done

  return 0
}

task_wave_index() {
  local target="$1"
  local wave_idx wave_csv task
  for ((wave_idx=0; wave_idx<${#WAVE_TASKS[@]}; wave_idx++)); do
    wave_csv="${WAVE_TASKS[$wave_idx]}"
    IFS=',' read -r -a wave_tasks <<<"${wave_csv}"
    for task in "${wave_tasks[@]}"; do
      if [[ "${task}" == "${target}" ]]; then
        echo $((wave_idx + 1))
        return 0
      fi
    done
  done
  echo 0
}

resolve_profile() {
  local config_path="${HOME}/.codex/config.toml"
  PROFILE_SELECTED="default"
  PROFILE_FALLBACK=true

  if [[ -f "${config_path}" ]] && grep -q '^\[profiles\.fast\]' "${config_path}"; then
    PROFILE_SELECTED="fast"
    PROFILE_FALLBACK=false
  fi
}

write_status_record() {
  local task_id="$1"
  local agent_id="$2"
  local status="$3"
  local attempt="$4"
  local gate_passed="$5"
  local review_passed="$6"
  local blocked_reason="$7"
  local wave="$8"
  local stage="$9"

  local escaped_reason="${blocked_reason//\"/\\\"}"

  printf '{"task_id":"%s","agent_id":"%s","status":"%s","attempt":%s,"gate_passed":%s,"pr_review_passed":%s,"blocked_reason":"%s","wave":%s,"stage":"%s","profile":"%s","profile_fallback":%s}\n' \
    "${task_id}" "${agent_id}" "${status}" "${attempt}" "${gate_passed}" "${review_passed}" "${escaped_reason}" "${wave}" "${stage}" "${PROFILE_SELECTED}" "${PROFILE_FALLBACK}" >> "${STATUS_FILE}"
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

write_plan() {
  local idx task_id status deps parallel deps_json ready parallel_bool risk dag_idx stage wave

  : > "${PLAN_FILE}"

  for ((idx=0; idx<${#TASK_IDS[@]}; idx++)); do
    task_id="${TASK_IDS[$idx]}"
    status="${TASK_STATUSS[$idx]}"
    deps="${TASK_DEPSS[$idx]}"
    parallel="${TASK_PARALLELS[$idx]}"

    deps_json="$(deps_to_json "${deps}")"
    parallel_bool="$(parallel_to_bool "${parallel}")"
    risk="$(risk_level_for_task "${deps}" "${parallel}")"
    wave="$(task_wave_index "${task_id}")"

    dag_idx="$(find_dag_index "${task_id}")"
    stage="${DAG_STAGES[$dag_idx]}"

    if [[ "$(to_lower "${status}")" == "done" ]]; then
      ready="false"
    elif dag_deps_are_done "${deps}"; then
      ready="true"
    else
      ready="false"
    fi

    printf '{"task_id":"%s","dependencies":%s,"parallel_safe":%s,"gate_stack":"%s","risk_level":"%s","ready":%s,"stage":"%s","wave":%s}\n' \
      "${task_id}" "${deps_json}" "${parallel_bool}" "${STACK}" "${risk}" "${ready}" "${stage}" "${wave}" >> "${PLAN_FILE}"
  done
}

process_qa_feedback() {
  local qa_dir bb_root qa_file payload qa_count=0
  bb_root="$(blackboard_root "${PROJECT_DIR}")"
  qa_dir="${bb_root}/feedback/qa"

  shopt -s nullglob
  for qa_file in "${qa_dir}"/*.json; do
    qa_count=$((qa_count + 1))
    payload="$(cat "${qa_file}")"

    if ! blackboard_emit_event "${PROJECT_DIR}" "QA_FAILURE_REPORTED" "QA" "IMPLEMENTATION" "${payload}"; then
      return 1
    fi

    if ! blackboard_emit_event "${PROJECT_DIR}" "SELF_HEAL_REPLAN_REQUESTED" "IMPLEMENTATION" "ORCHESTRATION" "${payload}"; then
      return 1
    fi
  done
  shopt -u nullglob

  printf '%s' "${qa_count}"
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
    --dag-file)
      [[ $# -ge 2 ]] || { error "--dag-file requires a value"; usage; exit 2; }
      DAG_FILE="$2"
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

if [[ -z "${DAG_FILE}" ]]; then
  DAG_FILE="$(awk '
    /^- Task DAG:/ {
      line=$0
      sub(/^- Task DAG:[[:space:]]*/, "", line)
      gsub(/`/, "", line)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
      print line
      exit
    }
  ' "${TASKS_FILE}")"
fi

if [[ -z "${DAG_FILE}" ]]; then
  base_name="$(basename "${TASKS_FILE}")"
  id="${base_name#tasks-}"
  id="${id%%-*}"
  slug="${base_name#tasks-${id}-}"
  slug="${slug%.md}"
  DAG_FILE="tasks/dag-${id}-${slug}.json"
fi

if [[ "${DAG_FILE}" != /* ]]; then
  DAG_FILE="${PROJECT_DIR}/${DAG_FILE}"
fi
if [[ ! -f "${DAG_FILE}" ]]; then
  error "DAG file not found: ${DAG_FILE}"
  exit 2
fi

load_tasks
load_dag
if ! build_unique_dag_task_ids; then
  exit 2
fi
validate_task_dag_alignment

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
if [[ -z "${STACK}" ]]; then
  STACK="${DAG_GATE_STACK}"
fi

case "${STACK}" in
  python|node|go)
    ;;
  *)
    error "Unsupported or missing stack '${STACK}'. Use --stack <python|node|go> or add metadata."
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

if ! compute_waves; then
  : > "${STATUS_FILE}"
  for task_id in "${TASK_IDS[@]}"; do
    if ! is_done "${task_id}"; then
      write_status_record "${task_id}" "sub-0" "blocked" 0 false false "dag_cycle_detected" 0 "IMPLEMENTATION"
    fi
  done
  : > "${PLAN_FILE}"
  cat > "${SUMMARY_FILE}" <<EOF_SUMMARY
{"approved":false,"plan_only":false,"stack":"${STACK}","loop_complete":false,"replan_triggered":false,"failed_task":"","qa_feedback_processed":0}
EOF_SUMMARY
  error "Unable to compute DAG waves. Check for cyclic dependencies."
  exit 1
fi

write_plan

if [[ "${PLAN_ONLY}" -eq 1 ]]; then
  : > "${STATUS_FILE}"
  cat > "${SUMMARY_FILE}" <<EOF_SUMMARY
{"approved":false,"plan_only":true,"stack":"${STACK}","loop_complete":false,"replan_triggered":false,"failed_task":"","qa_feedback_processed":0}
EOF_SUMMARY
  echo "[lead-orchestrate] plan written: ${PLAN_FILE}"
  exit 0
fi

if [[ "${APPROVE}" -ne 1 ]]; then
  error "Coordinator approval required. Re-run with --approve or use --plan-only."
  exit 2
fi

: > "${STATUS_FILE}"
blackboard_init "${PROJECT_DIR}"
resolve_profile

bb_root="$(blackboard_root "${PROJECT_DIR}")"
blackboard_write_json "${PROJECT_DIR}" "state/profile-selection.json" "{\"selected_profile\":\"${PROFILE_SELECTED}\",\"fallback\":${PROFILE_FALLBACK}}"
blackboard_emit_event "${PROJECT_DIR}" "ARTIFACT_PUBLISHED" "ORCHESTRATION" "IMPLEMENTATION" "{\"path\":\"${bb_root}/state/profile-selection.json\"}" >/dev/null || true

agent_seq=0
replan_triggered=false
loop_complete=false
failed_task=""
qa_feedback_processed=0

for ((wave_idx=0; wave_idx<${#WAVE_TASKS[@]}; wave_idx++)); do
  wave_num=$((wave_idx + 1))
  wave_csv="${WAVE_TASKS[$wave_idx]}"
  IFS=',' read -r -a wave_tasks <<<"${wave_csv}"

  pending_wave_tasks=()
  for task_id in "${wave_tasks[@]}"; do
    if ! is_done "${task_id}"; then
      pending_wave_tasks+=("${task_id}")
    fi
  done

  if [[ "${#pending_wave_tasks[@]}" -eq 0 ]]; then
    continue
  fi

  wave_json_tasks="["
  first_item=1
  for task_id in "${pending_wave_tasks[@]}"; do
    if [[ "${first_item}" -eq 0 ]]; then
      wave_json_tasks+=","
    fi
    wave_json_tasks+="\"${task_id}\""
    first_item=0
  done
  wave_json_tasks+="]"

  blackboard_write_json "${PROJECT_DIR}" "integration/waves/wave-${wave_num}.json" "{\"wave\":${wave_num},\"tasks\":${wave_json_tasks},\"state\":\"started\"}"
  if ! blackboard_emit_event "${PROJECT_DIR}" "INTEGRATION_DIRECTIVE_PUBLISHED" "ORCHESTRATION" "IMPLEMENTATION" "{\"wave\":${wave_num},\"path\":\"${bb_root}/integration/waves/wave-${wave_num}.json\"}"; then
    failed_task="${pending_wave_tasks[0]}"
    write_status_record "${failed_task}" "sub-0" "blocked" 0 false false "non_adjacent_stage_route" "${wave_num}" "IMPLEMENTATION"
    break
  fi

  for task_id in "${pending_wave_tasks[@]}"; do
    agent_seq=$((agent_seq + 1))
    agent_id="sub-${agent_seq}"
    dag_idx="$(find_dag_index "${task_id}")"
    stage="${DAG_STAGES[$dag_idx]}"

    blackboard_write_json "${PROJECT_DIR}" "integration/tasks/${task_id}.json" "{\"task_id\":\"${task_id}\",\"wave\":${wave_num},\"state\":\"ready\",\"directive\":\"follow_dag_and_contracts\"}"
    blackboard_emit_event "${PROJECT_DIR}" "ARTIFACT_PUBLISHED" "ORCHESTRATION" "IMPLEMENTATION" "{\"task_id\":\"${task_id}\",\"path\":\"${bb_root}/integration/tasks/${task_id}.json\"}" >/dev/null || true

    blackboard_write_json "${PROJECT_DIR}" "jobs/${task_id}.json" "{\"task_id\":\"${task_id}\",\"wave\":${wave_num},\"preferred_profile\":\"fast\",\"selected_profile\":\"${PROFILE_SELECTED}\",\"fallback_allowed\":true,\"profile_fallback\":${PROFILE_FALLBACK},\"integration_artifact\":\"${bb_root}/integration/tasks/${task_id}.json\"}"
    blackboard_emit_event "${PROJECT_DIR}" "TASK_DISPATCHED" "ORCHESTRATION" "IMPLEMENTATION" "{\"task_id\":\"${task_id}\",\"job\":\"${bb_root}/jobs/${task_id}.json\"}" >/dev/null || true

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
      write_status_record "${task_id}" "${agent_id}" "done" "${attempt}" true true "" "${wave_num}" "${stage}"
      mark_done "${task_id}"
      idx="$(find_task_index "${task_id}")"
      TASK_STATUSS[$idx]="done"
    else
      blackboard_write_json "${PROJECT_DIR}" "integration/tasks/${task_id}.json" "{\"task_id\":\"${task_id}\",\"wave\":${wave_num},\"state\":\"conflict\",\"directive\":\"resolve_gate_failure\"}"
      blackboard_emit_event "${PROJECT_DIR}" "INTEGRATION_CONFLICT_DETECTED" "IMPLEMENTATION" "ORCHESTRATION" "{\"task_id\":\"${task_id}\",\"wave\":${wave_num},\"reason\":\"gate_failed_after_${MAX_FIX_RETRIES}_attempts\"}" >/dev/null || true
      write_status_record "${task_id}" "${agent_id}" "blocked" "${attempt}" false false "gate_failed_after_${MAX_FIX_RETRIES}_attempts" "${wave_num}" "${stage}"
      failed_task="${task_id}"
      if [[ "${REPLAN_ON_FAILURE}" -eq 1 ]]; then
        replan_triggered=true
      fi
      break 2
    fi
  done

  blackboard_write_json "${PROJECT_DIR}" "integration/waves/wave-${wave_num}.json" "{\"wave\":${wave_num},\"tasks\":${wave_json_tasks},\"state\":\"completed\"}"
done

if [[ -z "${failed_task}" ]]; then
  qa_feedback_processed="$(process_qa_feedback || echo 0)"
  if [[ "${qa_feedback_processed}" -gt 0 ]]; then
    replan_triggered=true
  fi
fi

if [[ -z "${failed_task}" ]] && [[ "${replan_triggered}" == "false" ]]; then
  loop_complete=true
fi

write_plan

cat > "${SUMMARY_FILE}" <<EOF_SUMMARY
{"approved":true,"plan_only":false,"stack":"${STACK}","loop_complete":${loop_complete},"replan_triggered":${replan_triggered},"failed_task":"${failed_task}","qa_feedback_processed":${qa_feedback_processed}}
EOF_SUMMARY

echo "[lead-orchestrate] plan: ${PLAN_FILE}"
echo "[lead-orchestrate] status: ${STATUS_FILE}"
echo "[lead-orchestrate] summary: ${SUMMARY_FILE}"

if [[ "${loop_complete}" == "true" ]]; then
  echo "LOOP_COMPLETE"
  exit 0
fi

exit 1
