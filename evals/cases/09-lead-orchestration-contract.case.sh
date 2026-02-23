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
  "permissions = \"read_only\""
  "can_modify_files = false"
  "task_scope = \"single_task\""
  "fix_retry_limit = 3"
  "completion_signal = \"LOOP_COMPLETE\""
)

for token in "${required_tokens[@]}"; do
  if ! grep -Fq "${token}" "${CONFIG}"; then
    echo "[case-09] missing required config token: ${token}" >&2
    exit 1
  fi
done
