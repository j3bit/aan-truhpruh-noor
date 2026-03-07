#!/usr/bin/env bash
set -euo pipefail

ROOT="${EVAL_REPO_ROOT:-$(pwd)}"
TMP_DIR="$(mktemp -d)"
TARGET="${TMP_DIR}/migration-regression"
trap 'rm -rf "${TMP_DIR}"' EXIT

bash "${ROOT}/scripts/bootstrap-new-project.sh" \
  --name "migration-regression" \
  --stacks python \
  --dest "${TARGET}"

cp "${TARGET}/tasks/templates/prd.template.md" "${TARGET}/tasks/prd-1234-migration-regression.md"
cp "${TARGET}/tasks/templates/trd.template.md" "${TARGET}/tasks/trd-1234-migration-regression.md"

cat > "${TARGET}/tasks/tasks-1234-migration-regression.md" <<'EOF'
# TASKS-1234: migration-regression

## Metadata
- File name: `tasks/tasks-1234-migration-regression.md`
- PRD: `tasks/prd-1234-migration-regression.md`
- TRD: `tasks/trd-1234-migration-regression.md`
- Task DAG: `tasks/dag-1234-migration-regression.json`
- Task DAG Markdown: `tasks/dag-1234-migration-regression.md`
- Planning Artifact: `.blackboard/artifacts/task-planning/1234-migration-regression.json`
- Gate Stack: `python`
- Owner: `eval`
- Last Updated: `2026-03-01`

## Task List

### T-001: migrate old contract
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
EOF

cat > "${TARGET}/tasks/dag-1234-migration-regression.md" <<'EOF'
# DAG-1234: migration-regression

## Metadata
- File name: `tasks/dag-1234-migration-regression.md`
- PRD: `tasks/prd-1234-migration-regression.md`
- TRD: `tasks/trd-1234-migration-regression.md`
- Tasks: `tasks/tasks-1234-migration-regression.md`
- Gate Stack: `python`
- Last Updated: 2026-03-01

## Nodes
| Task ID | Depends On | Parallel-safe | Stage |
|---|---|---|---|
| T-001 | none | no | IMPLEMENTATION |

## Waves (Topological Order)
1. Wave 1: T-001
EOF

cat > "${TARGET}/tasks/dag-1234-migration-regression.json" <<'EOF'
{
  "metadata": {
    "id": "1234",
    "slug": "migration-regression",
    "prd": "tasks/prd-1234-migration-regression.md",
    "trd": "tasks/trd-1234-migration-regression.md",
    "tasks": "tasks/tasks-1234-migration-regression.md",
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

rm -f "${TARGET}/tasks/stacks.json"

bash "${TARGET}/scripts/migrate-polyglot.sh" --project-dir "${TARGET}" --dry-run >/dev/null

if [[ -f "${TARGET}/tasks/tasks-1234-migration-regression.md.bak" ]]; then
  echo "[case-28] dry-run unexpectedly created backup files" >&2
  exit 1
fi

bash "${TARGET}/scripts/migrate-polyglot.sh" --project-dir "${TARGET}" >/dev/null

test -f "${TARGET}/tasks/tasks-1234-migration-regression.md.bak"
test -f "${TARGET}/tasks/dag-1234-migration-regression.md.bak"
test -f "${TARGET}/tasks/dag-1234-migration-regression.json.bak"
test -f "${TARGET}/tasks/stacks.json"

if grep -q "Gate Stack" "${TARGET}/tasks/tasks-1234-migration-regression.md"; then
  echo "[case-28] task metadata still contains Gate Stack after migration" >&2
  exit 1
fi

jq -e '
  .metadata.stack_registry == "tasks/stacks.json" and
  (.nodes[0].gate_stacks | type == "array") and
  (.nodes[0].gate_stacks[0] == "python")
' "${TARGET}/tasks/dag-1234-migration-regression.json" >/dev/null

(cd "${TARGET}" && bash ./scripts/check.sh --stacks auto >/dev/null)
