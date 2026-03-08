#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

PROJECT_NAME=""
STACKS_RAW=""
DEST=""
FORCE=0

if [[ ! -f "${SCRIPT_DIR}/lib/product-root-layout.sh" ]]; then
  echo "[bootstrap] ERROR: missing layout helper: ${SCRIPT_DIR}/lib/product-root-layout.sh" >&2
  exit 2
fi

# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/product-root-layout.sh"

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/bootstrap-new-project.sh --name <project-name> --stacks <comma-separated-stack-list> [--dest <path>] [--force]

Description:
  Creates a new project from this bootstrap template.

Options:
  --name    Project name to inject into template placeholders.
  --stacks  Comma-separated stack list (e.g. python,node,go).
  --dest    Destination directory path (default: <cwd>/<project-name>).
  --force   Allow using an existing destination directory.
USAGE
}

error() {
  echo "[bootstrap] ERROR: $*" >&2
}

normalize_stacks() {
  local raw="$1"
  printf '%s\n' "${raw}" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed '/^$/d' | awk '!seen[$0]++'
}

ensure_adapter_for_stack() {
  local stack="$1"
  local adapter_abs="${DEST}/templates/stacks/${stack}/check.adapter.sh"

  if [[ -f "${adapter_abs}" ]]; then
    return 0
  fi

  mkdir -p "$(dirname "${adapter_abs}")"
  cat > "${adapter_abs}" <<EOF_ADAPTER
#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="\${PWD}"

while [[ \$# -gt 0 ]]; do
  case "\$1" in
    --project-dir)
      [[ \$# -ge 2 ]] || { echo "[${stack}-check] ERROR: --project-dir requires a value" >&2; exit 2; }
      PROJECT_DIR="\$2"
      shift 2
      ;;
    --changed-only)
      shift
      ;;
    -h|--help)
      echo "Usage: check.adapter.sh --project-dir <path> [--changed-only]"
      exit 0
      ;;
    *)
      echo "[${stack}-check] ERROR: Unknown argument \$1" >&2
      exit 2
      ;;
  esac
done

if [[ ! -d "\${PROJECT_DIR}" ]]; then
  echo "[${stack}-check] ERROR: project directory does not exist: \${PROJECT_DIR}" >&2
  exit 2
fi

echo "[${stack}-check] INFO: placeholder adapter for stack '${stack}' (no checks configured yet)."
exit 0
EOF_ADAPTER
  chmod +x "${adapter_abs}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)
      [[ $# -ge 2 ]] || { error "--name requires a value"; usage; exit 2; }
      PROJECT_NAME="$2"
      shift 2
      ;;
    --stacks)
      [[ $# -ge 2 ]] || { error "--stacks requires a value"; usage; exit 2; }
      STACKS_RAW="$2"
      shift 2
      ;;
    --stack)
      error "--stack is removed. Use --stacks <comma-separated-stack-list>."
      exit 2
      ;;
    --dest)
      [[ $# -ge 2 ]] || { error "--dest requires a value"; usage; exit 2; }
      DEST="$2"
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

if [[ -z "${PROJECT_NAME}" ]]; then
  error "--name is required"
  usage
  exit 2
fi

if [[ -z "${STACKS_RAW}" ]]; then
  error "--stacks is required"
  usage
  exit 2
fi

STACKS=()
while IFS= read -r stack_name; do
  [[ -n "${stack_name}" ]] && STACKS+=("${stack_name}")
done < <(normalize_stacks "${STACKS_RAW}")

if [[ "${#STACKS[@]}" -eq 0 ]]; then
  error "No valid stacks were provided"
  exit 2
fi

for stack in "${STACKS[@]}"; do
  if [[ ! "${stack}" =~ ^[a-z0-9][a-z0-9_-]*$ ]]; then
    error "Invalid stack name '${stack}'. Use lowercase alphanumeric, underscore, hyphen"
    exit 2
  fi
done

if [[ -z "${DEST}" ]]; then
  DEST="$(pwd)/${PROJECT_NAME}"
fi

if [[ -e "${DEST}" && "${FORCE}" -eq 0 ]]; then
  error "Destination already exists. Use --force to allow existing destination: ${DEST}"
  exit 2
fi

mkdir -p "${DEST}"

copy_item() {
  local source_rel="$1"
  local source_abs="${TEMPLATE_ROOT}/${source_rel}"
  local dest_abs="${DEST}/${source_rel}"

  if [[ ! -e "${source_abs}" ]]; then
    error "Missing template item: ${source_rel}"
    exit 2
  fi

  if [[ -d "${source_abs}" ]]; then
    mkdir -p "${dest_abs}"
    cp -R "${source_abs}/." "${dest_abs}"
  else
    mkdir -p "$(dirname "${dest_abs}")"
    cp "${source_abs}" "${dest_abs}"
  fi
}

prune_transient_artifacts() {
  local target_root="$1"

  while IFS= read -r -d '' cache_dir; do
    rm -rf "${cache_dir}"
  done < <(find "${target_root}" -type d \( -name '__pycache__' -o -name '.cache' \) -print0)

  find "${target_root}" -type f \( -name '*.pyc' -o -name '*.pyo' \) -delete

  if [[ -d "${target_root}/evals/results" ]]; then
    find "${target_root}/evals/results" -type f -name '*.jsonl' -delete
  fi
}

copy_item AGENTS.md
copy_item .gitignore
copy_item apps
copy_item packages
copy_item tests
copy_item infra
copy_item tasks
copy_item scripts
copy_item templates
copy_item ralph
copy_item .github
copy_item evals
copy_item docs
copy_item .agents
copy_item .codex
copy_item README.md

for stack in "${STACKS[@]}"; do
  ensure_adapter_for_stack "${stack}"
done

product_root_ensure_scaffold "${DEST}"

SAFE_PROJECT_NAME="$(printf '%s' "${PROJECT_NAME}" | sed 's/[&/]/\\&/g')"

while IFS= read -r -d '' file; do
  sed -i.bak "s/__PROJECT_NAME__/${SAFE_PROJECT_NAME}/g" "${file}" && rm -f "${file}.bak"
done < <(find "${DEST}" -type f \( -name '*.md' -o -name '*.sh' -o -name '*.yml' -o -name '*.yaml' -o -name '*.toml' -o -name '*.txt' \) -print0)

product_root_write_stack_registry "${DEST}" "${STACKS[@]}"

while IFS= read -r -d '' file; do
  chmod +x "${file}"
done < <(find "${DEST}" -type f -name '*.sh' -print0)

prune_transient_artifacts "${DEST}"

echo "[bootstrap] Project created at ${DEST}"
echo "[bootstrap] Selected stacks: $(IFS=,; echo "${STACKS[*]}")"
echo "[bootstrap] Root product layout enabled"
echo "[bootstrap] Suggested next steps:"
echo "  1) cd ${DEST}"
echo "  2) ./scripts/check.sh --stacks auto"
