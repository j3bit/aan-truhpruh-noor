#!/usr/bin/env bash
set -euo pipefail

ROOT="${EVAL_REPO_ROOT:-$(pwd)}"
TMP_DIR="$(mktemp -d)"
TARGET="${TMP_DIR}/cross-stack-rename-selection"
LOG_FILE="${TMP_DIR}/check.log"
trap 'rm -rf "${TMP_DIR}"' EXIT

bash "${ROOT}/scripts/bootstrap-new-project.sh" \
  --name "cross-stack-rename-selection" \
  --stacks python,node \
  --dest "${TARGET}"

(
  cd "${TARGET}"
  git init -q
  git add .
  git -c user.name='eval' -c user.email='eval@example.com' commit -q -m "baseline"
)

(
  cd "${TARGET}"
  git mv "services/python-hello/main.py" "services/node-hello/migrated-main.js"
)

set +e
(cd "${TARGET}" && bash ./scripts/check.sh --stacks auto --changed-only > "${LOG_FILE}")
_status=$?
set -e

if ! grep -Eq "\\[check\\] selected_stacks=(python,node|node,python)" "${LOG_FILE}"; then
  echo "[case-30] changed-only selection missed rename source stack" >&2
  cat "${LOG_FILE}" >&2
  exit 1
fi
