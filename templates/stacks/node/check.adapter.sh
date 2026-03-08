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
PROJECT_DIR="$(pwd -P)"

collect_nested_package_dirs() {
  local dir=""
  for dir in apps packages tests; do
    [[ -d "${dir}" ]] || continue
    find "${dir}" -type f -name 'package.json' -not -path '*/node_modules/*' -exec dirname {} \;
  done | sort -u
}

collect_product_js_files() {
  local dir=""
  for dir in apps packages tests; do
    [[ -d "${dir}" ]] || continue
    find "${dir}" -type f \( -name '*.js' -o -name '*.jsx' -o -name '*.mjs' -o -name '*.cjs' \) -not -path '*/node_modules/*'
  done | sort
}

collect_product_test_files() {
  local dir=""
  for dir in apps packages tests; do
    [[ -d "${dir}" ]] || continue
    find "${dir}" -type f \( -name '*.test.js' -o -name '*.test.mjs' -o -name '*.test.cjs' \) -not -path '*/node_modules/*'
  done | sort
}

HAS_ROOT_PACKAGE=0
[[ -f package.json ]] && HAS_ROOT_PACKAGE=1

declare -a PACKAGE_DIRS=()
declare -a JS_FILES=()
declare -a TEST_FILES=()

if [[ "${HAS_ROOT_PACKAGE}" -eq 1 ]]; then
  PACKAGE_DIRS=(".")
fi

while IFS= read -r dir; do
  [[ -n "${dir}" ]] && PACKAGE_DIRS+=("${dir}")
done < <(collect_nested_package_dirs)

while IFS= read -r file; do
  [[ -n "${file}" ]] && JS_FILES+=("${file}")
done < <(collect_product_js_files)

while IFS= read -r file; do
  [[ -n "${file}" ]] && TEST_FILES+=("${file}")
done < <(collect_product_test_files)

if [[ "${#PACKAGE_DIRS[@]}" -eq 0 && "${#JS_FILES[@]}" -eq 0 ]]; then
  echo "[node-check] INFO: no Node product markers found under root/apps/packages/tests; skipping"
  exit 0
fi

if ! command -v node >/dev/null 2>&1; then
  echo "[node-check] ERROR: node not found" >&2
  exit 2
fi

FAILED=0

run_step() {
  local name="$1"
  shift
  echo "[node-check] RUN: ${name}"
  if "$@"; then
    echo "[node-check] OK: ${name}"
  else
    echo "[node-check] FAIL: ${name}" >&2
    FAILED=1
  fi
}

run_pkg_script() {
  local package_dir="$1"
  local script_name="$2"
  local pm=""

  if [[ -f "${package_dir}/pnpm-lock.yaml" ]] && command -v pnpm >/dev/null 2>&1; then
    pm="pnpm"
  elif [[ -f "${package_dir}/yarn.lock" ]] && command -v yarn >/dev/null 2>&1; then
    pm="yarn"
  elif command -v npm >/dev/null 2>&1; then
    pm="npm"
  else
    echo "[node-check] ERROR: no package manager found for ${package_dir}" >&2
    return 2
  fi

  case "${pm}" in
    pnpm)
      (cd "${package_dir}" && pnpm run "${script_name}")
      ;;
    yarn)
      (cd "${package_dir}" && yarn run "${script_name}")
      ;;
    npm)
      (cd "${package_dir}" && npm run --silent "${script_name}")
      ;;
  esac
}

package_has_script() {
  local package_dir="$1"
  local script_name="$2"

  (cd "${package_dir}" && node -e "const fs=require('node:fs');const pkg=JSON.parse(fs.readFileSync('package.json','utf8'));process.exit(pkg.scripts && Object.prototype.hasOwnProperty.call(pkg.scripts, process.argv[1]) ? 0 : 1)" "${script_name}")
}

run_package_checks() {
  local package_dir="$1"
  local ran_any=0
  local pkg_js_files=()
  local pkg_test_files=()
  local file=""

  if package_has_script "${package_dir}" lint; then
    run_step "package script: lint (${package_dir})" run_pkg_script "${package_dir}" lint
    ran_any=1
  fi
  if package_has_script "${package_dir}" typecheck; then
    run_step "package script: typecheck (${package_dir})" run_pkg_script "${package_dir}" typecheck
    ran_any=1
  fi
  if package_has_script "${package_dir}" test; then
    run_step "package script: test (${package_dir})" run_pkg_script "${package_dir}" test
    ran_any=1
  fi

  if [[ "${ran_any}" -eq 1 ]]; then
    return 0
  fi

  while IFS= read -r file; do
    [[ -n "${file}" ]] && pkg_js_files+=("${file}")
  done < <(find "${package_dir}" -type f \( -name '*.js' -o -name '*.jsx' -o -name '*.mjs' -o -name '*.cjs' \) -not -path '*/node_modules/*' | sort)

  if [[ "${#pkg_js_files[@]}" -gt 0 ]]; then
    run_step "node syntax check (${package_dir})" node --check "${pkg_js_files[@]}"
  else
    echo "[node-check] INFO: no runnable JS files in ${package_dir}; skipping syntax check"
  fi

  while IFS= read -r file; do
    [[ -n "${file}" ]] && pkg_test_files+=("${file}")
  done < <(find "${package_dir}" -type f \( -name '*.test.js' -o -name '*.test.mjs' -o -name '*.test.cjs' \) -not -path '*/node_modules/*' | sort)

  if [[ "${#pkg_test_files[@]}" -gt 0 ]]; then
    run_step "node test runner (${package_dir})" node --test "${pkg_test_files[@]}"
  else
    echo "[node-check] INFO: no Node test files found in ${package_dir}; skipping tests"
  fi
}

if [[ "${CHANGED_ONLY}" -eq 1 ]]; then
  echo "[node-check] INFO: --changed-only currently runs full product-scope checks"
fi

if [[ "${#PACKAGE_DIRS[@]}" -gt 0 ]]; then
  for package_dir in "${PACKAGE_DIRS[@]}"; do
    run_package_checks "${package_dir}"
  done
elif [[ "${#JS_FILES[@]}" -gt 0 ]]; then
  run_step "node syntax check" node --check "${JS_FILES[@]}"

  if [[ "${#TEST_FILES[@]}" -gt 0 ]]; then
    run_step "node test runner" node --test "${TEST_FILES[@]}"
  else
    echo "[node-check] INFO: no Node test files found; skipping tests"
  fi
else
  echo "[node-check] INFO: only TypeScript files without package manifests were found; skipping runtime checks"
fi

if [[ "${FAILED}" -eq 0 ]]; then
  exit 0
fi

exit 1
