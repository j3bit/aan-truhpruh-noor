#!/usr/bin/env bash
set -euo pipefail

ROOT="${EVAL_REPO_ROOT:-$(pwd)}"
TMP_DIR="$(mktemp -d)"
TARGET="${TMP_DIR}/prd-required-sections"
trap 'rm -rf "${TMP_DIR}"' EXIT

bash "${ROOT}/scripts/bootstrap-new-project.sh" \
  --name "prd-required-sections" \
  --stack python \
  --dest "${TARGET}"

cat > "${TARGET}/tasks/prd-1234-prd-required-sections.md" <<'EOF'
# PRD-1234: prd-required-sections

## Goals
- Verify PRD section enforcement fails when required sections are missing.
EOF

cp "${TARGET}/tasks/templates/tasks.template.md" "${TARGET}/tasks/tasks-1234-prd-required-sections.md"

set +e
(cd "${TARGET}" && bash ./scripts/check.sh --stack python >/dev/null 2>&1)
missing_status=$?
set -e

if [[ "${missing_status}" -eq 0 ]]; then
  echo "[case-08] check passed even though PRD required sections are missing" >&2
  exit 1
fi

cp "${TARGET}/tasks/templates/prd.template.md" "${TARGET}/tasks/prd-1234-prd-required-sections.md"
(cd "${TARGET}" && bash ./scripts/check.sh --stack python >/dev/null)
