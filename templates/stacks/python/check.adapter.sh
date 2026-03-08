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

cd "${PROJECT_DIR}"
PROJECT_DIR="$(pwd -P)"

has_python_markers() {
  [[ -f "pyproject.toml" || -f "requirements.txt" || -f "setup.py" ]] && return 0

  local dir=""
  for dir in apps packages tests; do
    [[ -d "${dir}" ]] || continue
    if find "${dir}" -type f \( -name '*.py' -o -name 'pyproject.toml' -o -name 'requirements*.txt' -o -name 'setup.py' \) -print -quit | grep -q .; then
      return 0
    fi
  done

  return 1
}

collect_python_dirs() {
  local dir=""
  for dir in apps packages tests; do
    [[ -d "${dir}" ]] || continue
    if find "${dir}" -type f -name '*.py' -print -quit | grep -q .; then
      printf '%s\n' "${dir}"
    fi
  done
}

collect_test_targets() {
  local dir=""
  for dir in apps packages tests; do
    [[ -d "${dir}" ]] || continue
    printf '%s\n' "${dir}"
  done
}

collect_python_test_files() {
  local dir=""
  for dir in apps packages tests; do
    [[ -d "${dir}" ]] || continue
    find "${dir}" -type f \( -name 'test*.py' -o -name '*_test.py' \)
  done | sort
}

collect_unittest_specs() {
  local dir=""
  local pattern=""

  for pattern in 'test*.py' '*_test.py'; do
    for dir in apps packages tests; do
      [[ -d "${dir}" ]] || continue
      find "${dir}" -type f -name "${pattern}" -exec dirname {} \;
    done | sort -u | while IFS= read -r test_dir; do
      [[ -n "${test_dir}" ]] && printf '%s\t%s\n' "${pattern}" "${test_dir}"
    done
  done
}

if ! has_python_markers; then
  echo "[python-check] INFO: no Python product markers found under root/apps/packages/tests; skipping"
  exit 0
fi

if command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN="python3"
elif command -v python >/dev/null 2>&1; then
  PYTHON_BIN="python"
else
  echo "[python-check] ERROR: python interpreter not found" >&2
  exit 2
fi

FAILED=0
declare -a CODE_DIRS=()
declare -a TEST_TARGETS=()
declare -a PYTHON_TEST_FILES=()
declare -a UNITTEST_SPECS=()
declare -a CHANGED_FILES=()

while IFS= read -r dir; do
  [[ -n "${dir}" ]] && CODE_DIRS+=("${dir}")
done < <(collect_python_dirs)

while IFS= read -r dir; do
  [[ -n "${dir}" ]] && TEST_TARGETS+=("${dir}")
done < <(collect_test_targets)

while IFS= read -r file; do
  [[ -n "${file}" ]] && PYTHON_TEST_FILES+=("${file}")
done < <(collect_python_test_files)

while IFS=$'\t' read -r pattern test_dir; do
  [[ -n "${pattern}" && -n "${test_dir}" ]] && UNITTEST_SPECS+=("${pattern}:${test_dir}")
done < <(collect_unittest_specs)

if [[ "${CHANGED_ONLY}" -eq 1 ]] && command -v git >/dev/null 2>&1; then
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    while IFS= read -r file; do
      [[ -n "${file}" ]] || continue
      [[ -f "${file}" ]] || continue
      CHANGED_FILES+=("${file}")
    done < <({
      git diff --name-only --relative --diff-filter=ACMRTUXBD
      git diff --cached --name-only --relative --diff-filter=ACMRTUXBD
      git ls-files --others --exclude-standard
      git diff -M --name-status --diff-filter=R | awk -F'\t' 'NF >= 3 { print $2; print $3 }'
      git diff --cached -M --name-status --diff-filter=R | awk -F'\t' 'NF >= 3 { print $2; print $3 }'
    } | sed '/^$/d' | grep -E '^(apps|packages|tests)/.+\.py$' | sort -u)
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
  if [[ "${CHANGED_ONLY}" -eq 1 && "${#CHANGED_FILES[@]}" -gt 0 ]]; then
    run_step "ruff check (changed files)" ruff check "${CHANGED_FILES[@]}"
    run_step "ruff format --check (changed files)" ruff format --check "${CHANGED_FILES[@]}"
  elif [[ "${#CODE_DIRS[@]}" -gt 0 ]]; then
    run_step "ruff check" ruff check "${CODE_DIRS[@]}"
    run_step "ruff format --check" ruff format --check "${CODE_DIRS[@]}"
  else
    echo "[python-check] INFO: no Python source files under apps/packages/tests; skipping ruff"
  fi
else
  echo "[python-check] INFO: ruff not found; skipping lint/format checks"
fi

if [[ "${#CODE_DIRS[@]}" -gt 0 ]]; then
  run_step "python compileall" "${PYTHON_BIN}" -m compileall -q "${CODE_DIRS[@]}"
else
  echo "[python-check] INFO: no Python source directories found; skipping compileall"
fi

if [[ "${#PYTHON_TEST_FILES[@]}" -gt 0 ]]; then
  if command -v pytest >/dev/null 2>&1; then
    run_step "pytest" pytest -q "${TEST_TARGETS[@]}"
  elif [[ "${#UNITTEST_SPECS[@]}" -gt 0 ]]; then
    for spec in "${UNITTEST_SPECS[@]}"; do
      pattern="${spec%%:*}"
      test_dir="${spec#*:}"
      run_step "unittest discovery (${test_dir}, ${pattern})" "${PYTHON_BIN}" -m unittest discover -s "${test_dir}" -p "${pattern}" -v
    done
  else
    echo "[python-check] INFO: Python tests were found but no runnable unittest discovery targets were derived; skipping test execution"
  fi
else
  echo "[python-check] INFO: no Python tests found; skipping test execution"
fi

if [[ "${FAILED}" -eq 0 ]]; then
  exit 0
fi

exit 1
