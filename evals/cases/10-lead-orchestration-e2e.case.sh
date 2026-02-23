#!/usr/bin/env bash
set -euo pipefail

ROOT="${EVAL_REPO_ROOT:-$(pwd)}"
TMP_DIR="$(mktemp -d)"
TARGET="${TMP_DIR}/lead-e2e"
OUT_DIR="${TMP_DIR}/orchestration-out"
PLAN_A="${TMP_DIR}/plan-a"
PLAN_B="${TMP_DIR}/plan-b"
LOG_FILE="${TMP_DIR}/orchestrate.log"

cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

bash "${ROOT}/scripts/bootstrap-new-project.sh" \
  --name "lead-e2e" \
  --stack python \
  --dest "${TARGET}"

cp "${TARGET}/tasks/templates/prd.template.md" "${TARGET}/tasks/prd-1234-lead-e2e.md"

cat > "${TARGET}/tasks/tasks-1234-lead-e2e.md" <<'EOF'
# TASKS-1234: lead-e2e

## Metadata
- File name: `tasks/tasks-1234-lead-e2e.md`
- PRD: `tasks/prd-1234-lead-e2e.md`
- Gate Stack: `python`
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
  3. `./scripts/check.sh --stack python` exits with code `0`.
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
  3. `./scripts/check.sh --stack python` exits with code `0`.
- Notes:
  -
EOF

bash "${TARGET}/scripts/lead-orchestrate.sh" \
  --project-dir "${TARGET}" \
  --tasks-file "${TARGET}/tasks/tasks-1234-lead-e2e.md" \
  --approve \
  --out-dir "${OUT_DIR}" > "${LOG_FILE}"

grep -q "LOOP_COMPLETE" "${LOG_FILE}"

test -f "${OUT_DIR}/plan.jsonl"
test -f "${OUT_DIR}/status.jsonl"
test -f "${OUT_DIR}/summary.json"

jq -e '
  has("task_id") and
  has("dependencies") and
  has("parallel_safe") and
  has("gate_stack") and
  has("risk_level") and
  has("ready")
' "${OUT_DIR}/plan.jsonl" >/dev/null

jq -e '
  has("task_id") and
  has("agent_id") and
  has("status") and
  has("attempt") and
  has("gate_passed") and
  has("pr_review_passed") and
  has("blocked_reason")
' "${OUT_DIR}/status.jsonl" >/dev/null

jq -s -e '
  length == 2 and
  all(.[]; .status == "done" and .gate_passed == true and .pr_review_passed == true)
' "${OUT_DIR}/status.jsonl" >/dev/null

jq -e '.loop_complete == true and .replan_triggered == false and .failed_task == ""' "${OUT_DIR}/summary.json" >/dev/null

# Determinism check for lead planning.
bash "${TARGET}/scripts/lead-orchestrate.sh" \
  --project-dir "${TARGET}" \
  --tasks-file "${TARGET}/tasks/tasks-1234-lead-e2e.md" \
  --plan-only \
  --out-dir "${PLAN_A}" >/dev/null

bash "${TARGET}/scripts/lead-orchestrate.sh" \
  --project-dir "${TARGET}" \
  --tasks-file "${TARGET}/tasks/tasks-1234-lead-e2e.md" \
  --plan-only \
  --out-dir "${PLAN_B}" >/dev/null

cmp "${PLAN_A}/plan.jsonl" "${PLAN_B}/plan.jsonl"
