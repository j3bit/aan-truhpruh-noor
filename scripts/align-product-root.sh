#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${PWD}"
STACKS_RAW="auto"
APP_NAME=""
FORCE=0

if [[ ! -f "${SCRIPT_DIR}/lib/product-root-layout.sh" ]]; then
  echo "[align-product-root] ERROR: missing layout helper: ${SCRIPT_DIR}/lib/product-root-layout.sh" >&2
  exit 2
fi

if [[ ! -f "${SCRIPT_DIR}/lib/stack-registry.sh" ]]; then
  echo "[align-product-root] ERROR: missing stack registry helper: ${SCRIPT_DIR}/lib/stack-registry.sh" >&2
  exit 2
fi

# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/product-root-layout.sh"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/stack-registry.sh"

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/align-product-root.sh [--project-dir <path>] [--stacks <csv|auto>] [--app <name>] [--force]

Description:
  Aligns a repository to the product-root-first layout.
  - Ensures scaffold directories exist
  - Rewrites tasks/stacks.json so every stack project path is `.`
  - Optionally creates a starter app directory under apps/
USAGE
}

error() {
  echo "[align-product-root] ERROR: $*" >&2
}

info() {
  echo "[align-product-root] $*"
}

normalize_stacks() {
  local raw="$1"
  printf '%s\n' "${raw}" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed '/^$/d' | awk '!seen[$0]++'
}

discover_stacks_auto() {
  local project_dir="$1"
  local registry_abs="${project_dir}/tasks/stacks.json"
  local stack=""

  if [[ -f "${registry_abs}" ]]; then
    while IFS= read -r stack; do
      [[ -n "${stack}" ]] && printf '%s\n' "${stack}"
    done < <(stack_registry_list_names "${registry_abs}")
    return 0
  fi

  while IFS= read -r stack; do
    [[ -n "${stack}" ]] || continue
    printf '%s\n' "${stack}"
  done < <(find "${project_dir}/templates/stacks" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort)
}

write_app_readme() {
  local project_dir="$1"
  local app_name="$2"
  local readme_path="${project_dir}/apps/${app_name}/README.md"

  if [[ -f "${readme_path}" && "${FORCE}" -eq 0 ]]; then
    return 0
  fi

  mkdir -p "$(dirname "${readme_path}")"
  cat > "${readme_path}" <<EOF_APP
# ${app_name}

Product code for \`${app_name}\` starts here.
EOF_APP
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-dir)
      [[ $# -ge 2 ]] || { error "--project-dir requires a value"; usage; exit 2; }
      PROJECT_DIR="$2"
      shift 2
      ;;
    --stacks)
      [[ $# -ge 2 ]] || { error "--stacks requires a value"; usage; exit 2; }
      STACKS_RAW="$2"
      shift 2
      ;;
    --app)
      [[ $# -ge 2 ]] || { error "--app requires a value"; usage; exit 2; }
      APP_NAME="$2"
      shift 2
      ;;
    --force)
      FORCE=1
      shift
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

if [[ ! -d "${PROJECT_DIR}" ]]; then
  error "Project directory does not exist: ${PROJECT_DIR}"
  exit 2
fi

PROJECT_DIR="$(cd "${PROJECT_DIR}" && pwd -P)"

STACKS=()
if [[ "${STACKS_RAW}" == "auto" ]]; then
  while IFS= read -r stack; do
    [[ -n "${stack}" ]] && STACKS+=("${stack}")
  done < <(discover_stacks_auto "${PROJECT_DIR}")
else
  while IFS= read -r stack; do
    [[ -n "${stack}" ]] && STACKS+=("${stack}")
  done < <(normalize_stacks "${STACKS_RAW}")
fi

if [[ "${#STACKS[@]}" -eq 0 ]]; then
  error "No stacks resolved. Pass --stacks <csv> or ensure tasks/stacks.json exists."
  exit 2
fi

product_root_ensure_scaffold "${PROJECT_DIR}"
product_root_write_stack_registry "${PROJECT_DIR}" "${STACKS[@]}"

if [[ -n "${APP_NAME}" ]]; then
  write_app_readme "${PROJECT_DIR}" "${APP_NAME}"
fi

info "Aligned ${PROJECT_DIR} to the product-root-first layout"
info "Stacks: $(IFS=,; echo "${STACKS[*]}")"
if [[ -n "${APP_NAME}" ]]; then
  info "App scaffold: apps/${APP_NAME}"
fi
