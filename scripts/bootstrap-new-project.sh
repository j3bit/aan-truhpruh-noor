#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

PROJECT_NAME=""
STACKS_RAW=""
DEST=""
FORCE=0

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

stack_seed_example_dir() {
  local stack="$1"
  case "${stack}" in
    python) echo "examples/python-hello" ;;
    node) echo "examples/node-hello" ;;
    go) echo "examples/go-hello" ;;
    *) echo "" ;;
  esac
}

stack_default_owned_paths_json() {
  local stack="$1"
  case "${stack}" in
    python)
      cat <<'EOF_JSON'
["**/*.py", "pyproject.toml", "requirements*.txt", "setup.py"]
EOF_JSON
      ;;
    node)
      cat <<'EOF_JSON'
["**/*.js", "**/*.mjs", "**/*.cjs", "**/*.ts", "**/*.tsx", "package.json", "package-lock.json", "pnpm-lock.yaml", "yarn.lock"]
EOF_JSON
      ;;
    go)
      cat <<'EOF_JSON'
["**/*.go", "go.mod", "go.sum"]
EOF_JSON
      ;;
    *)
      cat <<'EOF_JSON'
["**/*"]
EOF_JSON
      ;;
  esac
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

if [[ -e "${DEST}" ]] && [[ "${FORCE}" -eq 0 ]]; then
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
copy_item examples

for stack in "${STACKS[@]}"; do
  ensure_adapter_for_stack "${stack}"
done

if [[ "${#STACKS[@]}" -eq 1 ]]; then
  stack="${STACKS[0]}"
  seed_dir="$(stack_seed_example_dir "${stack}")"
  if [[ -n "${seed_dir}" ]]; then
    cp -R "${TEMPLATE_ROOT}/${seed_dir}/." "${DEST}/"
  else
    echo "# ${PROJECT_NAME}" > "${DEST}/README.${stack}.md"
    echo "Starter files for stack '${stack}' are not bundled. Add your runtime files." >> "${DEST}/README.${stack}.md"
  fi
else
  for stack in "${STACKS[@]}"; do
    seed_dir="$(stack_seed_example_dir "${stack}")"
    service_dir="${DEST}/services/${stack}-hello"
    mkdir -p "${service_dir}"
    if [[ -n "${seed_dir}" ]]; then
      cp -R "${TEMPLATE_ROOT}/${seed_dir}/." "${service_dir}/"
    else
      cat > "${service_dir}/README.md" <<EOF_SERVICE
# ${stack}-hello

This service directory was created automatically for stack '${stack}'.
Add runtime/bootstrap files for this stack.
EOF_SERVICE
    fi
  done
fi

SAFE_PROJECT_NAME="$(printf '%s' "${PROJECT_NAME}" | sed 's/[&/]/\\&/g')"

while IFS= read -r -d '' file; do
  sed -i.bak "s/__PROJECT_NAME__/${SAFE_PROJECT_NAME}/g" "${file}" && rm -f "${file}.bak"
done < <(find "${DEST}" -type f \( -name '*.md' -o -name '*.sh' -o -name '*.yml' -o -name '*.yaml' -o -name '*.toml' -o -name '*.txt' \) -print0)

while IFS= read -r -d '' file; do
  chmod +x "${file}"
done < <(find "${DEST}" -type f \( -name '*.sh' \) -print0)

# Generate tasks/stacks.json for the bootstrapped project.
STACKS_JSON_PATH="${DEST}/tasks/stacks.json"
mkdir -p "$(dirname "${STACKS_JSON_PATH}")"

{
  echo '{'
  echo '  "version": 1,'
  echo '  "stacks": ['

  for idx in "${!STACKS[@]}"; do
    stack="${STACKS[$idx]}"
    if [[ "${#STACKS[@]}" -eq 1 ]]; then
      project_path='.'
    else
      project_path="services/${stack}-hello"
    fi

    adapter_path="templates/stacks/${stack}/check.adapter.sh"

    owned_paths_json="$(stack_default_owned_paths_json "${stack}")"

    echo '    {'
    echo "      \"name\": \"${stack}\"," 
    echo "      \"adapter\": \"${adapter_path}\"," 
    echo '      "projects": ['
    echo '        {'
    echo "          \"path\": \"${project_path}\"," 
    echo "          \"owned_paths\": ${owned_paths_json}"
    echo '        }'
    echo '      ]'

    if [[ "${idx}" -lt $(( ${#STACKS[@]} - 1 )) ]]; then
      echo '    },'
    else
      echo '    }'
    fi
  done

  echo '  ]'
  echo '}'
} > "${STACKS_JSON_PATH}"

prune_transient_artifacts "${DEST}"

echo "[bootstrap] Project created at ${DEST}"
echo "[bootstrap] Selected stacks: $(IFS=,; echo "${STACKS[*]}")"
echo "[bootstrap] Suggested next steps:"
echo "  1) cd ${DEST}"
echo "  2) ./scripts/smoke-test.sh"
echo "  3) ./scripts/check.sh --stacks auto"
