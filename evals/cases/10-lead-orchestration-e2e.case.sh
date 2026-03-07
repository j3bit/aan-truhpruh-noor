#!/usr/bin/env bash
set -euo pipefail

ROOT="${EVAL_REPO_ROOT:-$(pwd)}"
TMP_DIR="$(mktemp -d)"
TARGET="${TMP_DIR}/lead-e2e"
OUT_DIR="${TMP_DIR}/orchestration-out"
PLAN_A="${TMP_DIR}/plan-a"
PLAN_B="${TMP_DIR}/plan-b"
LOG_FILE="${TMP_DIR}/orchestrate.log"
WORKER_CMD_FILE="${TMP_DIR}/worker-cmd.sh"

cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

bash "${ROOT}/scripts/bootstrap-new-project.sh" \
  --name "lead-e2e" \
  --stacks python \
  --dest "${TARGET}"

cp "${TARGET}/tasks/templates/prd.template.md" "${TARGET}/tasks/prd-1234-lead-e2e.md"
cp "${TARGET}/tasks/templates/trd.template.md" "${TARGET}/tasks/trd-1234-lead-e2e.md"

cat > "${TARGET}/tasks/tasks-1234-lead-e2e.md" <<'EOF'
# TASKS-1234: lead-e2e

## Metadata
- File name: `tasks/tasks-1234-lead-e2e.md`
- PRD: `tasks/prd-1234-lead-e2e.md`
- TRD: `tasks/trd-1234-lead-e2e.md`
- Task DAG: `tasks/dag-1234-lead-e2e.json`
- Task DAG Markdown: `tasks/dag-1234-lead-e2e.md`
- Planning Artifact: `.blackboard/artifacts/task-planning/1234-lead-e2e.json`
- Stack Registry: `tasks/stacks.json`
- Owner: `lead-e2e`
- Last Updated: `2026-02-23`

## Global Rules
- Execute one task at a time unless explicitly marked parallel-safe.
- Every task must include acceptance criteria and test plan.
- Do not close task before gate passes.

## Task List

### T-001: baseline gate pass
- Status: `todo`
- Dependencies: `none`
- Parallel-safe: `no`
- Description:
  - Validate first task orchestration path.
- Acceptance Criteria:
  1. Orchestrator emits plan/status records for `T-001`.
  2. Gate passes while executing `T-001`.
- Test Plan:
  1. Run lead orchestrator with coordinator approval.
  2. Confirm `T-001` status is `done`.
- Done Definition:
  1. Acceptance criteria are satisfied.
  2. Test plan was executed and evidenced.
  3. `./scripts/check.sh --stacks auto` exits with code `0`.
- Notes:
  -

### T-002: dependency-respecting completion
- Status: `todo`
- Dependencies: `T-001`
- Parallel-safe: `no`
- Description:
  - Validate dependency-aware second task execution.
- Acceptance Criteria:
  1. `T-002` starts only after `T-001` is done.
  2. Orchestrator emits LOOP_COMPLETE after both tasks are done.
- Test Plan:
  1. Run lead orchestrator.
  2. Confirm final summary and status contract fields.
- Done Definition:
  1. Acceptance criteria are satisfied.
  2. Test plan was executed and evidenced.
  3. `./scripts/check.sh --stacks auto` exits with code `0`.
- Notes:
  -
EOF

bash -c "cat > \"${TARGET}/tasks/dag-1234-lead-e2e.md\" <<'EOF'
# DAG-1234: lead-e2e

## Metadata
- File name: \`tasks/dag-1234-lead-e2e.md\`
- PRD: \`tasks/prd-1234-lead-e2e.md\`
- TRD: \`tasks/trd-1234-lead-e2e.md\`
- Tasks: \`tasks/tasks-1234-lead-e2e.md\`
- Stack Registry: \`tasks/stacks.json\`
- Last Updated: 2026-02-23

## Nodes
| Task ID | Depends On | Parallel-safe | Stage |
|---|---|---|---|
| T-001 | none | no | IMPLEMENTATION |
| T-002 | T-001 | no | IMPLEMENTATION |

## Waves (Topological Order)
1. Wave 1: T-001
2. Wave 2: T-002
EOF"

cat > "${TARGET}/tasks/dag-1234-lead-e2e.json" <<'EOF'
{
  "metadata": {
    "id": "1234",
    "slug": "lead-e2e",
    "prd": "tasks/prd-1234-lead-e2e.md",
    "trd": "tasks/trd-1234-lead-e2e.md",
    "tasks": "tasks/tasks-1234-lead-e2e.md",
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
      "depends_on": ["T-001"],
      "parallel_safe": false,
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
  --tasks-file "${TARGET}/tasks/tasks-1234-lead-e2e.md" \
  --dag-file "${TARGET}/tasks/dag-1234-lead-e2e.json" \
  --approve \
  --out-dir "${OUT_DIR}" > "${LOG_FILE}"

grep -q "LOOP_COMPLETE" "${LOG_FILE}"

test -f "${OUT_DIR}/plan.jsonl"
test -f "${OUT_DIR}/status.jsonl"
test -f "${OUT_DIR}/summary.json"
test -f "${TARGET}/.blackboard/events/events.jsonl"
test -f "${TARGET}/.blackboard/integration/waves/wave-1.json"
test -f "${TARGET}/.blackboard/integration/waves/wave-2.json"
test -f "${TARGET}/.blackboard/jobs/T-001.json"
test -f "${TARGET}/.blackboard/jobs/T-002.json"

jq -e '
  has("task_id") and
  has("dependencies") and
  has("parallel_safe") and
  has("gate_stacks") and
  has("risk_level") and
  has("ready") and
  has("stage") and
  has("wave")
' "${OUT_DIR}/plan.jsonl" >/dev/null

jq -e '
  has("task_id") and
  has("agent_id") and
  has("status") and
  has("attempt") and
  has("gate_passed") and
  has("pr_review_passed") and
  has("blocked_reason") and
  has("stage") and
  has("wave") and
  has("profile") and
  has("profile_fallback")
' "${OUT_DIR}/status.jsonl" >/dev/null

jq -s -e '
  length == 2 and
  all(.[]; .status == "done" and .gate_passed == true and .pr_review_passed == true)
' "${OUT_DIR}/status.jsonl" >/dev/null

jq -e '.loop_complete == true and .replan_triggered == false and .failed_task == "" and .qa_feedback_processed == 0' "${OUT_DIR}/summary.json" >/dev/null

# Determinism check for lead planning.
bash "${TARGET}/scripts/lead-orchestrate.sh" \
  --project-dir "${TARGET}" \
  --tasks-file "${TARGET}/tasks/tasks-1234-lead-e2e.md" \
  --dag-file "${TARGET}/tasks/dag-1234-lead-e2e.json" \
  --plan-only \
  --out-dir "${PLAN_A}" >/dev/null

bash "${TARGET}/scripts/lead-orchestrate.sh" \
  --project-dir "${TARGET}" \
  --tasks-file "${TARGET}/tasks/tasks-1234-lead-e2e.md" \
  --dag-file "${TARGET}/tasks/dag-1234-lead-e2e.json" \
  --plan-only \
  --out-dir "${PLAN_B}" >/dev/null

cmp "${PLAN_A}/plan.jsonl" "${PLAN_B}/plan.jsonl"
