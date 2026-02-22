#!/usr/bin/env bash
set -euo pipefail

INPUT_FILE=""
OUTPUT_FILE=""

usage() {
  cat <<'USAGE'
Usage:
  ./evals/lib/parse-trace.sh --input <jsonl-file> [--output <json-file>]

Outputs JSON:
  {"loop_count":0,"retries":0,"skill_triggered":false}
USAGE
}

error() {
  echo "[trace-parse] ERROR: $*" >&2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input)
      [[ $# -ge 2 ]] || { error "--input requires a value"; usage; exit 2; }
      INPUT_FILE="$2"
      shift 2
      ;;
    --output)
      [[ $# -ge 2 ]] || { error "--output requires a value"; usage; exit 2; }
      OUTPUT_FILE="$2"
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

if [[ -z "${INPUT_FILE}" ]]; then
  error "--input is required"
  usage
  exit 2
fi

if [[ ! -f "${INPUT_FILE}" ]]; then
  error "Input file not found: ${INPUT_FILE}"
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  error "jq is required to parse trace JSONL"
  exit 2
fi

loop_count="$(jq -R -s '
  split("\n")
  | map(select(length > 0) | (fromjson? // null))
  | map(select(type == "object" and .type == "turn.started"))
  | length
' "${INPUT_FILE}")"

retries="$(jq -R -s '
  split("\n")
  | map(select(length > 0) | (fromjson? // null))
  | map(
      select(
        type == "object"
        and .type == "error"
        and ((.message // "") | test("Reconnecting"; "i"))
      )
    )
  | length
' "${INPUT_FILE}")"

skill_triggered="$(jq -R -s '
  split("\n")
  | map(select(length > 0) | (fromjson? // null))
  | map(
      select(
        type == "object"
        and (
          ((.message // "") | test("skill|SKILL\\.md|/skills/"; "i"))
          or ((.tool_name // "") | test("skill"; "i"))
          or ((.name // "") | test("skill"; "i"))
        )
      )
    )
  | (length > 0)
' "${INPUT_FILE}")"

result_json="$(jq -cn \
  --argjson loop_count "${loop_count}" \
  --argjson retries "${retries}" \
  --argjson skill_triggered "${skill_triggered}" \
  '{loop_count:$loop_count,retries:$retries,skill_triggered:$skill_triggered}')"

if [[ -n "${OUTPUT_FILE}" ]]; then
  printf '%s\n' "${result_json}" > "${OUTPUT_FILE}"
else
  printf '%s\n' "${result_json}"
fi
