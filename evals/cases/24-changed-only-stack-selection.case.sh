#!/usr/bin/env bash
set -euo pipefail

ROOT="${EVAL_REPO_ROOT:-$(pwd)}"
TMP_DIR="$(mktemp -d)"
TARGET="${TMP_DIR}/changed-only-selection"
LOG_FILE="${TMP_DIR}/check.log"
trap 'rm -rf "${TMP_DIR}"' EXIT

bash "${ROOT}/scripts/bootstrap-new-project.sh" \
  --name "changed-only-selection" \
  --stacks python,node \
  --dest "${TARGET}"

(
  cd "${TARGET}"
  git init -q
  git add .
  git -c user.name='eval' -c user.email='eval@example.com' commit -q -m "baseline"
)

echo "// changed by eval case 24" >> "${TARGET}/services/node-hello/test/basic.test.js"

(cd "${TARGET}" && bash ./scripts/check.sh --stacks auto --changed-only > "${LOG_FILE}")

if ! grep -Fq "[check] selected_stacks=node" "${LOG_FILE}"; then
  echo "[case-24] changed-only selection did not isolate node stack" >&2
  cat "${LOG_FILE}" >&2
  exit 1
fi

if grep -Eq "\\[check\\] selected_stacks=(python,node|node,python)" "${LOG_FILE}"; then
  echo "[case-24] changed-only selection unexpectedly included python stack" >&2
  cat "${LOG_FILE}" >&2
  exit 1
fi
