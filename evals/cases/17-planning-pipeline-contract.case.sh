#!/usr/bin/env bash
set -euo pipefail

ROOT="${EVAL_REPO_ROOT:-$(pwd)}"
TMP_DIR="$(mktemp -d)"
TARGET="${TMP_DIR}/planning-pipeline-contract"
trap 'rm -rf "${TMP_DIR}"' EXIT

bash "${ROOT}/scripts/bootstrap-new-project.sh" \
  --name "planning-pipeline-contract" \
  --stacks python \
  --dest "${TARGET}"

(cd "${TARGET}" && bash ./scripts/validate-contracts.sh --project-dir . >/dev/null)

mv "${TARGET}/.agents/skills/develop-concept/SKILL.md" \
  "${TARGET}/.agents/skills/develop-concept/SKILL.md.bak"

set +e
(cd "${TARGET}" && bash ./scripts/validate-contracts.sh --project-dir . >/dev/null 2>&1)
missing_skill_status=$?
set -e

if [[ "${missing_skill_status}" -eq 0 ]]; then
  echo "[case-17] contract validation passed despite missing develop-concept skill" >&2
  exit 1
fi

mv "${TARGET}/.agents/skills/develop-concept/SKILL.md.bak" \
  "${TARGET}/.agents/skills/develop-concept/SKILL.md"

mv "${TARGET}/.agents/skills/develop-concept/references/concept-contract.md" \
  "${TARGET}/.agents/skills/develop-concept/references/concept-contract.md.bak"

set +e
(cd "${TARGET}" && bash ./scripts/validate-contracts.sh --project-dir . >/dev/null 2>&1)
missing_reference_status=$?
set -e

if [[ "${missing_reference_status}" -eq 0 ]]; then
  echo "[case-17] contract validation passed despite missing develop-concept reference" >&2
  exit 1
fi

mv "${TARGET}/.agents/skills/develop-concept/references/concept-contract.md.bak" \
  "${TARGET}/.agents/skills/develop-concept/references/concept-contract.md"

mv "${TARGET}/.agents/skills/create-trd/SKILL.md" \
  "${TARGET}/.agents/skills/create-trd/SKILL.md.bak"

set +e
(cd "${TARGET}" && bash ./scripts/validate-contracts.sh --project-dir . >/dev/null 2>&1)
missing_create_trd_status=$?
set -e

if [[ "${missing_create_trd_status}" -eq 0 ]]; then
  echo "[case-17] contract validation passed despite missing create-trd skill" >&2
  exit 1
fi

mv "${TARGET}/.agents/skills/create-trd/SKILL.md.bak" \
  "${TARGET}/.agents/skills/create-trd/SKILL.md"

mv "${TARGET}/.agents/skills/create-trd/references/trd-contract.md" \
  "${TARGET}/.agents/skills/create-trd/references/trd-contract.md.bak"

set +e
(cd "${TARGET}" && bash ./scripts/validate-contracts.sh --project-dir . >/dev/null 2>&1)
missing_create_trd_reference_status=$?
set -e

if [[ "${missing_create_trd_reference_status}" -eq 0 ]]; then
  echo "[case-17] contract validation passed despite missing create-trd reference" >&2
  exit 1
fi

mv "${TARGET}/.agents/skills/create-trd/references/trd-contract.md.bak" \
  "${TARGET}/.agents/skills/create-trd/references/trd-contract.md"

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

mv "${TARGET}/tasks/contracts/blackboard/ideation-output.schema.json.bak" \
  "${TARGET}/tasks/contracts/blackboard/ideation-output.schema.json"

echo "[case-17] PASS"
