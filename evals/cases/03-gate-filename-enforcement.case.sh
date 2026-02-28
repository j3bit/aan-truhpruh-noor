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
cp "${TARGET}/tasks/templates/trd.template.md" "${TARGET}/tasks/trd-1234-valid.md"
cp "${TARGET}/tasks/templates/dag.template.md" "${TARGET}/tasks/dag-1234-valid.md"

cat > "${TARGET}/tasks/tasks-1234-valid.md" <<'EOF'
# TASKS-1234: valid

## Metadata
- File name: `tasks/tasks-1234-valid.md`
- PRD: `tasks/prd-1234-valid.md`
- TRD: `tasks/trd-1234-valid.md`
- Task DAG: `tasks/dag-1234-valid.json`
- Task DAG Markdown: `tasks/dag-1234-valid.md`
- Planning Artifact: `.blackboard/artifacts/task-planning/1234-valid.json`
- Gate Stack: `python`
- Owner: `eval`
- Last Updated: `2026-02-27`

## Task List

### T-001: base
- Status: `todo`
- Dependencies: `none`
- Parallel-safe: `no`
- Description:
  -
- Acceptance Criteria:
  1.
- Test Plan:
  1.
- Done Definition:
  1. Acceptance criteria are satisfied.
  2. Test plan was executed and evidenced.
  3. `./scripts/check.sh --stack python` exits with code `0`.

### T-002: dependent
- Status: `todo`
- Dependencies: `T-001`
- Parallel-safe: `no`
- Description:
  -
- Acceptance Criteria:
  1.
- Test Plan:
  1.
- Done Definition:
  1. Acceptance criteria are satisfied.
  2. Test plan was executed and evidenced.
  3. `./scripts/check.sh --stack python` exits with code `0`.
EOF

cat > "${TARGET}/tasks/dag-1234-valid.json" <<'EOF'
{
  "metadata": {
    "id": "1234",
    "slug": "valid",
    "prd": "tasks/prd-1234-valid.md",
    "trd": "tasks/trd-1234-valid.md",
    "tasks": "tasks/tasks-1234-valid.md",
    "gate_stack": "python"
  },
  "nodes": [
    {
      "task_id": "T-001",
      "depends_on": [],
      "parallel_safe": false,
      "stage": "IMPLEMENTATION"
    },
    {
      "task_id": "T-002",
      "depends_on": ["T-001"],
      "parallel_safe": false,
      "stage": "IMPLEMENTATION"
    }
  ]
}
EOF

(cd "${TARGET}" && bash ./scripts/check.sh --stack python >/dev/null)
