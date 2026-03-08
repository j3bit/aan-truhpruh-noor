#!/usr/bin/env bash
set -euo pipefail

ROOT="${EVAL_REPO_ROOT:-$(pwd)}"
TMP_DIR="$(mktemp -d)"
TARGET="${TMP_DIR}/migration-missing-tasks"
LOG_FILE="${TMP_DIR}/migrate.log"
trap 'rm -rf "${TMP_DIR}"' EXIT

mkdir -p "${TARGET}"

set +e
bash "${ROOT}/scripts/migrate-polyglot.sh" --project-dir "${TARGET}" > "${LOG_FILE}" 2>&1
status=$?
set -e

if [[ "${status}" -eq 0 ]]; then
  echo "[case-38] migration unexpectedly succeeded without tasks/" >&2
  cat "${LOG_FILE}" >&2
  exit 1
fi

grep -q "missing tasks directory" "${LOG_FILE}"

if find "${TARGET}" -mindepth 1 -print -quit | grep -q .; then
  echo "[case-38] migration created scaffold files before rejecting missing tasks/" >&2
  find "${TARGET}" -mindepth 1 | sort >&2
  exit 1
fi
