#!/usr/bin/env bash
set -euo pipefail

ROOT="${EVAL_REPO_ROOT:-$(pwd)}"
TMP_DIR="$(mktemp -d)"
TARGET="${TMP_DIR}/sub-agent-custom-registry"
RESULT_FILE="${TMP_DIR}/worker-result.json"
trap 'rm -rf "${TMP_DIR}"' EXIT

bash "${ROOT}/scripts/bootstrap-new-project.sh" \
  --name "sub-agent-custom-registry" \
  --stacks python \
  --dest "${TARGET}"

cp "${TARGET}/tasks/templates/prd.template.md" "${TARGET}/tasks/prd-1234-sub-agent-custom-registry.md"
cp "${TARGET}/tasks/templates/trd.template.md" "${TARGET}/tasks/trd-1234-sub-agent-custom-registry.md"

cp "${TARGET}/tasks/stacks.json" "${TARGET}/tasks/custom-stacks.json"

cat > "${TARGET}/tasks/tasks-1234-sub-agent-custom-registry.md" <<'EOF'
# TASKS-1234: sub-agent-custom-registry

## Metadata
- File name: `tasks/tasks-1234-sub-agent-custom-registry.md`
- PRD: `tasks/prd-1234-sub-agent-custom-registry.md`
- TRD: `tasks/trd-1234-sub-agent-custom-registry.md`
- Task DAG: `tasks/dag-1234-sub-agent-custom-registry.json`
- Task DAG Markdown: `tasks/dag-1234-sub-agent-custom-registry.md`
- Planning Artifact: `.blackboard/artifacts/task-planning/1234-sub-agent-custom-registry.json`
- Stack Registry: `tasks/custom-stacks.json`

## Task List

### T-001: verify custom stack registry gate path
- Status: `todo`
- Dependencies: `none`
- Parallel-safe: `yes`
- Description:
  - run worker gate with custom registry metadata path.
- Acceptance Criteria:
  1. run-sub-agent forwards --registry to check.sh and gate passes.
- Test Plan:
  1. invoke run-sub-agent with --registry tasks/custom-stacks.json.
- Done Definition:
  1. worker result reports gate_passed=true.
EOF

cat > "${TARGET}/tasks/dag-1234-sub-agent-custom-registry.md" <<'EOF'
# DAG-1234: sub-agent-custom-registry

## Metadata
- File name: `tasks/dag-1234-sub-agent-custom-registry.md`
- PRD: `tasks/prd-1234-sub-agent-custom-registry.md`
- TRD: `tasks/trd-1234-sub-agent-custom-registry.md`
- Tasks: `tasks/tasks-1234-sub-agent-custom-registry.md`
- Stack Registry: `tasks/custom-stacks.json`
- Last Updated: 2026-03-01

## Nodes
| Task ID | Depends On | Parallel-safe | Stage |
|---|---|---|---|
| T-001 | none | yes | IMPLEMENTATION |

## Waves (Topological Order)
1. Wave 1: T-001
EOF

cat > "${TARGET}/tasks/dag-1234-sub-agent-custom-registry.json" <<'EOF'
{
  "metadata": {
    "id": "1234",
    "slug": "sub-agent-custom-registry",
    "prd": "tasks/prd-1234-sub-agent-custom-registry.md",
    "trd": "tasks/trd-1234-sub-agent-custom-registry.md",
    "tasks": "tasks/tasks-1234-sub-agent-custom-registry.md",
    "stack_registry": "tasks/custom-stacks.json"
  },
  "nodes": [
    {
      "task_id": "T-001",
      "depends_on": [],
      "parallel_safe": true,
      "gate_stacks": ["python"],
      "stage": "IMPLEMENTATION"
    }
  ]
}
EOF

ORCH_WORKER_CMD=true \
bash "${TARGET}/scripts/run-sub-agent.sh" \
  --task-id "T-001" \
  --project-dir "${TARGET}" \
  --worktree-dir "${TARGET}" \
  --stacks "python" \
  --registry "tasks/custom-stacks.json" \
  --result-file "${RESULT_FILE}" \
  --worker-backend "codex-exec" \
  --timeout-seconds 120 >/dev/null

jq -e '.exit_code == 0 and .gate_passed == true and .pr_review_passed == true' "${RESULT_FILE}" >/dev/null
