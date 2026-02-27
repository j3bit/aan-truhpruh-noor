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
  ".agents/skills/plan-tasks/SKILL.md"
  ".agents/skills/orchestrate-tasks/SKILL.md"
  ".agents/skills/process-task/SKILL.md"
  ".agents/skills/fix-failing-checks/SKILL.md"
  ".agents/skills/pr-review/SKILL.md"
)
REQUIRED_TEMPLATE_FILES=(
  ".codex/config.toml"
  "docs/runbook/03-multi-agent.md"
  "scripts/lead-orchestrate.sh"
  "scripts/lib/blackboard.sh"
  "scripts/lib/stage-router.sh"
  "tasks/templates/trd.template.md"
  "tasks/templates/dag.template.md"
  "tasks/templates/dag.template.json"
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

normalize_deps() {
  local deps="$1"
  deps="${deps//\`/}"
  deps="$(printf '%s' "${deps}" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed '/^$/d' | sort -u | paste -sd ',' -)"
  printf '%s' "${deps}"
}

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

validate_tasks_metadata_contract() {
  local file="$1"
  local rel_path="$2"

  if ! awk '
    BEGIN {
      has_trd = 0
      has_dag = 0
      failed = 0
    }

    /^- TRD:/ { has_trd = 1 }
    /^- Task DAG:/ { has_dag = 1 }

    END {
      missing = ""
      if (!has_trd) {
        missing = missing " TRD"
      }
      if (!has_dag) {
        missing = missing " Task DAG"
      }
      if (missing != "") {
        printf("[contracts] FAIL: %s missing metadata:%s\n", file_path, missing) > "/dev/stderr"
        failed = 1
      }
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

validate_trd_file_required_sections() {
  local file="$1"
  local rel_path="$2"

  if ! awk '
    BEGIN {
      has_context = 0
      has_arch_goals = 0
      has_clean_arch = 0
      has_components = 0
      has_interfaces = 0
      has_dependency_graph = 0
      has_test_arch = 0
      has_rollout = 0
      failed = 0
    }

    /^##[[:space:]]/ {
      heading = tolower($0)
      if (index(heading, "context") > 0) has_context = 1
      if (index(heading, "architecture goals") > 0) has_arch_goals = 1
      if (index(heading, "clean architecture") > 0) has_clean_arch = 1
      if (index(heading, "component catalog") > 0) has_components = 1
      if (index(heading, "interface contracts") > 0) has_interfaces = 1
      if (index(heading, "dependency graph") > 0) has_dependency_graph = 1
      if (index(heading, "test architecture") > 0) has_test_arch = 1
      if (index(heading, "rollout") > 0) has_rollout = 1
    }

    END {
      missing = ""
      if (!has_context) missing = missing " Context"
      if (!has_arch_goals) missing = missing " Architecture Goals"
      if (!has_clean_arch) missing = missing " Clean Architecture"
      if (!has_components) missing = missing " Component Catalog"
      if (!has_interfaces) missing = missing " Interface Contracts"
      if (!has_dependency_graph) missing = missing " Dependency Graph"
      if (!has_test_arch) missing = missing " Test Architecture"
      if (!has_rollout) missing = missing " Rollout"

      if (missing != "") {
        printf("[contracts] FAIL: %s missing TRD sections:%s\n", file_path, missing) > "/dev/stderr"
        failed = 1
      }

      exit failed
    }
  ' "file_path=${rel_path}" "${file}"; then
    FAILED=1
  fi
}

validate_dag_md_sections() {
  local file="$1"
  local rel_path="$2"

  if ! awk '
    BEGIN {
      has_metadata = 0
      has_nodes = 0
      has_waves = 0
      failed = 0
    }

    /^##[[:space:]]+Metadata/ { has_metadata = 1 }
    /^##[[:space:]]+Nodes/ { has_nodes = 1 }
    /^##[[:space:]]+Waves/ { has_waves = 1 }

    END {
      missing = ""
      if (!has_metadata) missing = missing " Metadata"
      if (!has_nodes) missing = missing " Nodes"
      if (!has_waves) missing = missing " Waves"
      if (missing != "") {
        printf("[contracts] FAIL: %s missing DAG sections:%s\n", file_path, missing) > "/dev/stderr"
        failed = 1
      }
      exit failed
    }
  ' "file_path=${rel_path}" "${file}"; then
    FAILED=1
  fi
}

extract_task_dependencies() {
  local tasks_file="$1"
  local out_file="$2"

  awk '
    function trim(v) {
      gsub(/`/, "", v)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
      return v
    }
    /^### T-[0-9]+:/ {
      task_id = $2
      sub(/:/, "", task_id)
      deps = ""
      next
    }
    task_id != "" && /^- Dependencies:/ {
      line = $0
      sub(/^- Dependencies:[[:space:]]*/, "", line)
      line = trim(line)
      if (tolower(line) == "none" || line == "") {
        deps = ""
      } else {
        gsub(/[[:space:]]+/, "", line)
        deps = line
      }
      print task_id "|" deps
      task_id = ""
      deps = ""
      next
    }
  ' "${tasks_file}" | sort -u > "${out_file}"
}

extract_dag_dependencies() {
  local dag_file="$1"
  local out_file="$2"

  if ! perl -MJSON::PP -e '
    use strict;
    use warnings;
    my ($path) = @ARGV;
    local $/;
    open my $fh, "<", $path or die "open_failed";
    my $json = <$fh>;
    close $fh;
    my $obj = decode_json($json);
    die "missing_metadata" unless ref($obj->{metadata}) eq "HASH";
    for my $k (qw(id slug prd trd tasks gate_stack)) {
      die "missing_metadata_key_$k" unless defined $obj->{metadata}{$k};
    }
    die "missing_nodes" unless ref($obj->{nodes}) eq "ARRAY";
    for my $node (@{$obj->{nodes}}) {
      die "invalid_node" unless ref($node) eq "HASH";
      die "missing_task_id" unless defined $node->{task_id};
      die "missing_depends_on" unless ref($node->{depends_on}) eq "ARRAY";
      die "missing_parallel_safe" unless exists $node->{parallel_safe};
      my @deps = sort @{$node->{depends_on}};
      print $node->{task_id} . "|" . join(",", @deps) . "\n";
    }
  ' "${dag_file}" > "${out_file}.raw" 2>/dev/null; then
    echo "[contracts] FAIL: invalid DAG json schema: ${dag_file}" >&2
    FAILED=1
    return
  fi

  sed '/^$/d' "${out_file}.raw" | sort -u > "${out_file}"
  rm -f "${out_file}.raw"
}

validate_task_dag_consistency() {
  local tasks_file="$1"
  local rel_tasks="$2"
  local base_name id slug expected_dag rel_expected_dag
  local task_deps_file dag_deps_file

  base_name="$(basename "${tasks_file}")"
  id="${base_name#tasks-}"
  id="${id%%-*}"
  slug="${base_name#tasks-${id}-}"
  slug="${slug%.md}"

  expected_dag="${TASKS_DIR}/dag-${id}-${slug}.json"
  rel_expected_dag="tasks/dag-${id}-${slug}.json"

  if [[ ! -f "${expected_dag}" ]]; then
    echo "[contracts] FAIL: ${rel_tasks} missing paired DAG json: ${rel_expected_dag}" >&2
    FAILED=1
    return
  fi

  task_deps_file="$(mktemp)"
  dag_deps_file="$(mktemp)"

  extract_task_dependencies "${tasks_file}" "${task_deps_file}"
  extract_dag_dependencies "${expected_dag}" "${dag_deps_file}"

  if [[ -f "${dag_deps_file}" ]]; then
    if ! diff -u "${task_deps_file}" "${dag_deps_file}" >/dev/null 2>&1; then
      echo "[contracts] FAIL: dependency mismatch between ${rel_tasks} and ${rel_expected_dag}" >&2
      FAILED=1
    fi
  fi

  rm -f "${task_deps_file}" "${dag_deps_file}"
}

for pattern in \
  'prd-*.md:^tasks/prd-[0-9]{4}-[a-z0-9][a-z0-9-]*\.md$' \
  'tasks-*.md:^tasks/tasks-[0-9]{4}-[a-z0-9][a-z0-9-]*\.md$' \
  'trd-*.md:^tasks/trd-[0-9]{4}-[a-z0-9][a-z0-9-]*\.md$' \
  'dag-*.md:^tasks/dag-[0-9]{4}-[a-z0-9][a-z0-9-]*\.md$' \
  'dag-*.json:^tasks/dag-[0-9]{4}-[a-z0-9][a-z0-9-]*\.json$'
 do
  glob="${pattern%%:*}"
  regex="${pattern#*:}"
  while IFS= read -r -d '' abs_path; do
    rel_path="${abs_path#${PROJECT_DIR}/}"
    if should_check_file "${rel_path}"; then
      check_filename_contract "${rel_path}" "${regex}"
    fi
  done < <(find "${TASKS_DIR}" -maxdepth 1 -type f -name "${glob}" -print0)
done

while IFS= read -r -d '' abs_path; do
  rel_path="${abs_path#${PROJECT_DIR}/}"
  if should_check_file "${rel_path}"; then
    validate_prd_file_required_sections "${abs_path}" "${rel_path}"
  fi
done < <(find "${TASKS_DIR}" -maxdepth 1 -type f -name 'prd-*.md' -print0)

while IFS= read -r -d '' abs_path; do
  rel_path="${abs_path#${PROJECT_DIR}/}"
  if should_check_file "${rel_path}"; then
    validate_trd_file_required_sections "${abs_path}" "${rel_path}"
  fi
done < <(find "${TASKS_DIR}" -maxdepth 1 -type f -name 'trd-*.md' -print0)

while IFS= read -r -d '' abs_path; do
  rel_path="${abs_path#${PROJECT_DIR}/}"
  if should_check_file "${rel_path}"; then
    validate_dag_md_sections "${abs_path}" "${rel_path}"
  fi
done < <(find "${TASKS_DIR}" -maxdepth 1 -type f -name 'dag-*.md' -print0)

while IFS= read -r -d '' abs_path; do
  rel_path="${abs_path#${PROJECT_DIR}/}"
  if should_check_file "${rel_path}"; then
    validate_task_file_block_contract "${abs_path}" "${rel_path}"
    validate_tasks_metadata_contract "${abs_path}" "${rel_path}"
    validate_task_dag_consistency "${abs_path}" "${rel_path}"
  fi
done < <(find "${TASKS_DIR}" -maxdepth 1 -type f -name 'tasks-*.md' -print0)

if [[ "${FAILED}" -eq 0 ]]; then
  echo "[contracts] PASS"
  exit 0
fi

exit 1
