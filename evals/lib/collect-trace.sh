#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

TRACE_MODE="hybrid"
OUTPUT_META=""
OUTPUT_TRACE=""
TIMEOUT_SECONDS=90
PROMPT="Respond with OK only."
CODEX_BIN="codex"

usage() {
  cat <<'USAGE'
Usage:
  ./evals/lib/collect-trace.sh \
    --output-meta <json-file> \
    [--trace-mode <hybrid|trace-only|local-only>] \
    [--output-trace <jsonl-file>] \
    [--trace-timeout-seconds <int>] \
    [--prompt <text>] \
    [--codex-bin <command>]
USAGE
}

error() {
  echo "[trace-collect] ERROR: $*" >&2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --trace-mode)
      [[ $# -ge 2 ]] || { error "--trace-mode requires a value"; usage; exit 2; }
      TRACE_MODE="$2"
      shift 2
      ;;
    --output-meta)
      [[ $# -ge 2 ]] || { error "--output-meta requires a value"; usage; exit 2; }
      OUTPUT_META="$2"
      shift 2
      ;;
    --output-trace)
      [[ $# -ge 2 ]] || { error "--output-trace requires a value"; usage; exit 2; }
      OUTPUT_TRACE="$2"
      shift 2
      ;;
    --trace-timeout-seconds)
      [[ $# -ge 2 ]] || { error "--trace-timeout-seconds requires a value"; usage; exit 2; }
      TIMEOUT_SECONDS="$2"
      shift 2
      ;;
    --prompt)
      [[ $# -ge 2 ]] || { error "--prompt requires a value"; usage; exit 2; }
      PROMPT="$2"
      shift 2
      ;;
    --codex-bin)
      [[ $# -ge 2 ]] || { error "--codex-bin requires a value"; usage; exit 2; }
      CODEX_BIN="$2"
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

if [[ -z "${OUTPUT_META}" ]]; then
  error "--output-meta is required"
  usage
  exit 2
fi

case "${TRACE_MODE}" in
  hybrid|trace-only|local-only)
    ;;
  *)
    error "Unsupported trace mode '${TRACE_MODE}'. Use: hybrid, trace-only, local-only"
    exit 2
    ;;
esac

if ! [[ "${TIMEOUT_SECONDS}" =~ ^[0-9]+$ ]]; then
  error "--trace-timeout-seconds must be an integer"
  exit 2
fi

write_meta() {
  local loop_count="$1"
  local retries="$2"
  local skill_triggered="$3"
  local trace_status="$4"
  local fallback_reason="$5"
  local trace_mode="$6"

  jq -cn \
    --argjson loop_count "${loop_count}" \
    --argjson retries "${retries}" \
    --argjson skill_triggered "${skill_triggered}" \
    --arg trace_status "${trace_status}" \
    --arg fallback_reason "${fallback_reason}" \
    --arg trace_mode "${trace_mode}" \
    '{
      loop_count:$loop_count,
      retries:$retries,
      skill_triggered:$skill_triggered,
      trace_status:$trace_status,
      fallback_reason:$fallback_reason,
      trace_mode:$trace_mode
    }' > "${OUTPUT_META}"
}

if [[ "${TRACE_MODE}" == "local-only" ]]; then
  write_meta 0 0 false "skipped" "local-only mode" "${TRACE_MODE}"
  exit 0
fi

if [[ -z "${OUTPUT_TRACE}" ]]; then
  TRACE_FILE="$(mktemp)"
  cleanup_trace_file=1
else
  TRACE_FILE="${OUTPUT_TRACE}"
  cleanup_trace_file=0
fi
TRACE_ERR_FILE="$(mktemp)"

cleanup() {
  if [[ "${cleanup_trace_file}" -eq 1 ]]; then
    rm -f "${TRACE_FILE}"
  fi
  rm -f "${TRACE_ERR_FILE}"
}
trap cleanup EXIT

run_with_timeout() {
  if command -v timeout >/dev/null 2>&1; then
    timeout "${TIMEOUT_SECONDS}" "$@"
    return $?
  fi
  if command -v gtimeout >/dev/null 2>&1; then
    gtimeout "${TIMEOUT_SECONDS}" "$@"
    return $?
  fi

  echo "[trace-collect] WARN: timeout utility not found; running without timeout" >&2
  "$@"
}

set +e
run_with_timeout "${CODEX_BIN}" exec --json --skip-git-repo-check "${PROMPT}" > "${TRACE_FILE}" 2> "${TRACE_ERR_FILE}"
trace_status=$?
set -e

if [[ "${trace_status}" -eq 0 ]]; then
  PARSED_META_FILE="$(mktemp)"
  "${SCRIPT_DIR}/parse-trace.sh" --input "${TRACE_FILE}" --output "${PARSED_META_FILE}"
  jq '. + {trace_status:"success",fallback_reason:"",trace_mode:$mode}' \
    --arg mode "${TRACE_MODE}" \
    "${PARSED_META_FILE}" > "${OUTPUT_META}"
  rm -f "${PARSED_META_FILE}"
  exit 0
fi

fallback_reason="$(head -n 1 "${TRACE_ERR_FILE}" | tr -d '\r')"
if [[ -z "${fallback_reason}" ]]; then
  fallback_reason="trace command failed with exit code ${trace_status}"
fi

if [[ "${TRACE_MODE}" == "trace-only" ]]; then
  write_meta 0 0 false "failed" "${fallback_reason}" "${TRACE_MODE}"
  echo "[trace-collect] ERROR: trace-only mode failed: ${fallback_reason}" >&2
  exit 1
fi

write_meta 0 0 false "fallback" "${fallback_reason}" "${TRACE_MODE}"
echo "[trace-collect] INFO: falling back to local metrics (${fallback_reason})"
exit 0
