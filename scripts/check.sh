#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

STACK=""
CHANGED_ONLY=0
PROJECT_DIR="${PWD}"

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/check.sh --stack <python|node|go> [--changed-only] [--project-dir <path>]

Exit Codes:
  0: all checks passed
  1: one or more checks failed
  2: configuration or input error
USAGE
}

error() {
  echo "[check] ERROR: $*" >&2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --stack)
      [[ $# -ge 2 ]] || { error "--stack requires a value"; usage; exit 2; }
      STACK="$2"
      shift 2
      ;;
    --changed-only)
      CHANGED_ONLY=1
      shift
      ;;
    --project-dir)
      [[ $# -ge 2 ]] || { error "--project-dir requires a value"; usage; exit 2; }
      PROJECT_DIR="$2"
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

if [[ -z "${STACK}" ]]; then
  error "--stack is required"
  usage
  exit 2
fi

case "${STACK}" in
  python|node|go)
    ;;
  *)
    error "Unsupported stack '${STACK}'. Use one of: python, node, go"
    exit 2
    ;;
esac

if [[ ! -d "${PROJECT_DIR}" ]]; then
  error "Project directory does not exist: ${PROJECT_DIR}"
  exit 2
fi

ADAPTER="${REPO_ROOT}/templates/stacks/${STACK}/check.adapter.sh"
if [[ ! -f "${ADAPTER}" ]]; then
  error "Adapter not found: ${ADAPTER}"
  exit 2
fi

ARGS=(--project-dir "${PROJECT_DIR}")
if [[ "${CHANGED_ONLY}" -eq 1 ]]; then
  ARGS+=(--changed-only)
fi

echo "[check] stack=${STACK} project_dir=${PROJECT_DIR} changed_only=${CHANGED_ONLY}"

set +e
bash "${ADAPTER}" "${ARGS[@]}"
RESULT=$?
set -e

if [[ "${RESULT}" -eq 0 ]]; then
  echo "[check] PASS"
elif [[ "${RESULT}" -eq 1 ]]; then
  echo "[check] FAIL"
else
  echo "[check] ERROR"
fi

exit "${RESULT}"
