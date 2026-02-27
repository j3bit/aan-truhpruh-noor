#!/usr/bin/env bash
set -euo pipefail

ROOT="${EVAL_REPO_ROOT:-$(pwd)}"
CONFIG="${ROOT}/.codex/config.toml"

if [[ ! -f "${CONFIG}" ]]; then
  echo "[case-09] missing config file: .codex/config.toml" >&2
  exit 1
fi

required_tokens=(
  "multi_agent = true"
  "mode = \"lead_orchestrated\""
  "replan_trigger = \"failure_or_blocker\""
  "allow_replan_on_success = false"
  "blackboard_root = \".blackboard\""
  "stage_model = \"IDEATION,PRD,TRD,TASK_PLANNING,ORCHESTRATION,IMPLEMENTATION,QA,DEPLOYMENT\""
  "self_heal_relay = \"QA->IMPLEMENTATION->ORCHESTRATION\""
  "permissions = \"read_only\""
  "can_modify_files = false"
  "skills = [\"orchestrate-tasks\"]"
  "task_scope = \"single_task\""
  "fix_retry_limit = 3"
  "preferred_profile = \"fast\""
  "completion_signal = \"LOOP_COMPLETE\""
)

for token in "${required_tokens[@]}"; do
  if ! grep -Fq "${token}" "${CONFIG}"; then
    echo "[case-09] missing required config token: ${token}" >&2
    exit 1
  fi
done
