#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="${PWD}"
CHANGED_ONLY=0

usage() {
  cat <<'USAGE'
Usage:
  check.adapter.sh --project-dir <path> [--changed-only]
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-dir)
      [[ $# -ge 2 ]] || { echo "[go-check] ERROR: --project-dir requires a value" >&2; exit 2; }
      PROJECT_DIR="$2"
      shift 2
      ;;
    --changed-only)
      CHANGED_ONLY=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[go-check] ERROR: Unknown argument $1" >&2
      usage
      exit 2
      ;;
  esac
done

if [[ ! -d "${PROJECT_DIR}" ]]; then
  echo "[go-check] ERROR: project directory does not exist: ${PROJECT_DIR}" >&2
  exit 2
fi

cd -- "${PROJECT_DIR}"
PROJECT_DIR="$(pwd -P)"

if ! command -v go >/dev/null 2>&1; then
  echo "[go-check] ERROR: go is not installed" >&2
  exit 2
fi

if [[ ! -f go.mod ]]; then
  echo "[go-check] ERROR: go.mod not found in ${PROJECT_DIR}" >&2
  exit 2
fi

# Use project-local caches so checks work in sandboxed environments.
export GOPATH="${PROJECT_DIR}/.cache/go"
export GOMODCACHE="${GOPATH}/pkg/mod"
export GOCACHE="${PROJECT_DIR}/.cache/go-build"
mkdir -p "${GOMODCACHE}" "${GOCACHE}"

if [[ "${CHANGED_ONLY}" -eq 1 ]]; then
  echo "[go-check] INFO: --changed-only currently runs full checks because package dependencies can span modules"
fi

declare -a GO_FILES=()
while IFS= read -r file; do
  [[ -n "${file}" ]] && GO_FILES+=("${file}")
done < <(find . -type f -name '*.go' -not -path './vendor/*' | sort)
if [[ "${#GO_FILES[@]}" -eq 0 ]]; then
  echo "[go-check] ERROR: no .go files found" >&2
  exit 2
fi

FAILED=0

run_step() {
  local name="$1"
  shift
  echo "[go-check] RUN: ${name}"
  if "$@"; then
    echo "[go-check] OK: ${name}"
  else
    echo "[go-check] FAIL: ${name}" >&2
    FAILED=1
  fi
}

echo "[go-check] RUN: gofmt -l"
UNFORMATTED="$(gofmt -l "${GO_FILES[@]}")"
if [[ -n "${UNFORMATTED}" ]]; then
  echo "[go-check] FAIL: gofmt detected unformatted files:" >&2
  echo "${UNFORMATTED}" >&2
  FAILED=1
else
  echo "[go-check] OK: gofmt"
fi

run_step "go test ./..." go test ./...
run_step "go vet ./..." go vet ./...

if [[ "${FAILED}" -eq 0 ]]; then
  exit 0
fi

exit 1
