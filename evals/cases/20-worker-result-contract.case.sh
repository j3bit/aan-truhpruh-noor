#!/usr/bin/env bash
set -euo pipefail

ROOT="${EVAL_REPO_ROOT:-$(pwd)}"
TMP_DIR="$(mktemp -d)"
TARGET="${TMP_DIR}/worker-result-contract"
OUT_DIR="${TMP_DIR}/orchestration-out"
WORKER_CMD_FILE="${TMP_DIR}/worker-cmd.sh"
trap 'rm -rf "${TMP_DIR}"' EXIT

bash "${ROOT}/scripts/bootstrap-new-project.sh" \
  --name "worker-result-contract" \
  --stacks python \
  --dest "${TARGET}"

cp "${TARGET}/tasks/templates/prd.template.md" "${TARGET}/tasks/prd-1234-worker-result-contract.md"
cp "${TARGET}/tasks/templates/trd.template.md" "${TARGET}/tasks/trd-1234-worker-result-contract.md"

cat > "${TARGET}/tasks/tasks-1234-worker-result-contract.md" <<'EOF'
# TASKS-1234: worker-result-contract

## Metadata
- File name: `tasks/tasks-1234-worker-result-contract.md`
- PRD: `tasks/prd-1234-worker-result-contract.md`
- TRD: `tasks/trd-1234-worker-result-contract.md`
- Task DAG: `tasks/dag-1234-worker-result-contract.json`
- Task DAG Markdown: `tasks/dag-1234-worker-result-contract.md`
- Planning Artifact: `.blackboard/artifacts/task-planning/1234-worker-result-contract.json`
- Stack Registry: `tasks/stacks.json`

## Task List

### T-001: worker result contract
- Status: `todo`
- Dependencies: `none`
- Parallel-safe: `yes`
- Description:
  - verify worker result artifact contract shape.
- Acceptance Criteria:
  1. worker result contract file is emitted.
- Test Plan:
  1. run orchestrator with deterministic worker command.
- Done Definition:
  1. plan and status contracts are valid.
EOF

cat > "${TARGET}/tasks/dag-1234-worker-result-contract.md" <<'EOF'
# DAG-1234: worker-result-contract

## Metadata
- File name: `tasks/dag-1234-worker-result-contract.md`
- PRD: `tasks/prd-1234-worker-result-contract.md`
- TRD: `tasks/trd-1234-worker-result-contract.md`
- Tasks: `tasks/tasks-1234-worker-result-contract.md`
- Stack Registry: `tasks/stacks.json`
- Last Updated: 2026-03-01

## Nodes
| Task ID | Depends On | Parallel-safe | Stage |
|---|---|---|---|
| T-001 | none | yes | IMPLEMENTATION |

## Waves (Topological Order)
1. Wave 1: T-001
EOF

cat > "${TARGET}/tasks/dag-1234-worker-result-contract.json" <<'EOF'
{
  "metadata": {
    "id": "1234",
    "slug": "worker-result-contract",
    "prd": "tasks/prd-1234-worker-result-contract.md",
    "trd": "tasks/trd-1234-worker-result-contract.md",
    "tasks": "tasks/tasks-1234-worker-result-contract.md",
    "stack_registry": "tasks/stacks.json"
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
  --tasks-file "${TARGET}/tasks/tasks-1234-worker-result-contract.md" \
  --dag-file "${TARGET}/tasks/dag-1234-worker-result-contract.json" \
  --approve \
  --max-parallel-workers 2 \
  --worker-timeout-seconds 120 \
  --out-dir "${OUT_DIR}" >/dev/null

result_file="${OUT_DIR}/workers/T-001.result.json"
status_file="${OUT_DIR}/status.jsonl"
summary_file="${OUT_DIR}/summary.json"

test -f "${result_file}"
test -f "${status_file}"
test -f "${summary_file}"

jq -e '
  has("task_id") and
  has("exit_code") and
  has("gate_passed") and
  has("pr_review_passed") and
  has("profile") and
  has("profile_fallback") and
  has("duration_sec") and
  has("worker_backend")
' "${result_file}" >/dev/null

jq -e '
  has("worker_backend") and
  has("duration_sec") and
  has("result_file")
' "${status_file}" >/dev/null

jq -e '.max_parallel_workers == 2 and .worker_timeout_seconds == 120 and .loop_complete == true' "${summary_file}" >/dev/null
