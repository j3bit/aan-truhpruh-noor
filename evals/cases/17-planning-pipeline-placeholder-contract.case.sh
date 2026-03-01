#!/usr/bin/env bash
set -euo pipefail

ROOT="${EVAL_REPO_ROOT:-$(pwd)}"
TMP_DIR="$(mktemp -d)"
TARGET="${TMP_DIR}/planning-placeholder-contract"
trap 'rm -rf "${TMP_DIR}"' EXIT

bash "${ROOT}/scripts/bootstrap-new-project.sh" \
  --name "planning-placeholder-contract" \
  --stacks python \
  --dest "${TARGET}"

(cd "${TARGET}" && bash ./scripts/validate-contracts.sh --project-dir . >/dev/null)

mv "${TARGET}/.agents/skills/ideation-consultant/SKILL.md" \
  "${TARGET}/.agents/skills/ideation-consultant/SKILL.md.bak"

set +e
(cd "${TARGET}" && bash ./scripts/validate-contracts.sh --project-dir . >/dev/null 2>&1)
missing_skill_status=$?
set -e

if [[ "${missing_skill_status}" -eq 0 ]]; then
  echo "[case-17] contract validation passed despite missing ideation placeholder skill" >&2
  exit 1
fi

mv "${TARGET}/.agents/skills/ideation-consultant/SKILL.md.bak" \
  "${TARGET}/.agents/skills/ideation-consultant/SKILL.md"

mv "${TARGET}/tasks/contracts/blackboard/ideation-output.schema.json" \
  "${TARGET}/tasks/contracts/blackboard/ideation-output.schema.json.bak"

set +e
(cd "${TARGET}" && bash ./scripts/validate-contracts.sh --project-dir . >/dev/null 2>&1)
missing_schema_status=$?
set -e

if [[ "${missing_schema_status}" -eq 0 ]]; then
  echo "[case-17] contract validation passed despite missing ideation schema" >&2
  exit 1
fi
