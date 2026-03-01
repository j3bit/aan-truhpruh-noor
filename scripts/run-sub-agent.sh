#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

TASK_ID=""
PROJECT_DIR=""
WORKTREE_DIR=""
STACK=""
PROFILE="default"
PROFILE_FALLBACK="true"
WORKER_BACKEND="ralph-codex"
RESULT_FILE=""
TIMEOUT_SECONDS=1800
INTEGRATION_FEEDBACK_FILE=""

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/run-sub-agent.sh \
    --task-id <T-...> \
    --project-dir <path> \
    --worktree-dir <path> \
    --stack <python|node|go> \
    --result-file <path> \
    [--profile <fast|default>] \
    [--profile-fallback <true|false>] \
    [--worker-backend <ralph-codex|codex-exec>] \
    [--integration-feedback-file <path>] \
    [--timeout-seconds <int>]
USAGE
}

error() {
  echo "[run-sub-agent] ERROR: $*" >&2
}

json_bool() {
  case "$1" in
    true|false) printf '%s' "$1" ;;
    *) printf 'false' ;;
  esac
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --task-id)
      TASK_ID="$2"
      shift 2
      ;;
    --project-dir)
      PROJECT_DIR="$2"
      shift 2
      ;;
    --worktree-dir)
      WORKTREE_DIR="$2"
      shift 2
      ;;
    --stack)
      STACK="$2"
      shift 2
      ;;
    --profile)
      PROFILE="$2"
      shift 2
      ;;
    --profile-fallback)
      PROFILE_FALLBACK="$2"
      shift 2
      ;;
    --worker-backend)
      WORKER_BACKEND="$2"
      shift 2
      ;;
    --result-file)
      RESULT_FILE="$2"
      shift 2
      ;;
    --integration-feedback-file)
      INTEGRATION_FEEDBACK_FILE="$2"
      shift 2
      ;;
    --timeout-seconds)
      TIMEOUT_SECONDS="$2"
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

if [[ -z "${TASK_ID}" || -z "${PROJECT_DIR}" || -z "${WORKTREE_DIR}" || -z "${STACK}" || -z "${RESULT_FILE}" ]]; then
  error "Missing required arguments"
  usage
  exit 2
fi

case "${STACK}" in
  python|node|go) ;;
  *)
    error "Unsupported stack '${STACK}'"
    exit 2
    ;;
esac

case "${WORKER_BACKEND}" in
  ralph-codex|codex-exec) ;;
  *)
    error "Unsupported worker backend '${WORKER_BACKEND}'"
    exit 2
    ;;
esac

mkdir -p "$(dirname "${RESULT_FILE}")"

START_TS="$(date +%s)"
SUCCESS=false
GATE_PASSED=false
REVIEW_PASSED=false
EXIT_CODE=1
ACTUAL_BACKEND="${WORKER_BACKEND}"

run_with_timeout() {
  local seconds="$1"
  shift

  if command -v timeout >/dev/null 2>&1; then
    timeout "${seconds}" "$@"
  elif command -v gtimeout >/dev/null 2>&1; then
    gtimeout "${seconds}" "$@"
  else
    "$@"
  fi
}

run_gate() {
  if bash "${REPO_ROOT}/scripts/check.sh" --stack "${STACK}" --project-dir "${WORKTREE_DIR}"; then
    GATE_PASSED=true
    return 0
  fi
  GATE_PASSED=false
  return 1
}

run_review() {
  # In local/offline contexts, a diff-based Codex review may not be available.
  # We enforce a minimal hard check: gate must pass before review can pass.
  if [[ "${GATE_PASSED}" == "true" ]]; then
    REVIEW_PASSED=true
    return 0
  fi
  REVIEW_PASSED=false
  return 1
}

run_ralph_backend() {
  local prompt_text feedback_hint
  feedback_hint=""
  if [[ -n "${INTEGRATION_FEEDBACK_FILE}" ]] && [[ -f "${INTEGRATION_FEEDBACK_FILE}" ]]; then
    feedback_hint="Integration conflict feedback is available at ${INTEGRATION_FEEDBACK_FILE}. Resolve it before completion."
  fi
  prompt_text="Execute task ${TASK_ID} using process-task contract in ${WORKTREE_DIR}. Use TDD and stop only after gate pass and review pass. ${feedback_hint}"

  if ! command -v ralph >/dev/null 2>&1; then
    return 127
  fi

  run_with_timeout "${TIMEOUT_SECONDS}" \
    ralph run \
    --backend codex \
    --no-tui \
    --autonomous \
    -c "${PROJECT_DIR}/ralph/loop-config.yaml" \
    -p "${prompt_text}" \
    -- --profile "${PROFILE}"
}

run_codex_backend() {
  local prompt_text feedback_hint
  feedback_hint=""
  if [[ -n "${INTEGRATION_FEEDBACK_FILE}" ]] && [[ -f "${INTEGRATION_FEEDBACK_FILE}" ]]; then
    feedback_hint="Integration conflict feedback is available at ${INTEGRATION_FEEDBACK_FILE}. Resolve it before completion."
  fi
  prompt_text="Execute atomic task ${TASK_ID} in ${WORKTREE_DIR} using process-task skill. Follow TDD. Run ./scripts/check.sh --stack ${STACK} and finish only when complete. ${feedback_hint}"

  if ! command -v codex >/dev/null 2>&1; then
    return 127
  fi

  run_with_timeout "${TIMEOUT_SECONDS}" \
    codex exec \
    --cd "${WORKTREE_DIR}" \
    --profile "${PROFILE}" \
    --sandbox workspace-write \
    --full-auto \
    "${prompt_text}"
}

attempt_gate_and_review() {
  if run_gate; then
    if run_review; then
      SUCCESS=true
      EXIT_CODE=0
      return 0
    fi
  fi
  SUCCESS=false
  EXIT_CODE=1
  return 1
}

if [[ -n "${ORCH_WORKER_CMD:-}" ]]; then
  ACTUAL_BACKEND="custom-command"
  if run_with_timeout "${TIMEOUT_SECONDS}" bash -lc "${ORCH_WORKER_CMD}"; then
    attempt_gate_and_review || true
  else
    EXIT_CODE=$?
    SUCCESS=false
  fi
else
  if [[ "${WORKER_BACKEND}" == "ralph-codex" ]]; then
    if run_ralph_backend; then
      ACTUAL_BACKEND="ralph-codex"
    else
      ACTUAL_BACKEND="codex-exec"
      run_codex_backend || true
    fi
  else
    ACTUAL_BACKEND="codex-exec"
    run_codex_backend || true
  fi

  attempt_gate_and_review || true
fi

if [[ "${SUCCESS}" == "true" ]]; then
  GATE_PASSED=true
  REVIEW_PASSED=true
fi

END_TS="$(date +%s)"
DURATION_SEC=$((END_TS - START_TS))

cat > "${RESULT_FILE}" <<EOF_JSON
{
  "task_id": "${TASK_ID}",
  "exit_code": ${EXIT_CODE},
  "gate_passed": $(json_bool "${GATE_PASSED}"),
  "pr_review_passed": $(json_bool "${REVIEW_PASSED}"),
  "profile": "${PROFILE}",
  "profile_fallback": $(json_bool "${PROFILE_FALLBACK}"),
  "duration_sec": ${DURATION_SEC},
  "worker_backend": "${ACTUAL_BACKEND}"
}
EOF_JSON

exit "${EXIT_CODE}"
