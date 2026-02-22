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
      [[ $# -ge 2 ]] || { echo "[python-check] ERROR: --project-dir requires a value" >&2; exit 2; }
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
      echo "[python-check] ERROR: Unknown argument $1" >&2
      usage
      exit 2
      ;;
  esac
done

if ! command -v python3 >/dev/null 2>&1 && ! command -v python >/dev/null 2>&1; then
  echo "[python-check] ERROR: python interpreter not found" >&2
  exit 2
fi

if command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN="python3"
else
  PYTHON_BIN="python"
fi

cd "${PROJECT_DIR}"

if [[ ! -f "pyproject.toml" && ! -f "requirements.txt" ]] && ! find . -type f -name '*.py' -not -path './.git/*' -print -quit | grep -q .; then
  echo "[python-check] ERROR: no Python project markers found in ${PROJECT_DIR}" >&2
  exit 2
fi

FAILED=0

declare -a CHANGED_FILES=()
if [[ "${CHANGED_ONLY}" -eq 1 ]] && command -v git >/dev/null 2>&1; then
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    while IFS= read -r file; do
      [[ -n "${file}" ]] && CHANGED_FILES+=("${file}")
    done < <(git diff --name-only --diff-filter=ACMRTUXB -- '*.py' 2>/dev/null || true)
  fi
fi

run_step() {
  local name="$1"
  shift
  echo "[python-check] RUN: ${name}"
  if "$@"; then
    echo "[python-check] OK: ${name}"
  else
    echo "[python-check] FAIL: ${name}" >&2
    FAILED=1
  fi
}

if command -v ruff >/dev/null 2>&1; then
  if [[ "${CHANGED_ONLY}" -eq 1 ]] && [[ "${#CHANGED_FILES[@]}" -gt 0 ]]; then
    run_step "ruff check (changed files)" ruff check "${CHANGED_FILES[@]}"
    run_step "ruff format --check (changed files)" ruff format --check "${CHANGED_FILES[@]}"
  else
    run_step "ruff check" ruff check .
    run_step "ruff format --check" ruff format --check .
  fi
else
  echo "[python-check] INFO: ruff not found; skipping lint/format checks"
fi

run_step "python compileall" "${PYTHON_BIN}" -m compileall -q .

HAS_TESTS=0
if find . -type f \( -name 'test_*.py' -o -name '*_test.py' \) -not -path './.git/*' -print -quit | grep -q .; then
  HAS_TESTS=1
fi

if [[ "${HAS_TESTS}" -eq 1 ]] && command -v pytest >/dev/null 2>&1; then
  run_step "pytest" pytest -q
else
  run_step "unittest discovery" "${PYTHON_BIN}" -m unittest discover -v
fi

if [[ "${FAILED}" -eq 0 ]]; then
  exit 0
fi

exit 1
