#!/usr/bin/env bash
set -euo pipefail

ROOT="${EVAL_REPO_ROOT:-$(pwd)}"
TMP_DIR="$(mktemp -d)"
RETRY_CASES_DIR="${TMP_DIR}/retry-cases"
RETRY_RESULTS_DIR="${TMP_DIR}/retry-results"
UNEXPECTED_CASES_DIR="${TMP_DIR}/unexpected-cases"
UNEXPECTED_RESULTS_DIR="${TMP_DIR}/unexpected-results"
UNEXPECTED_MARKER="${ROOT}/.evals-case6-unexpected.tmp"

cleanup() {
  rm -rf "${TMP_DIR}"
  rm -f "${UNEXPECTED_MARKER}"
}
trap cleanup EXIT

mkdir -p "${RETRY_CASES_DIR}" "${RETRY_RESULTS_DIR}" "${UNEXPECTED_CASES_DIR}" "${UNEXPECTED_RESULTS_DIR}"

cat > "${RETRY_CASES_DIR}/01-retry-thrash.case.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

cat > "${EVAL_META_PATH}" <<'JSON'
{"loop_count":1,"retries":99,"skill_triggered":false}
JSON
EOF
chmod +x "${RETRY_CASES_DIR}/01-retry-thrash.case.sh"

set +e
bash "${ROOT}/evals/run-evals.sh" \
  --trace-mode local-only \
  --max-retries 3 \
  --cases-dir "${RETRY_CASES_DIR}" \
  --results-dir "${RETRY_RESULTS_DIR}" >/dev/null 2>&1
retry_status=$?
set -e

if [[ "${retry_status}" -eq 0 ]]; then
  echo "[case-06] nested eval unexpectedly passed for retry threshold case" >&2
  exit 1
fi

retry_result_file="$(ls -1 "${RETRY_RESULTS_DIR}"/*.jsonl | tail -n 1)"
jq -e '(.passed == false) and (.retries > 3)' "${retry_result_file}" >/dev/null

cat > "${UNEXPECTED_CASES_DIR}/01-unexpected-files.case.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

touch "${EVAL_REPO_ROOT}/.evals-case6-unexpected.tmp"
cat > "${EVAL_META_PATH}" <<'JSON'
{"loop_count":0,"retries":0,"skill_triggered":false}
JSON
EOF
chmod +x "${UNEXPECTED_CASES_DIR}/01-unexpected-files.case.sh"

set +e
bash "${ROOT}/evals/run-evals.sh" \
  --trace-mode local-only \
  --cases-dir "${UNEXPECTED_CASES_DIR}" \
  --results-dir "${UNEXPECTED_RESULTS_DIR}" >/dev/null 2>&1
unexpected_status=$?
set -e

if [[ "${unexpected_status}" -eq 0 ]]; then
  echo "[case-06] nested eval unexpectedly passed for unexpected-files case" >&2
  exit 1
fi

unexpected_result_file="$(ls -1 "${UNEXPECTED_RESULTS_DIR}"/*.jsonl | tail -n 1)"
jq -e '(.passed == false) and (.unexpected_files > 0)' "${unexpected_result_file}" >/dev/null
