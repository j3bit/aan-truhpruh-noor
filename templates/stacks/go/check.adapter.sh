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

collect_go_files() {
  local dir=""
  for dir in apps packages tests; do
    [[ -d "${dir}" ]] || continue
    find "${dir}" -type f -name '*.go' -not -path '*/vendor/*'
  done | sort
}

has_go_markers() {
  local dir=""

  if [[ -f go.mod || -f go.work ]]; then
    return 0
  fi

  for dir in apps packages tests; do
    [[ -d "${dir}" ]] || continue
    if find "${dir}" -type f \( -name '*.go' -o -name 'go.mod' \) -print -quit | grep -q .; then
      return 0
    fi
  done

  return 1
}

collect_go_modules() {
  local dir=""

  if [[ -f go.work ]]; then
    go work edit -json | perl -MJSON::PP -e '
      use strict;
      use warnings;

      local $/;
      my $obj = decode_json(<>);
      for my $entry (@{$obj->{Use} // []}) {
        next unless ref($entry) eq "HASH";
        my $path = $entry->{DiskPath};
        next unless defined $path && !ref($path) && $path ne "";
        print $path, "\n";
      }
    ' | sed 's#/$##' | sed '/^$/d' | sort -u
    return 0
  fi

  if [[ -f go.mod ]]; then
    printf '.\n'
    return 0
  fi

  for dir in apps packages tests; do
    [[ -d "${dir}" ]] || continue
    find "${dir}" -type f -name 'go.mod' -exec dirname {} \;
  done | sort -u
}

declare -a GO_FILES=()

while IFS= read -r file; do
  [[ -n "${file}" ]] && GO_FILES+=("${file}")
done < <(collect_go_files)

if ! has_go_markers; then
  echo "[go-check] INFO: no Go product markers found under root/apps/packages/tests; skipping"
  exit 0
fi

if ! command -v go >/dev/null 2>&1; then
  echo "[go-check] ERROR: go is not installed" >&2
  exit 2
fi

declare -a MODULE_DIRS=()
while IFS= read -r dir; do
  [[ -n "${dir}" ]] && MODULE_DIRS+=("${dir}")
done < <(collect_go_modules)

if [[ "${#MODULE_DIRS[@]}" -eq 0 && "${#GO_FILES[@]}" -gt 0 ]]; then
  echo "[go-check] ERROR: Go files found but no go.mod/go.work was found under root/apps/packages/tests" >&2
  exit 2
fi

export GOPATH="${PROJECT_DIR}/.cache/go"
export GOMODCACHE="${GOPATH}/pkg/mod"
export GOCACHE="${PROJECT_DIR}/.cache/go-build"
mkdir -p "${GOMODCACHE}" "${GOCACHE}"

if [[ "${CHANGED_ONLY}" -eq 1 ]]; then
  echo "[go-check] INFO: --changed-only currently runs full module checks because Go dependencies can span packages"
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

run_module_checks() {
  local module_dir="$1"
  local module_go_files=()
  local file=""

  while IFS= read -r file; do
    [[ -n "${file}" ]] && module_go_files+=("${file}")
  done < <(cd "${module_dir}" && find . -type f -name '*.go' -not -path './vendor/*' | sort)

  if [[ "${#module_go_files[@]}" -eq 0 ]]; then
    echo "[go-check] INFO: no .go files found in ${module_dir}; skipping"
    return 0
  fi

  echo "[go-check] RUN: gofmt -l (${module_dir})"
  local unformatted=""
  unformatted="$(cd "${module_dir}" && gofmt -l "${module_go_files[@]}")"
  if [[ -n "${unformatted}" ]]; then
    echo "[go-check] FAIL: gofmt detected unformatted files in ${module_dir}:" >&2
    echo "${unformatted}" >&2
    FAILED=1
  else
    echo "[go-check] OK: gofmt (${module_dir})"
  fi

  run_step "go test ./... (${module_dir})" bash -lc "cd \"${module_dir}\" && go test ./..."
  run_step "go vet ./... (${module_dir})" bash -lc "cd \"${module_dir}\" && go vet ./..."
}

for module_dir in "${MODULE_DIRS[@]}"; do
  run_module_checks "${module_dir}"
done

if [[ "${FAILED}" -eq 0 ]]; then
  exit 0
fi

exit 1
