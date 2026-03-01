#!/usr/bin/env bash
set -euo pipefail

ROOT="${EVAL_REPO_ROOT:-$(pwd)}"
TMP_DIR="$(mktemp -d)"
TARGET="${TMP_DIR}/fallback-all-stacks"
LOG_FILE="${TMP_DIR}/check.log"
trap 'rm -rf "${TMP_DIR}"' EXIT

bash "${ROOT}/scripts/bootstrap-new-project.sh" \
  --name "fallback-all-stacks" \
  --stacks python,node \
  --dest "${TARGET}"

(
  cd "${TARGET}"
  git init -q
  git add .
  git -c user.name='eval' -c user.email='eval@example.com' commit -q -m "baseline"
)

echo "unmatched change" >> "${TARGET}/docs-unmatched.txt"

(cd "${TARGET}" && bash ./scripts/check.sh --stacks auto --changed-only > "${LOG_FILE}")

if ! grep -Eq "\\[check\\] selected_stacks=(python,node|node,python)" "${LOG_FILE}"; then
  echo "[case-25] unmatched change did not fall back to full stack set" >&2
  cat "${LOG_FILE}" >&2
  exit 1
fi
