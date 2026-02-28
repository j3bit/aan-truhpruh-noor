#!/usr/bin/env bash
set -euo pipefail

ROOT="${EVAL_REPO_ROOT:-$(pwd)}"
TMP_DIR="$(mktemp -d)"
TARGET="${TMP_DIR}/done-definition-check"
trap 'rm -rf "${TMP_DIR}"' EXIT

bash "${ROOT}/scripts/bootstrap-new-project.sh" \
  --name "done-definition-check" \
  --stack python \
  --dest "${TARGET}"

cp "${TARGET}/tasks/templates/prd.template.md" "${TARGET}/tasks/prd-1234-done-definition.md"
cp "${TARGET}/tasks/templates/trd.template.md" "${TARGET}/tasks/trd-1234-done-definition.md"
cp "${TARGET}/tasks/templates/dag.template.md" "${TARGET}/tasks/dag-1234-done-definition.md"

cat > "${TARGET}/tasks/dag-1234-done-definition.json" <<'EOF'
{
  "metadata": {
    "id": "1234",
    "slug": "done-definition",
    "prd": "tasks/prd-1234-done-definition.md",
    "trd": "tasks/trd-1234-done-definition.md",
    "tasks": "tasks/tasks-1234-done-definition.md",
    "gate_stack": "python"
  },
  "nodes": [
    {
      "task_id": "T-001",
      "depends_on": [],
      "parallel_safe": false,
      "stage": "IMPLEMENTATION"
    }
  ]
}
EOF

cat > "${TARGET}/tasks/tasks-1234-done-definition.md" <<'EOF'
# TASKS-1234: done-definition-check

## Metadata
- File name: `tasks/tasks-1234-done-definition.md`
- PRD: `tasks/prd-1234-done-definition.md`
- TRD: `tasks/trd-1234-done-definition.md`
- Task DAG: `tasks/dag-1234-done-definition.json`
- Gate Stack: `python`
- Owner: example
- Last Updated: 2026-02-22

## Task List

### T-001: missing done definition
- Status: `todo`
- Dependencies: `none`
- Parallel-safe: `no`
- Acceptance Criteria:
  1. Contract validator should detect missing done definition.
- Test Plan:
  1. Run `./scripts/check.sh --stack python`.
EOF

set +e
(cd "${TARGET}" && bash ./scripts/check.sh --stack python >/dev/null 2>&1)
missing_status=$?
set -e

if [[ "${missing_status}" -eq 0 ]]; then
  echo "[case-04] check passed even though Done Definition is missing" >&2
  exit 1
fi

cat >> "${TARGET}/tasks/tasks-1234-done-definition.md" <<'EOF'
- Done Definition:
  1. Acceptance criteria are satisfied.
  2. Test plan was executed and evidenced.
  3. `./scripts/check.sh --stack python` exits with code `0`.
EOF

(cd "${TARGET}" && bash ./scripts/check.sh --stack python >/dev/null)
