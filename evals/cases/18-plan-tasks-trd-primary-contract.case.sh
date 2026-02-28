#!/usr/bin/env bash
set -euo pipefail

ROOT="${EVAL_REPO_ROOT:-$(pwd)}"
TMP_DIR="$(mktemp -d)"
TARGET="${TMP_DIR}/plan-tasks-trd-primary"
trap 'rm -rf "${TMP_DIR}"' EXIT

bash "${ROOT}/scripts/bootstrap-new-project.sh" \
  --name "plan-tasks-trd-primary" \
  --stack python \
  --dest "${TARGET}"

PLAN_SKILL="${TARGET}/.agents/skills/plan-tasks/SKILL.md"
PLAN_REF="${TARGET}/.agents/skills/plan-tasks/references/tasks-contract.md"

grep -Fq 'Source TRD path (`tasks/trd-<4digit>-<slug>.md`) as the primary input.' "${PLAN_SKILL}"
grep -Fq "Read source TRD first and use it as the decomposition source of truth." "${PLAN_SKILL}"
grep -Fq "Read source PRD only for goals/non-goals/constraints checks" "${PLAN_SKILL}"
grep -Fq "Use TRD as the primary decomposition input" "${PLAN_REF}"
