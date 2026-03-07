#!/usr/bin/env bash
set -euo pipefail

ROOT="${EVAL_REPO_ROOT:-$(pwd)}"
TMP_DIR="$(mktemp -d)"
TARGET="${TMP_DIR}/task-dag-artifact-metadata"
trap 'rm -rf "${TMP_DIR}"' EXIT

bash "${ROOT}/scripts/bootstrap-new-project.sh" \
  --name "task-dag-artifact-metadata" \
  --stacks python \
  --dest "${TARGET}"

cp "${TARGET}/tasks/templates/prd.template.md" "${TARGET}/tasks/prd-1234-task-dag-artifact-metadata.md"
cp "${TARGET}/tasks/templates/trd.template.md" "${TARGET}/tasks/trd-1234-task-dag-artifact-metadata.md"

cat > "${TARGET}/tasks/tasks-1234-task-dag-artifact-metadata.md" <<'EOF'
# TASKS-1234: task-dag-artifact-metadata

## Metadata
- File name: `tasks/tasks-1234-task-dag-artifact-metadata.md`
- PRD: `tasks/prd-1234-task-dag-artifact-metadata.md`
- TRD: `tasks/trd-1234-task-dag-artifact-metadata.md`
- Task DAG: `tasks/dag-1234-task-dag-artifact-metadata.json`
- Task DAG Markdown: `tasks/dag-1234-task-dag-artifact-metadata-wrong.md`
- Planning Artifact: `.blackboard/artifacts/task-planning/wrong.json`
- Stack Registry: `tasks/stacks.json`
- Owner: `eval`
- Last Updated: `2026-02-28`

## Task List

### T-001: metadata contract
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

cat > "${TARGET}/tasks/dag-1234-task-dag-artifact-metadata.md" <<'EOF'
# DAG-1234: task-dag-artifact-metadata

## Metadata
- File name: `tasks/dag-1234-task-dag-artifact-metadata.md`
- PRD: `tasks/prd-1234-task-dag-artifact-metadata.md`
- TRD: `tasks/trd-1234-task-dag-artifact-metadata.md`
- Tasks: `tasks/tasks-1234-task-dag-artifact-metadata.md`
- Stack Registry: `tasks/stacks.json`
- Last Updated: 2026-02-28

## Nodes
| Task ID | Depends On | Parallel-safe | Stage |
|---|---|---|---|
| T-001 | none | no | IMPLEMENTATION |

## Waves (Topological Order)
1. Wave 1: T-001
EOF

cat > "${TARGET}/tasks/dag-1234-task-dag-artifact-metadata.json" <<'EOF'
{
  "metadata": {
    "id": "1234",
    "slug": "task-dag-artifact-metadata",
    "prd": "tasks/prd-1234-task-dag-artifact-metadata.md",
    "trd": "tasks/trd-1234-task-dag-artifact-metadata.md",
    "tasks": "tasks/tasks-1234-task-dag-artifact-metadata.md",
    "stack_registry": "tasks/stacks.json"
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

set +e
(cd "${TARGET}" && bash ./scripts/validate-contracts.sh --project-dir . >/dev/null 2>&1)
invalid_metadata_status=$?
set -e

if [[ "${invalid_metadata_status}" -eq 0 ]]; then
  echo "[case-19] contract validation passed despite invalid Task DAG metadata paths" >&2
  exit 1
fi

perl -0pi -e 's#- Task DAG Markdown: `[^`]+`#- Task DAG Markdown: `tasks/dag-1234-task-dag-artifact-metadata.md`#' \
  "${TARGET}/tasks/tasks-1234-task-dag-artifact-metadata.md"
perl -0pi -e 's#- Planning Artifact: `[^`]+`#- Planning Artifact: `.blackboard/artifacts/task-planning/1234-task-dag-artifact-metadata.json`#' \
  "${TARGET}/tasks/tasks-1234-task-dag-artifact-metadata.md"

(cd "${TARGET}" && bash ./scripts/validate-contracts.sh --project-dir . >/dev/null)
