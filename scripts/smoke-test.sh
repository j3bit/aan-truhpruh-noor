#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

assert_file() {
  local path="$1"
  [[ -f "$path" ]] || { echo "[smoke] ERROR: missing file: $path" >&2; exit 1; }
}

run_bootstrap_check() {
  local stack="$1"
  local root_dir="$2"
  local target="${root_dir}/bootstrap-${stack}"

  bash "${REPO_ROOT}/scripts/bootstrap-new-project.sh" \
    --name "bootstrap-${stack}" \
    --stack "${stack}" \
    --dest "${target}"

  assert_file "${target}/AGENTS.md"
  assert_file "${target}/tasks/process-rules.md"
  assert_file "${target}/scripts/check.sh"
  assert_file "${target}/.github/workflows/check.yml"
  assert_file "${target}/evals/run-evals.sh"

  if [[ "${stack}" == "python" ]]; then
    if command -v python3 >/dev/null 2>&1 || command -v python >/dev/null 2>&1; then
      (cd "${target}" && bash ./scripts/check.sh --stack python)
    else
      echo "[smoke] INFO: python not available; skipping python gate execution"
    fi
  fi

  if [[ "${stack}" == "node" ]]; then
    if command -v node >/dev/null 2>&1; then
      (cd "${target}" && bash ./scripts/check.sh --stack node)
    else
      echo "[smoke] INFO: node not available; skipping node gate execution"
    fi
  fi

  if [[ "${stack}" == "go" ]]; then
    if command -v go >/dev/null 2>&1; then
      (cd "${target}" && bash ./scripts/check.sh --stack go)
    else
      echo "[smoke] INFO: go not available; skipping go gate execution"
    fi
  fi
}

echo "[smoke] Running shell syntax checks"
while IFS= read -r -d '' file; do
  bash -n "$file"
done < <(find "${REPO_ROOT}/scripts" "${REPO_ROOT}/templates/stacks" "${REPO_ROOT}/evals" -type f -name '*.sh' -print0)

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

run_bootstrap_check python "${TMP_DIR}"
run_bootstrap_check node "${TMP_DIR}"
run_bootstrap_check go "${TMP_DIR}"

echo "[smoke] PASS"
