#!/usr/bin/env bash
set -euo pipefail

ROOT="${EVAL_REPO_ROOT:-$(pwd)}"
TMP_DIR="$(mktemp -d)"
TARGET="${TMP_DIR}/filename-check"
trap 'rm -rf "${TMP_DIR}"' EXIT

bash "${ROOT}/scripts/bootstrap-new-project.sh" \
  --name "filename-check" \
  --stack python \
  --dest "${TARGET}"

cp "${TARGET}/tasks/templates/prd.template.md" "${TARGET}/tasks/prd-12-invalid.md"
cp "${TARGET}/tasks/templates/tasks.template.md" "${TARGET}/tasks/tasks-12-invalid.md"

set +e
(cd "${TARGET}" && bash ./scripts/check.sh --stack python >/dev/null 2>&1)
invalid_status=$?
set -e

if [[ "${invalid_status}" -eq 0 ]]; then
  echo "[case-03] check passed with invalid 4-digit file names" >&2
  exit 1
fi

rm -f "${TARGET}/tasks/prd-12-invalid.md" "${TARGET}/tasks/tasks-12-invalid.md"
cp "${TARGET}/tasks/templates/prd.template.md" "${TARGET}/tasks/prd-1234-valid.md"
cp "${TARGET}/tasks/templates/tasks.template.md" "${TARGET}/tasks/tasks-1234-valid.md"

(cd "${TARGET}" && bash ./scripts/check.sh --stack python >/dev/null)
