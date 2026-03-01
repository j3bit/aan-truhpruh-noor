#!/usr/bin/env bash
set -euo pipefail

ROOT="${EVAL_REPO_ROOT:-$(pwd)}"
WORKFLOW_FILE="${ROOT}/.github/workflows/check.yml"

test -f "${WORKFLOW_FILE}"

section_has_need() {
  local section="$1"
  local need="$2"
  local file="$3"

  awk -v section="${section}" -v need="${need}" '
    $0 == "  " section ":" { in_section = 1; next }
    in_section && $0 ~ /^  [^[:space:]].*:/ { in_section = 0 }
    in_section && $0 ~ "needs:[[:space:]]*" need "$" { found = 1 }
    END { exit(found ? 0 : 1) }
  ' "${file}"
}

if ! section_has_need "qa-and-static" "quality-gate" "${WORKFLOW_FILE}"; then
  echo "[case-22] qa-and-static must depend on quality-gate" >&2
  exit 1
fi

if ! section_has_need "release-readiness" "qa-and-static" "${WORKFLOW_FILE}"; then
  echo "[case-22] release-readiness must depend on qa-and-static" >&2
  exit 1
fi

if ! grep -Fq "./scripts/qa-pipeline.sh" "${WORKFLOW_FILE}"; then
  echo "[case-22] qa pipeline command missing" >&2
  exit 1
fi

if ! grep -Fq "actions/upload-artifact@v4" "${WORKFLOW_FILE}"; then
  echo "[case-22] artifact upload step missing" >&2
  exit 1
fi

if ! grep -Fq "release-readiness.json" "${WORKFLOW_FILE}"; then
  echo "[case-22] release-readiness report artifact missing" >&2
  exit 1
fi
