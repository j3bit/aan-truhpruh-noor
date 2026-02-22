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

Notes:
  --project-dir lets you run checks for a target project path.
  Example (from template root):
    ./scripts/check.sh --stack python --project-dir ./examples/python-hello

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

# Normalize to an absolute path so stack adapters receive stable paths.
PROJECT_DIR="$(cd -- "${PROJECT_DIR}" && pwd -P)"

ADAPTER="${REPO_ROOT}/templates/stacks/${STACK}/check.adapter.sh"
if [[ ! -f "${ADAPTER}" ]]; then
  error "Adapter not found: ${ADAPTER}"
  exit 2
fi

CONTRACT_VALIDATOR="${REPO_ROOT}/scripts/validate-contracts.sh"
if [[ ! -f "${CONTRACT_VALIDATOR}" ]]; then
  error "Contract validator not found: ${CONTRACT_VALIDATOR}"
  exit 2
fi

ARGS=(--project-dir "${PROJECT_DIR}")
if [[ "${CHANGED_ONLY}" -eq 1 ]]; then
  ARGS+=(--changed-only)
fi

echo "[check] stack=${STACK} project_dir=${PROJECT_DIR} changed_only=${CHANGED_ONLY}"

set +e
echo "[check] RUN: contract preflight"
bash "${CONTRACT_VALIDATOR}" "${ARGS[@]}"
CONTRACT_RESULT=$?
if [[ "${CONTRACT_RESULT}" -ne 0 ]]; then
  if [[ "${CONTRACT_RESULT}" -eq 1 ]]; then
    echo "[check] FAIL"
    set -e
    exit 1
  fi
  echo "[check] ERROR"
  set -e
  exit 2
fi

echo "[check] RUN: stack adapter"
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
