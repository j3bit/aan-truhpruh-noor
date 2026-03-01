#!/usr/bin/env bash
set -euo pipefail

ROOT="${EVAL_REPO_ROOT:-$(pwd)}"
TMP_DIR="$(mktemp -d)"
TARGET="${TMP_DIR}/registry-required"
trap 'rm -rf "${TMP_DIR}"' EXIT

bash "${ROOT}/scripts/bootstrap-new-project.sh" \
  --name "registry-required" \
  --stacks python \
  --dest "${TARGET}"

mv "${TARGET}/tasks/stacks.json" "${TARGET}/tasks/stacks.json.bak-input"

set +e
(cd "${TARGET}" && bash ./scripts/validate-contracts.sh --project-dir . >/dev/null 2>&1)
missing_registry_status=$?
set -e

if [[ "${missing_registry_status}" -eq 0 ]]; then
  echo "[case-23] validate-contracts passed without tasks/stacks.json" >&2
  exit 1
fi

mv "${TARGET}/tasks/stacks.json.bak-input" "${TARGET}/tasks/stacks.json"
(cd "${TARGET}" && bash ./scripts/validate-contracts.sh --project-dir . >/dev/null)
