#!/usr/bin/env bash
set -euo pipefail

ROOT="${EVAL_REPO_ROOT:-$(pwd)}"
TMP_DIR="$(mktemp -d)"
TARGET="${TMP_DIR}/parallel-safe-wave"
OUT_DIR="${TMP_DIR}/orchestration-out"
trap 'rm -rf "${TMP_DIR}"' EXIT

bash "${ROOT}/scripts/bootstrap-new-project.sh" \
  --name "parallel-safe-wave" \
  --stacks python \
  --dest "${TARGET}"

cp "${TARGET}/tasks/templates/prd.template.md" "${TARGET}/tasks/prd-1234-parallel-safe-wave.md"
cp "${TARGET}/tasks/templates/trd.template.md" "${TARGET}/tasks/trd-1234-parallel-safe-wave.md"

cat > "${TARGET}/tasks/tasks-1234-parallel-safe-wave.md" <<'EOF'
# TASKS-1234: parallel-safe-wave

## Metadata
- File name: `tasks/tasks-1234-parallel-safe-wave.md`
- PRD: `tasks/prd-1234-parallel-safe-wave.md`
- TRD: `tasks/trd-1234-parallel-safe-wave.md`
- Task DAG: `tasks/dag-1234-parallel-safe-wave.json`
- Task DAG Markdown: `tasks/dag-1234-parallel-safe-wave.md`
- Planning Artifact: `.blackboard/artifacts/task-planning/1234-parallel-safe-wave.json`
- Stack Registry: `tasks/stacks.json`

## Task List

### T-001: serial task A
- Status: `todo`
- Dependencies: `none`
- Parallel-safe: `no`
- Description:
  - serial task A
- Acceptance Criteria:
  1. wave planning enforces non-parallel-safe serialization.
- Test Plan:
  1. run lead orchestrator in plan-only mode.
- Done Definition:
  1. plan contract is valid.

### T-002: serial task B
- Status: `todo`
- Dependencies: `none`
- Parallel-safe: `no`
- Description:
  - serial task B
- Acceptance Criteria:
  1. wave planning enforces non-parallel-safe serialization.
- Test Plan:
  1. run lead orchestrator in plan-only mode.
- Done Definition:
  1. plan contract is valid.

### T-003: parallel task A
- Status: `todo`
- Dependencies: `none`
- Parallel-safe: `yes`
- Description:
  - parallel task A
- Acceptance Criteria:
  1. independent parallel-safe tasks may share a wave.
- Test Plan:
  1. run lead orchestrator in plan-only mode.
- Done Definition:
  1. plan contract is valid.

### T-004: parallel task B
- Status: `todo`
- Dependencies: `none`
- Parallel-safe: `yes`
- Description:
  - parallel task B
- Acceptance Criteria:
  1. independent parallel-safe tasks may share a wave.
- Test Plan:
  1. run lead orchestrator in plan-only mode.
- Done Definition:
  1. plan contract is valid.
EOF

cat > "${TARGET}/tasks/dag-1234-parallel-safe-wave.json" <<'EOF'
{
  "metadata": {
    "id": "1234",
    "slug": "parallel-safe-wave",
    "prd": "tasks/prd-1234-parallel-safe-wave.md",
    "trd": "tasks/trd-1234-parallel-safe-wave.md",
    "tasks": "tasks/tasks-1234-parallel-safe-wave.md",
    "stack_registry": "tasks/stacks.json"
  },
  "nodes": [
    {
      "task_id": "T-001",
      "depends_on": [],
      "parallel_safe": false,
      "gate_stacks": ["python"],
      "stage": "IMPLEMENTATION"
    },
    {
      "task_id": "T-002",
      "depends_on": [],
      "parallel_safe": false,
      "gate_stacks": ["python"],
      "stage": "IMPLEMENTATION"
    },
    {
      "task_id": "T-003",
      "depends_on": [],
      "parallel_safe": true,
      "gate_stacks": ["python"],
      "stage": "IMPLEMENTATION"
    },
    {
      "task_id": "T-004",
      "depends_on": [],
      "parallel_safe": true,
      "gate_stacks": ["python"],
      "stage": "IMPLEMENTATION"
    }
  ]
}
EOF

bash "${TARGET}/scripts/lead-orchestrate.sh" \
  --project-dir "${TARGET}" \
  --tasks-file "${TARGET}/tasks/tasks-1234-parallel-safe-wave.md" \
  --dag-file "${TARGET}/tasks/dag-1234-parallel-safe-wave.json" \
  --plan-only \
  --out-dir "${OUT_DIR}" >/dev/null

test -f "${OUT_DIR}/plan.jsonl"

# No wave may contain more than one non-parallel-safe task.
jq -s -e '
  [group_by(.wave)[] | [ .[] | select(.parallel_safe == false) ] | length]
  | all(.[]; . <= 1)
' "${OUT_DIR}/plan.jsonl" >/dev/null

# Independent parallel-safe tasks should share the same wave for maximal parallelism.
jq -s -e '
  (map(select(.task_id == "T-003")) | .[0].wave) as $w3 |
  (map(select(.task_id == "T-004")) | .[0].wave) as $w4 |
  $w3 == $w4
' "${OUT_DIR}/plan.jsonl" >/dev/null
