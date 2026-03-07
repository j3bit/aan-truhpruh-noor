#!/usr/bin/env bash
set -euo pipefail

ROOT="${EVAL_REPO_ROOT:-$(pwd)}"
TMP_DIR="$(mktemp -d)"
TARGET="${TMP_DIR}/dag-gate-stacks-validation"
trap 'rm -rf "${TMP_DIR}"' EXIT

bash "${ROOT}/scripts/bootstrap-new-project.sh" \
  --name "dag-gate-stacks-validation" \
  --stacks python \
  --dest "${TARGET}"

cp "${TARGET}/tasks/templates/prd.template.md" "${TARGET}/tasks/prd-1234-dag-gate-stacks-validation.md"
cp "${TARGET}/tasks/templates/trd.template.md" "${TARGET}/tasks/trd-1234-dag-gate-stacks-validation.md"
cp "${TARGET}/tasks/templates/dag.template.md" "${TARGET}/tasks/dag-1234-dag-gate-stacks-validation.md"

cat > "${TARGET}/tasks/tasks-1234-dag-gate-stacks-validation.md" <<'EOF'
# TASKS-1234: dag-gate-stacks-validation

## Metadata
- File name: `tasks/tasks-1234-dag-gate-stacks-validation.md`
- PRD: `tasks/prd-1234-dag-gate-stacks-validation.md`
- TRD: `tasks/trd-1234-dag-gate-stacks-validation.md`
- Task DAG: `tasks/dag-1234-dag-gate-stacks-validation.json`
- Task DAG Markdown: `tasks/dag-1234-dag-gate-stacks-validation.md`
- Planning Artifact: `.blackboard/artifacts/task-planning/1234-dag-gate-stacks-validation.json`
- Stack Registry: `tasks/stacks.json`
- Owner: `eval`
- Last Updated: `2026-03-01`

## Task List

### T-001: invalid stack reference
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
  3. `./scripts/check.sh --stacks auto` exits with code `0`.
EOF

cat > "${TARGET}/tasks/dag-1234-dag-gate-stacks-validation.json" <<'EOF'
{
  "metadata": {
    "id": "1234",
    "slug": "dag-gate-stacks-validation",
    "prd": "tasks/prd-1234-dag-gate-stacks-validation.md",
    "trd": "tasks/trd-1234-dag-gate-stacks-validation.md",
    "tasks": "tasks/tasks-1234-dag-gate-stacks-validation.md",
    "stack_registry": "tasks/stacks.json"
  },
  "nodes": [
    {
      "task_id": "T-001",
      "depends_on": [],
      "parallel_safe": false,
      "gate_stacks": ["rust"],
      "stage": "IMPLEMENTATION"
    }
  ]
}
EOF

set +e
(cd "${TARGET}" && bash ./scripts/validate-contracts.sh --project-dir . >/dev/null 2>&1)
invalid_stack_status=$?
set -e

if [[ "${invalid_stack_status}" -eq 0 ]]; then
  echo "[case-26] validate-contracts passed despite unregistered DAG gate_stacks entry" >&2
  exit 1
fi
