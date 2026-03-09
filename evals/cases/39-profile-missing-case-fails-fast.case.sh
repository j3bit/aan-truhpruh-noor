#!/usr/bin/env bash
set -euo pipefail

ROOT="${EVAL_REPO_ROOT:-$(pwd)}"
TMP_DIR="$(mktemp -d)"
TARGET="${TMP_DIR}/profile-missing-case-fails-fast"
trap 'rm -rf "${TMP_DIR}"' EXIT

mkdir -p "${TARGET}/evals/lib" "${TARGET}/evals/cases" "${TARGET}/evals/results"

cp "${ROOT}/evals/run-evals.sh" "${TARGET}/evals/"
cp "${ROOT}/evals/lib/case-profiles.sh" "${TARGET}/evals/lib/"
cp "${ROOT}/evals/cases/01-required-artifacts.case.sh" "${TARGET}/evals/cases/"
cp "${ROOT}/evals/cases/02-contract-trace-rule.case.sh" "${TARGET}/evals/cases/"
cp "${ROOT}/evals/cases/03-gate-filename-enforcement.case.sh" "${TARGET}/evals/cases/"
cp "${ROOT}/evals/cases/04-gate-done-definition-enforcement.case.sh" "${TARGET}/evals/cases/"

set +e
(
  cd "${TARGET}"
  ./evals/run-evals.sh --profile smoke --list-cases
) > "${TMP_DIR}/list.out" 2> "${TMP_DIR}/list.err"
list_status=$?
(
  cd "${TARGET}"
  ./evals/run-evals.sh --profile smoke
) > "${TMP_DIR}/run.out" 2> "${TMP_DIR}/run.err"
run_status=$?
set -e

if [[ "${list_status}" -ne 2 ]]; then
  echo "[case-39] expected --list-cases to fail fast with exit 2" >&2
  cat "${TMP_DIR}/list.out" >&2 || true
  cat "${TMP_DIR}/list.err" >&2 || true
  exit 1
fi

if [[ "${run_status}" -ne 2 ]]; then
  echo "[case-39] expected profile execution to fail fast with exit 2" >&2
  cat "${TMP_DIR}/run.out" >&2 || true
  cat "${TMP_DIR}/run.err" >&2 || true
  exit 1
fi

grep -q "missing case '07-bootstrap-artifact-hygiene.case.sh'" "${TMP_DIR}/list.err"
grep -q "missing case '07-bootstrap-artifact-hygiene.case.sh'" "${TMP_DIR}/run.err"
