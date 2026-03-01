#!/usr/bin/env bash
set -euo pipefail

ROOT="${EVAL_REPO_ROOT:-$(pwd)}"
TMP_DIR="$(mktemp -d)"
TARGET="${TMP_DIR}/deleted-file-stack-selection"
LOG_FILE="${TMP_DIR}/check.log"
trap 'rm -rf "${TMP_DIR}"' EXIT

bash "${ROOT}/scripts/bootstrap-new-project.sh" \
  --name "deleted-file-stack-selection" \
  --stacks python,node \
  --dest "${TARGET}"

(
  cd "${TARGET}"
  git init -q
  git add .
  git -c user.name='eval' -c user.email='eval@example.com' commit -q -m "baseline"
)

rm -f "${TARGET}/services/python-hello/main.py"
echo "// changed by eval case 29" >> "${TARGET}/services/node-hello/test/basic.test.js"

set +e
(cd "${TARGET}" && bash ./scripts/check.sh --stacks auto --changed-only > "${LOG_FILE}")
_status=$?
set -e

if ! grep -Eq "\\[check\\] selected_stacks=(python,node|node,python)" "${LOG_FILE}"; then
  echo "[case-29] changed-only selection missed deleted-file stack" >&2
  cat "${LOG_FILE}" >&2
  exit 1
fi
