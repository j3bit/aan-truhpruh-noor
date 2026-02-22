#!/usr/bin/env bash
set -euo pipefail

ROOT="${EVAL_REPO_ROOT:-$(pwd)}"
RULES_FILE="${ROOT}/tasks/process-rules.md"

if [[ ! -f "${RULES_FILE}" ]]; then
  echo "[case-02] missing process rules file: ${RULES_FILE}" >&2
  exit 1
fi

grep -qi "Trace logging required" "${RULES_FILE}"
