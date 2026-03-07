#!/usr/bin/env bash
set -euo pipefail

ROOT="${EVAL_REPO_ROOT:-$(pwd)}"
TMP_DIR="$(mktemp -d)"
TARGET="${TMP_DIR}/custom-registry-path-contract"
trap 'rm -rf "${TMP_DIR}"' EXIT

bash "${ROOT}/scripts/bootstrap-new-project.sh" \
  --name "custom-registry-path-contract" \
  --stacks python \
  --dest "${TARGET}"

cp "${TARGET}/tasks/templates/prd.template.md" "${TARGET}/tasks/prd-1234-custom-registry.md"
cp "${TARGET}/tasks/templates/trd.template.md" "${TARGET}/tasks/trd-1234-custom-registry.md"

cat > "${TARGET}/tasks/tasks-1234-custom-registry.md" <<'EOF'
# TASKS-1234: custom-registry

## Metadata
- File name: `tasks/tasks-1234-custom-registry.md`
- PRD: `tasks/prd-1234-custom-registry.md`
- TRD: `tasks/trd-1234-custom-registry.md`
- Task DAG: `tasks/dag-1234-custom-registry.json`
- Task DAG Markdown: `tasks/dag-1234-custom-registry.md`
- Planning Artifact: `.blackboard/artifacts/task-planning/1234-custom-registry.json`
- Stack Registry: `tasks/custom-stacks.json`

## Task List

### T-001: custom registry check
- Status: `todo`
- Dependencies: `none`
- Parallel-safe: `no`
- Description:
  - verify custom registry path contract.
- Acceptance Criteria:
  1. validate-contracts accepts metadata paths that match --registry.
- Test Plan:
  1. run validate-contracts/check with --registry tasks/custom-stacks.json.
- Done Definition:
  1. contract checks pass.
EOF

cat > "${TARGET}/tasks/dag-1234-custom-registry.md" <<'EOF'
# DAG-1234: custom-registry

## Metadata
- File name: `tasks/dag-1234-custom-registry.md`
- PRD: `tasks/prd-1234-custom-registry.md`
- TRD: `tasks/trd-1234-custom-registry.md`
- Tasks: `tasks/tasks-1234-custom-registry.md`
- Stack Registry: `tasks/custom-stacks.json`
- Last Updated: 2026-03-01

## Nodes
| Task ID | Depends On | Parallel-safe | Stage |
|---|---|---|---|
| T-001 | none | no | IMPLEMENTATION |

## Waves (Topological Order)
1. Wave 1: T-001
EOF

cat > "${TARGET}/tasks/dag-1234-custom-registry.json" <<'EOF'
{
  "metadata": {
    "id": "1234",
    "slug": "custom-registry",
    "prd": "tasks/prd-1234-custom-registry.md",
    "trd": "tasks/trd-1234-custom-registry.md",
    "tasks": "tasks/tasks-1234-custom-registry.md",
    "stack_registry": "tasks/custom-stacks.json"
  },
  "nodes": [
    {
      "task_id": "T-001",
      "depends_on": [],
      "parallel_safe": false,
      "gate_stacks": ["python"],
      "stage": "IMPLEMENTATION"
    }
  ]
}
EOF

cp "${TARGET}/tasks/stacks.json" "${TARGET}/tasks/custom-stacks.json"

bash "${TARGET}/scripts/validate-contracts.sh" \
  --project-dir "${TARGET}" \
  --registry "tasks/custom-stacks.json" >/dev/null

bash "${TARGET}/scripts/check.sh" \
  --project-dir "${TARGET}" \
  --registry "tasks/custom-stacks.json" \
  --stacks auto >/dev/null
