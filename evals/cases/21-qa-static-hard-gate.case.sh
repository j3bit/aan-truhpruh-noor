#!/usr/bin/env bash
set -euo pipefail

ROOT="${EVAL_REPO_ROOT:-$(pwd)}"
TMP_DIR="$(mktemp -d)"
TARGET="${TMP_DIR}/qa-static-hard-gate"
trap 'rm -rf "${TMP_DIR}"' EXIT

bash "${ROOT}/scripts/bootstrap-new-project.sh" \
  --name "qa-static-hard-gate" \
  --stacks python \
  --dest "${TARGET}"

cp "${TARGET}/tasks/templates/prd.template.md" "${TARGET}/tasks/prd-1234-qa-static-hard-gate.md"
cp "${TARGET}/tasks/templates/trd.template.md" "${TARGET}/tasks/trd-1234-qa-static-hard-gate.md"

cat > "${TARGET}/tasks/tasks-1234-qa-static-hard-gate.md" <<'EOF'
# TASKS-1234: qa-static-hard-gate

## Metadata
- File name: `tasks/tasks-1234-qa-static-hard-gate.md`
- PRD: `tasks/prd-1234-qa-static-hard-gate.md`
- TRD: `tasks/trd-1234-qa-static-hard-gate.md`
- Task DAG: `tasks/dag-1234-qa-static-hard-gate.json`
- Task DAG Markdown: `tasks/dag-1234-qa-static-hard-gate.md`
- Planning Artifact: `.blackboard/artifacts/task-planning/1234-qa-static-hard-gate.json`
- Stack Registry: `tasks/stacks.json`

## Task List

### T-001: qa gate validation
- Status: `todo`
- Dependencies: `none`
- Parallel-safe: `no`
- Description:
  - verify QA/static pipeline hard-gate behavior.
- Acceptance Criteria:
  1. static review failure blocks QA pipeline.
- Test Plan:
  1. create a shell convention violation and run qa pipeline.
- Done Definition:
  1. qa pipeline failure is observed and feedback bundle is generated.
EOF

cat > "${TARGET}/tasks/dag-1234-qa-static-hard-gate.md" <<'EOF'
# DAG-1234: qa-static-hard-gate

## Metadata
- File name: `tasks/dag-1234-qa-static-hard-gate.md`
- PRD: `tasks/prd-1234-qa-static-hard-gate.md`
- TRD: `tasks/trd-1234-qa-static-hard-gate.md`
- Tasks: `tasks/tasks-1234-qa-static-hard-gate.md`
- Stack Registry: `tasks/stacks.json`
- Last Updated: 2026-03-01

## Nodes
| Task ID | Depends On | Parallel-safe | Stage |
|---|---|---|---|
| T-001 | none | no | IMPLEMENTATION |

## Waves (Topological Order)
1. Wave 1: T-001
EOF

cat > "${TARGET}/tasks/dag-1234-qa-static-hard-gate.json" <<'EOF'
{
  "metadata": {
    "id": "1234",
    "slug": "qa-static-hard-gate",
    "prd": "tasks/prd-1234-qa-static-hard-gate.md",
    "trd": "tasks/trd-1234-qa-static-hard-gate.md",
    "tasks": "tasks/tasks-1234-qa-static-hard-gate.md",
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

cat > "${TARGET}/scripts/convention-violation.sh" <<'EOF'
#!/usr/bin/env bash
echo "missing strict mode on purpose"
EOF
chmod +x "${TARGET}/scripts/convention-violation.sh"

set +e
bash "${TARGET}/scripts/qa-pipeline.sh" \
  --project-dir "${TARGET}" \
  --stacks auto >/dev/null
qa_status=$?
set -e

if [[ "${qa_status}" -eq 0 ]]; then
  echo "[case-21] qa pipeline unexpectedly succeeded despite static-review violation" >&2
  exit 1
fi

qa_report="${TARGET}/.orchestration/reports/qa-report.json"
static_report="${TARGET}/.orchestration/reports/static-review.json"
feedback_dir="${TARGET}/.blackboard/feedback/qa"

test -f "${qa_report}"
test -f "${static_report}"
test -d "${feedback_dir}"

jq -e '.passed == false and any(.failures[]; test("static-review"))' "${qa_report}" >/dev/null
stack_static_report="$(jq -r '.reports[0].report_path' "${static_report}")"
test -n "${stack_static_report}"
test -f "${stack_static_report}"
jq -e '.passed == false and .checks.conventions.count > 0' "${stack_static_report}" >/dev/null

if ! find "${feedback_dir}" -type f -name 'qa-failure-*.json' -print -quit | grep -q .; then
  echo "[case-21] missing QA feedback bundle artifact" >&2
  exit 1
fi
