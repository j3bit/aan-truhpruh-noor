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
      [[ $# -ge 2 ]] || { echo "[node-check] ERROR: --project-dir requires a value" >&2; exit 2; }
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
      echo "[node-check] ERROR: Unknown argument $1" >&2
      usage
      exit 2
      ;;
  esac
done

cd "${PROJECT_DIR}"

if [[ ! -f package.json ]]; then
  echo "[node-check] ERROR: package.json not found in ${PROJECT_DIR}" >&2
  exit 2
fi

if ! command -v node >/dev/null 2>&1; then
  echo "[node-check] ERROR: node not found" >&2
  exit 2
fi

PM=""
if [[ -f pnpm-lock.yaml ]] && command -v pnpm >/dev/null 2>&1; then
  PM="pnpm"
elif [[ -f yarn.lock ]] && command -v yarn >/dev/null 2>&1; then
  PM="yarn"
elif command -v npm >/dev/null 2>&1; then
  PM="npm"
else
  echo "[node-check] ERROR: no package manager found (pnpm/yarn/npm)" >&2
  exit 2
fi

if [[ "${CHANGED_ONLY}" -eq 1 ]]; then
  echo "[node-check] INFO: --changed-only currently runs full script-level checks"
fi

FAILED=0
RAN_ANY=0

run_step() {
  local name="$1"
  shift
  RAN_ANY=1
  echo "[node-check] RUN: ${name}"
  if "$@"; then
    echo "[node-check] OK: ${name}"
  else
    echo "[node-check] FAIL: ${name}" >&2
    FAILED=1
  fi
}

has_script() {
  local script_name="$1"
  node -e "const fs=require('node:fs');const pkg=JSON.parse(fs.readFileSync('package.json','utf8'));process.exit(pkg.scripts && Object.prototype.hasOwnProperty.call(pkg.scripts, process.argv[1]) ? 0 : 1)" "$script_name"
}

run_pkg_script() {
  local script_name="$1"
  case "${PM}" in
    pnpm)
      pnpm run "$script_name"
      ;;
    yarn)
      yarn run "$script_name"
      ;;
    npm)
      npm run --silent "$script_name"
      ;;
    *)
      return 2
      ;;
  esac
}

if has_script lint; then
  run_step "package script: lint" run_pkg_script lint
fi
if has_script typecheck; then
  run_step "package script: typecheck" run_pkg_script typecheck
fi
if has_script test; then
  run_step "package script: test" run_pkg_script test
fi

if [[ "${RAN_ANY}" -eq 0 ]]; then
  declare -a JS_FILES=()
  while IFS= read -r file; do
    [[ -n "${file}" ]] && JS_FILES+=("${file}")
  done < <(find . -type f \( -name '*.js' -o -name '*.mjs' -o -name '*.cjs' \) -not -path './node_modules/*' | sort)

  if [[ "${#JS_FILES[@]}" -eq 0 ]]; then
    echo "[node-check] ERROR: no scripts configured and no JS files found" >&2
    exit 2
  fi

  run_step "node syntax check" node --check "${JS_FILES[@]}"

  declare -a TEST_FILES=()
  while IFS= read -r file; do
    [[ -n "${file}" ]] && TEST_FILES+=("${file}")
  done < <(find . -type f -name '*.test.js' -not -path './node_modules/*' | sort)
  if [[ "${#TEST_FILES[@]}" -gt 0 ]]; then
    run_step "node test runner" node --test "${TEST_FILES[@]}"
  else
    echo "[node-check] INFO: no *.test.js files found; test run skipped"
  fi
fi

if [[ "${FAILED}" -eq 0 ]]; then
  exit 0
fi

exit 1
