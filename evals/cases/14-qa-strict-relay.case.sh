#!/usr/bin/env bash
set -euo pipefail

ROOT="${EVAL_REPO_ROOT:-$(pwd)}"
TMP_DIR="$(mktemp -d)"
TARGET="${TMP_DIR}/qa-relay"
OUT_DIR="${TMP_DIR}/orchestration-out"
trap 'rm -rf "${TMP_DIR}"' EXIT

bash "${ROOT}/scripts/bootstrap-new-project.sh" \
  --name "qa-relay" \
  --stack python \
  --dest "${TARGET}"

cp "${TARGET}/tasks/templates/prd.template.md" "${TARGET}/tasks/prd-1234-qa-relay.md"
cp "${TARGET}/tasks/templates/trd.template.md" "${TARGET}/tasks/trd-1234-qa-relay.md"

cat > "${TARGET}/tasks/tasks-1234-qa-relay.md" <<'EOF'
# TASKS-1234: qa-relay

## Metadata
- File name: `tasks/tasks-1234-qa-relay.md`
- PRD: `tasks/prd-1234-qa-relay.md`
- TRD: `tasks/trd-1234-qa-relay.md`
- Task DAG: `tasks/dag-1234-qa-relay.json`
- Task DAG Markdown: `tasks/dag-1234-qa-relay.md`
- Planning Artifact: `.blackboard/artifacts/task-planning/1234-qa-relay.json`
- Gate Stack: `python`
- Owner: `eval`
- Last Updated: `2026-02-27`

## Task List

### T-001: relay check
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

cat > "${TARGET}/tasks/dag-1234-qa-relay.md" <<'EOF'
# DAG-1234: qa-relay

## Metadata
- File name: `tasks/dag-1234-qa-relay.md`
- PRD: `tasks/prd-1234-qa-relay.md`
- TRD: `tasks/trd-1234-qa-relay.md`
- Tasks: `tasks/tasks-1234-qa-relay.md`
- Gate Stack: `python`
- Last Updated: 2026-02-27

## Nodes
| Task ID | Depends On | Parallel-safe | Stage |
|---|---|---|---|
| T-001 | none | no | IMPLEMENTATION |

## Waves (Topological Order)
1. Wave 1: T-001
EOF

cat > "${TARGET}/tasks/dag-1234-qa-relay.json" <<'EOF'
{
  "metadata": {
    "id": "1234",
    "slug": "qa-relay",
    "prd": "tasks/prd-1234-qa-relay.md",
    "trd": "tasks/trd-1234-qa-relay.md",
    "tasks": "tasks/tasks-1234-qa-relay.md",
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

mkdir -p "${TARGET}/.blackboard/feedback/qa"
cat > "${TARGET}/.blackboard/feedback/qa/failure-1.json" <<'EOF'
{
  "id": "qa-001",
  "failed_test": "integration:test-suite",
  "error_log": "simulated failure",
  "task_id": "T-001"
}
EOF

set +e
bash "${TARGET}/scripts/lead-orchestrate.sh" \
  --project-dir "${TARGET}" \
  --tasks-file "${TARGET}/tasks/tasks-1234-qa-relay.md" \
  --dag-file "${TARGET}/tasks/dag-1234-qa-relay.json" \
  --approve \
  --out-dir "${OUT_DIR}" >/dev/null
orchestrate_status=$?
set -e

if [[ "${orchestrate_status}" -eq 0 ]]; then
  echo "[case-14] orchestration unexpectedly reported success despite QA replan trigger" >&2
  exit 1
fi

events_file="${TARGET}/.blackboard/events/events.jsonl"
jq -s -e 'any(.[]; .type == "QA_FAILURE_REPORTED" and .from_stage == "QA" and .to_stage == "IMPLEMENTATION")' "${events_file}" >/dev/null
jq -s -e 'any(.[]; .type == "SELF_HEAL_REPLAN_REQUESTED" and .from_stage == "IMPLEMENTATION" and .to_stage == "ORCHESTRATION")' "${events_file}" >/dev/null
jq -s -e 'any(.[]; .from_stage == "QA" and .to_stage == "ORCHESTRATION" and .status == "accepted") | not' "${events_file}" >/dev/null

# Ensure JSONL framing remains one event per line even with pretty payload input.
while IFS= read -r line; do
  jq -e . >/dev/null <<<"${line}"
done < "${events_file}"

jq -e '.replan_triggered == true and .qa_feedback_processed > 0 and .loop_complete == false' "${OUT_DIR}/summary.json" >/dev/null
