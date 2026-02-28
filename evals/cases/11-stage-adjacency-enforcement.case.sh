#!/usr/bin/env bash
set -euo pipefail

ROOT="${EVAL_REPO_ROOT:-$(pwd)}"
TMP_DIR="$(mktemp -d)"
TARGET="${TMP_DIR}/adjacency-check"
trap 'rm -rf "${TMP_DIR}"' EXIT

bash "${ROOT}/scripts/bootstrap-new-project.sh" \
  --name "adjacency-check" \
  --stack python \
  --dest "${TARGET}"

# shellcheck source=/dev/null
source "${TARGET}/scripts/lib/blackboard.sh"

blackboard_init "${TARGET}"

set +e
blackboard_emit_event "${TARGET}" "QA_FAILURE_REPORTED" "QA" "IMPLEMENTATION" '{"case":"11-adjacent"}'
adjacent_status=$?
set -e

if [[ "${adjacent_status}" -ne 0 ]]; then
  echo "[case-11] adjacent stage route unexpectedly rejected" >&2
  exit 1
fi

set +e
blackboard_emit_event "${TARGET}" "QA_FAILURE_REPORTED" "QA" "ORCHESTRATION" '{"case":"11"}'
route_status=$?
set -e

if [[ "${route_status}" -eq 0 ]]; then
  echo "[case-11] non-adjacent stage route unexpectedly accepted" >&2
  exit 1
fi

events_file="${TARGET}/.blackboard/events/events.jsonl"
grep -q '"status":"accepted"' "${events_file}"
grep -q '"status":"rejected"' "${events_file}"
grep -q '"blocked_reason":"non_adjacent_stage_route"' "${events_file}"

# Ensure emitted JSONL lines are valid JSON payload records.
jq -e . "${events_file}" >/dev/null
