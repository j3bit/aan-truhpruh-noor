#!/usr/bin/env bash
set -euo pipefail

ROOT="${EVAL_REPO_ROOT:-$(pwd)}"
TRACE_HELPER_DIR="${EVAL_TRACE_HELPER_DIR:-${ROOT}/evals/lib}"
META_PATH="${EVAL_META_PATH:?EVAL_META_PATH is required}"
TRACE_MODE="${EVAL_TRACE_MODE:-hybrid}"

if [[ ! -x "${TRACE_HELPER_DIR}/collect-trace.sh" ]]; then
  echo "[case-05] missing trace helper: ${TRACE_HELPER_DIR}/collect-trace.sh" >&2
  exit 1
fi

"${TRACE_HELPER_DIR}/collect-trace.sh" \
  --trace-mode "${TRACE_MODE}" \
  --trace-timeout-seconds "${EVAL_TRACE_TIMEOUT_SECONDS:-90}" \
  --output-meta "${META_PATH}" \
  --codex-bin "__missing_codex__" \
  --prompt "Respond with OK only."

if [[ "${TRACE_MODE}" == "trace-only" ]]; then
  echo "[case-05] trace-only mode unexpectedly succeeded" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "[case-05] jq is required for assertions" >&2
  exit 1
fi

case "${TRACE_MODE}" in
  hybrid)
    jq -e '
      (.trace_status == "fallback")
      and (.loop_count == 0)
      and (.retries == 0)
      and (.skill_triggered == false)
    ' "${META_PATH}" >/dev/null
    ;;
  local-only)
    jq -e '
      (.trace_status == "skipped")
      and (.loop_count == 0)
      and (.retries == 0)
      and (.skill_triggered == false)
    ' "${META_PATH}" >/dev/null
    ;;
  *)
    echo "[case-05] unsupported trace mode for this case: ${TRACE_MODE}" >&2
    exit 1
    ;;
esac
