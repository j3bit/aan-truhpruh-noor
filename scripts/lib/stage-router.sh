#!/usr/bin/env bash
set -euo pipefail

STAGE_IDEATION="IDEATION"
STAGE_PRD="PRD"
STAGE_TRD="TRD"
STAGE_TASK_PLANNING="TASK_PLANNING"
STAGE_ORCHESTRATION="ORCHESTRATION"
STAGE_IMPLEMENTATION="IMPLEMENTATION"
STAGE_QA="QA"
STAGE_DEPLOYMENT="DEPLOYMENT"

stage_router_stages() {
  cat <<'EOF_STAGES'
IDEATION
PRD
TRD
TASK_PLANNING
ORCHESTRATION
IMPLEMENTATION
QA
DEPLOYMENT
EOF_STAGES
}

stage_router_index_of() {
  local stage="$1"
  local idx=0
  while IFS= read -r value; do
    if [[ "${value}" == "${stage}" ]]; then
      printf '%s' "${idx}"
      return 0
    fi
    idx=$((idx + 1))
  done < <(stage_router_stages)
  return 1
}

stage_router_adjacent() {
  local from_stage="$1"
  local to_stage="$2"
  local from_idx to_idx diff

  if ! from_idx="$(stage_router_index_of "${from_stage}")"; then
    return 1
  fi
  if ! to_idx="$(stage_router_index_of "${to_stage}")"; then
    return 1
  fi

  diff=$((from_idx - to_idx))
  if [[ "${diff}" -lt 0 ]]; then
    diff=$((diff * -1))
  fi

  [[ "${diff}" -eq 1 ]]
}

stage_router_validate_route() {
  local from_stage="$1"
  local to_stage="$2"

  stage_router_adjacent "${from_stage}" "${to_stage}"
}
