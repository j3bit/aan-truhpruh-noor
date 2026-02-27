#!/usr/bin/env bash
set -euo pipefail

ROOT="${EVAL_REPO_ROOT:-$(pwd)}"
TMP_DIR="$(mktemp -d)"
TARGET="${TMP_DIR}/dag-contract-check"
trap 'rm -rf "${TMP_DIR}"' EXIT

bash "${ROOT}/scripts/bootstrap-new-project.sh" \
  --name "dag-contract-check" \
  --stack python \
  --dest "${TARGET}"

cp "${TARGET}/tasks/templates/prd.template.md" "${TARGET}/tasks/prd-1234-dag-contract-check.md"
cp "${TARGET}/tasks/templates/trd.template.md" "${TARGET}/tasks/trd-1234-dag-contract-check.md"

cat > "${TARGET}/tasks/tasks-1234-dag-contract-check.md" <<'EOF'
# TASKS-1234: dag-contract-check

## Metadata
- File name: `tasks/tasks-1234-dag-contract-check.md`
- PRD: `tasks/prd-1234-dag-contract-check.md`
- TRD: `tasks/trd-1234-dag-contract-check.md`
- Task DAG: `tasks/dag-1234-dag-contract-check-wrong.json`
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

cat > "${TARGET}/tasks/dag-1234-dag-contract-check.md" <<'EOF'
# DAG-1234: dag-contract-check

## Metadata
- File name: `tasks/dag-1234-dag-contract-check.md`
- PRD: `tasks/prd-1234-dag-contract-check.md`
- TRD: `tasks/trd-1234-dag-contract-check.md`
- Tasks: `tasks/tasks-1234-dag-contract-check.md`
- Gate Stack: `python`
- Last Updated: 2026-02-27

## Nodes
| Task ID | Depends On | Parallel-safe | Stage |
|---|---|---|---|
| T-001 | none | no | IMPLEMENTATION |
| T-002 | T-001 | no | IMPLEMENTATION |

## Waves (Topological Order)
1. Wave 1: T-001
2. Wave 2: T-002
EOF

# Intentionally mismatched DAG dependency for T-002.
cat > "${TARGET}/tasks/dag-1234-dag-contract-check.json" <<'EOF'
{
  "metadata": {
    "id": "1234",
    "slug": "dag-contract-check",
    "prd": "tasks/prd-1234-dag-contract-check.md",
    "trd": "tasks/trd-1234-dag-contract-check.md",
    "tasks": "tasks/tasks-1234-dag-contract-check.md",
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
      "depends_on": [],
      "parallel_safe": false,
      "stage": "IMPLEMENTATION"
    }
  ]
}
EOF

set +e
(cd "${TARGET}" && bash ./scripts/check.sh --stack python >/dev/null 2>&1)
metadata_mismatch_status=$?
set -e

if [[ "${metadata_mismatch_status}" -eq 0 ]]; then
  echo "[case-12] check passed despite invalid Task DAG metadata path" >&2
  exit 1
fi

perl -0pi -e 's#- Task DAG: `tasks/dag-1234-dag-contract-check-wrong\.json`#- Task DAG: `tasks/dag-1234-dag-contract-check.json`#' \
  "${TARGET}/tasks/tasks-1234-dag-contract-check.md"

# Duplicate DAG task IDs should be rejected by both validator and orchestrator.
cat > "${TARGET}/tasks/dag-1234-dag-contract-check.json" <<'EOF'
{
  "metadata": {
    "id": "1234",
    "slug": "dag-contract-check",
    "prd": "tasks/prd-1234-dag-contract-check.md",
    "trd": "tasks/trd-1234-dag-contract-check.md",
    "tasks": "tasks/tasks-1234-dag-contract-check.md",
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

set +e
(cd "${TARGET}" && bash ./scripts/check.sh --stack python >/dev/null 2>&1)
duplicate_validator_status=$?
set -e

if [[ "${duplicate_validator_status}" -eq 0 ]]; then
  echo "[case-12] check passed despite duplicate DAG task ids" >&2
  exit 1
fi

set +e
bash "${TARGET}/scripts/lead-orchestrate.sh" \
  --project-dir "${TARGET}" \
  --tasks-file "${TARGET}/tasks/tasks-1234-dag-contract-check.md" \
  --dag-file "${TARGET}/tasks/dag-1234-dag-contract-check.json" \
  --plan-only >/dev/null 2>&1
duplicate_orchestrator_status=$?
set -e

if [[ "${duplicate_orchestrator_status}" -eq 0 ]]; then
  echo "[case-12] lead orchestrator accepted duplicate DAG task ids" >&2
  exit 1
fi

# Intentionally mismatched DAG dependency for T-002.
cat > "${TARGET}/tasks/dag-1234-dag-contract-check.json" <<'EOF'
{
  "metadata": {
    "id": "1234",
    "slug": "dag-contract-check",
    "prd": "tasks/prd-1234-dag-contract-check.md",
    "trd": "tasks/trd-1234-dag-contract-check.md",
    "tasks": "tasks/tasks-1234-dag-contract-check.md",
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
      "depends_on": [],
      "parallel_safe": false,
      "stage": "IMPLEMENTATION"
    }
  ]
}
EOF

set +e
(cd "${TARGET}" && bash ./scripts/check.sh --stack python >/dev/null 2>&1)
mismatch_status=$?
set -e

if [[ "${mismatch_status}" -eq 0 ]]; then
  echo "[case-12] check passed despite DAG/task dependency mismatch" >&2
  exit 1
fi

cat > "${TARGET}/tasks/dag-1234-dag-contract-check.json" <<'EOF'
{
  "metadata": {
    "id": "1234",
    "slug": "dag-contract-check",
    "prd": "tasks/prd-1234-dag-contract-check.md",
    "trd": "tasks/trd-1234-dag-contract-check.md",
    "tasks": "tasks/tasks-1234-dag-contract-check.md",
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
