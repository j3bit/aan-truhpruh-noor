#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

PROJECT_NAME=""
STACK=""
DEST=""
FORCE=0

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/bootstrap-new-project.sh --name <project-name> --stack <python|node|go> [--dest <path>] [--force]

Description:
  Creates a new project from this bootstrap template.

Options:
  --name    Project name to inject into template placeholders.
  --stack   Starter stack to seed into the project root.
  --dest    Destination directory path (default: <cwd>/<project-name>).
  --force   Allow using an existing destination directory.
USAGE
}

error() {
  echo "[bootstrap] ERROR: $*" >&2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)
      [[ $# -ge 2 ]] || { error "--name requires a value"; usage; exit 2; }
      PROJECT_NAME="$2"
      shift 2
      ;;
    --stack)
      [[ $# -ge 2 ]] || { error "--stack requires a value"; usage; exit 2; }
      STACK="$2"
      shift 2
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

case "${STACK}" in
  python|node|go)
    ;;
  *)
    error "--stack must be one of: python, node, go"
    usage
    exit 2
    ;;
esac

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
copy_item README.md
copy_item examples

case "${STACK}" in
  python)
    cp -R "${TEMPLATE_ROOT}/examples/python-hello/." "${DEST}/"
    ;;
  node)
    cp -R "${TEMPLATE_ROOT}/examples/node-hello/." "${DEST}/"
    ;;
  go)
    cp -R "${TEMPLATE_ROOT}/examples/go-hello/." "${DEST}/"
    ;;
esac

SAFE_PROJECT_NAME="$(printf '%s' "${PROJECT_NAME}" | sed 's/[&/]/\\&/g')"

while IFS= read -r -d '' file; do
  sed -i.bak "s/__PROJECT_NAME__/${SAFE_PROJECT_NAME}/g" "${file}" && rm -f "${file}.bak"
done < <(find "${DEST}" -type f \( -name '*.md' -o -name '*.sh' -o -name '*.yml' -o -name '*.yaml' -o -name '*.toml' -o -name '*.txt' \) -print0)

while IFS= read -r -d '' file; do
  chmod +x "${file}"
done < <(find "${DEST}" -type f \( -name '*.sh' \) -print0)

prune_transient_artifacts "${DEST}"

echo "[bootstrap] Project created at ${DEST}"
echo "[bootstrap] Suggested next steps:"
echo "  1) cd ${DEST}"
echo "  2) ./scripts/smoke-test.sh"
echo "  3) ./scripts/check.sh --stack ${STACK}"
