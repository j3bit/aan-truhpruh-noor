#!/usr/bin/env bash
set -euo pipefail

ROOT="${EVAL_REPO_ROOT:-$(pwd)}"
TMP_DIR="$(mktemp -d)"
TARGET="${TMP_DIR}/profile-fallback"
OUT_DIR="${TMP_DIR}/orchestration-out"
TMP_HOME="${TMP_DIR}/home-no-fast"
WORKER_CMD_FILE="${TMP_DIR}/worker-cmd.sh"
trap 'rm -rf "${TMP_DIR}"' EXIT

mkdir -p "${TMP_HOME}"

bash "${ROOT}/scripts/bootstrap-new-project.sh" \
  --name "profile-fallback" \
  --stack python \
  --dest "${TARGET}"

cp "${TARGET}/tasks/templates/prd.template.md" "${TARGET}/tasks/prd-1234-profile-fallback.md"
cp "${TARGET}/tasks/templates/trd.template.md" "${TARGET}/tasks/trd-1234-profile-fallback.md"

cat > "${TARGET}/tasks/tasks-1234-profile-fallback.md" <<'EOF'
# TASKS-1234: profile-fallback

## Metadata
- File name: `tasks/tasks-1234-profile-fallback.md`
- PRD: `tasks/prd-1234-profile-fallback.md`
- TRD: `tasks/trd-1234-profile-fallback.md`
- Task DAG: `tasks/dag-1234-profile-fallback.json`
- Task DAG Markdown: `tasks/dag-1234-profile-fallback.md`
- Planning Artifact: `.blackboard/artifacts/task-planning/1234-profile-fallback.json`
- Gate Stack: `python`
- Owner: `eval`
- Last Updated: `2026-02-27`

## Task List

### T-001: profile selection
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

cat > "${TARGET}/tasks/dag-1234-profile-fallback.md" <<'EOF'
# DAG-1234: profile-fallback

## Metadata
- File name: `tasks/dag-1234-profile-fallback.md`
- PRD: `tasks/prd-1234-profile-fallback.md`
- TRD: `tasks/trd-1234-profile-fallback.md`
- Tasks: `tasks/tasks-1234-profile-fallback.md`
- Gate Stack: `python`
- Last Updated: 2026-02-27

## Nodes
| Task ID | Depends On | Parallel-safe | Stage |
|---|---|---|---|
| T-001 | none | no | IMPLEMENTATION |

## Waves (Topological Order)
1. Wave 1: T-001
EOF

cat > "${TARGET}/tasks/dag-1234-profile-fallback.json" <<'EOF'
{
  "metadata": {
    "id": "1234",
    "slug": "profile-fallback",
    "prd": "tasks/prd-1234-profile-fallback.md",
    "trd": "tasks/trd-1234-profile-fallback.md",
    "tasks": "tasks/tasks-1234-profile-fallback.md",
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
  "profile_fallback": ${ORCH_PROFILE_FALLBACK:-true},
  "duration_sec": 1,
  "worker_backend": "custom-command"
}
EOF_JSON
EOF
chmod +x "${WORKER_CMD_FILE}"

HOME="${TMP_HOME}" ORCH_WORKER_CMD="${WORKER_CMD_FILE}" bash "${TARGET}/scripts/lead-orchestrate.sh" \
  --project-dir "${TARGET}" \
  --tasks-file "${TARGET}/tasks/tasks-1234-profile-fallback.md" \
  --dag-file "${TARGET}/tasks/dag-1234-profile-fallback.json" \
  --approve \
  --out-dir "${OUT_DIR}" >/dev/null

jq -e '.selected_profile == "default" and .fallback == true' "${TARGET}/.blackboard/state/profile-selection.json" >/dev/null
jq -s -e 'all(.[]; .profile == "default" and .profile_fallback == true)' "${OUT_DIR}/status.jsonl" >/dev/null
