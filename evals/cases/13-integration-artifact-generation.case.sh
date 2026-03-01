#!/usr/bin/env bash
set -euo pipefail

ROOT="${EVAL_REPO_ROOT:-$(pwd)}"
TMP_DIR="$(mktemp -d)"
TARGET="${TMP_DIR}/integration-artifacts"
OUT_DIR="${TMP_DIR}/orchestration-out"
WORKER_CMD_FILE="${TMP_DIR}/worker-cmd.sh"
trap 'rm -rf "${TMP_DIR}"' EXIT

bash "${ROOT}/scripts/bootstrap-new-project.sh" \
  --name "integration-artifacts" \
  --stack python \
  --dest "${TARGET}"

cp "${TARGET}/tasks/templates/prd.template.md" "${TARGET}/tasks/prd-1234-integration-artifacts.md"
cp "${TARGET}/tasks/templates/trd.template.md" "${TARGET}/tasks/trd-1234-integration-artifacts.md"

cat > "${TARGET}/tasks/tasks-1234-integration-artifacts.md" <<'EOF'
# TASKS-1234: integration-artifacts

## Metadata
- File name: `tasks/tasks-1234-integration-artifacts.md`
- PRD: `tasks/prd-1234-integration-artifacts.md`
- TRD: `tasks/trd-1234-integration-artifacts.md`
- Task DAG: `tasks/dag-1234-integration-artifacts.json`
- Task DAG Markdown: `tasks/dag-1234-integration-artifacts.md`
- Planning Artifact: `.blackboard/artifacts/task-planning/1234-integration-artifacts.json`
- Gate Stack: `python`
- Owner: `eval`
- Last Updated: `2026-02-27`

## Task List

### T-001: integration artifact emission
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

cat > "${TARGET}/tasks/dag-1234-integration-artifacts.md" <<'EOF'
# DAG-1234: integration-artifacts

## Metadata
- File name: `tasks/dag-1234-integration-artifacts.md`
- PRD: `tasks/prd-1234-integration-artifacts.md`
- TRD: `tasks/trd-1234-integration-artifacts.md`
- Tasks: `tasks/tasks-1234-integration-artifacts.md`
- Gate Stack: `python`
- Last Updated: 2026-02-27

## Nodes
| Task ID | Depends On | Parallel-safe | Stage |
|---|---|---|---|
| T-001 | none | no | IMPLEMENTATION |

## Waves (Topological Order)
1. Wave 1: T-001
EOF

cat > "${TARGET}/tasks/dag-1234-integration-artifacts.json" <<'EOF'
{
  "metadata": {
    "id": "1234",
    "slug": "integration-artifacts",
    "prd": "tasks/prd-1234-integration-artifacts.md",
    "trd": "tasks/trd-1234-integration-artifacts.md",
    "tasks": "tasks/tasks-1234-integration-artifacts.md",
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

cat > "${WORKER_CMD_FILE}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cat > "${ORCH_RESULT_FILE}" <<EOF_JSON
{
  "task_id": "${ORCH_TASK_ID}",
  "exit_code": 0,
  "gate_passed": true,
  "pr_review_passed": true,
  "profile": "${ORCH_PROFILE:-default}",
  "profile_fallback": false,
  "duration_sec": 1,
  "worker_backend": "custom-command"
}
EOF_JSON
EOF
chmod +x "${WORKER_CMD_FILE}"

ORCH_WORKER_CMD="${WORKER_CMD_FILE}" \
bash "${TARGET}/scripts/lead-orchestrate.sh" \
  --project-dir "${TARGET}" \
  --tasks-file "${TARGET}/tasks/tasks-1234-integration-artifacts.md" \
  --dag-file "${TARGET}/tasks/dag-1234-integration-artifacts.json" \
  --approve \
  --out-dir "${OUT_DIR}" >/dev/null

test -f "${TARGET}/.blackboard/integration/waves/wave-1.json"
test -f "${TARGET}/.blackboard/integration/tasks/T-001.json"
test -f "${TARGET}/.blackboard/jobs/T-001.json"

grep -q '"type":"INTEGRATION_DIRECTIVE_PUBLISHED"' "${TARGET}/.blackboard/events/events.jsonl"
grep -q '"type":"ARTIFACT_PUBLISHED"' "${TARGET}/.blackboard/events/events.jsonl"
