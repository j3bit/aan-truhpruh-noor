#!/usr/bin/env bash
set -euo pipefail

ROOT="${EVAL_REPO_ROOT:-$(pwd)}"
TMP_DIR="$(mktemp -d)"
TARGET="${TMP_DIR}/migration-dry-run-no-side-effects"
LOG_FILE="${TMP_DIR}/migrate.log"
trap 'rm -rf "${TMP_DIR}"' EXIT

mkdir -p "${TARGET}/tasks" "${TARGET}/templates/stacks/python"

cat > "${TARGET}/tasks/tasks-0001-test.md" <<'EOF'
# TASKS-0001: test

## Metadata
- File name: `tasks/tasks-0001-test.md`
- PRD: `tasks/prd-0001-test.md`
- TRD: `tasks/trd-0001-test.md`
- Task DAG: `tasks/dag-0001-test.json`
- Stack Registry: `tasks/stacks.json`
- Gate Stack: `python`
EOF

before_file="${TMP_DIR}/before.txt"
after_file="${TMP_DIR}/after.txt"

(cd "${TARGET}" && find . -mindepth 1 | sort) > "${before_file}"

bash "${ROOT}/scripts/migrate-polyglot.sh" --project-dir "${TARGET}" --dry-run > "${LOG_FILE}"

(cd "${TARGET}" && find . -mindepth 1 | sort) > "${after_file}"

if ! cmp -s "${before_file}" "${after_file}"; then
  echo "[case-34] dry-run modified repository contents" >&2
  diff -u "${before_file}" "${after_file}" >&2 || true
  exit 1
fi

grep -q "WOULD_ENSURE product-root scaffold directories" "${LOG_FILE}"
grep -q "Dry-run complete. No files were written." "${LOG_FILE}"
