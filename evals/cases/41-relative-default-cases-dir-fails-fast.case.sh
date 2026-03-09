#!/usr/bin/env bash
set -euo pipefail

ROOT="${EVAL_REPO_ROOT:-$(pwd)}"
TMP_DIR="$(mktemp -d)"
TARGET="${TMP_DIR}/relative-default-cases-dir-fails-fast"
trap 'rm -rf "${TMP_DIR}"' EXIT

mkdir -p "${TARGET}/evals/lib" "${TARGET}/evals/cases" "${TARGET}/evals/results"

cp "${ROOT}/evals/run-evals.sh" "${TARGET}/evals/"
cp "${ROOT}/evals/lib/case-profiles.sh" "${TARGET}/evals/lib/"
cp "${ROOT}"/evals/cases/*.case.sh "${TARGET}/evals/cases/"

cat > "${TARGET}/evals/cases/99-temp.case.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 0
EOF
chmod +x "${TARGET}/evals/cases/99-temp.case.sh"

set +e
(
  cd "${TARGET}"
  ./evals/run-evals.sh --profile smoke --cases-dir ./evals/cases --list-cases
) > "${TMP_DIR}/list.out" 2> "${TMP_DIR}/list.err"
list_status=$?
(
  cd "${TARGET}"
  ./evals/run-evals.sh --profile smoke --cases-dir ./evals/cases
) > "${TMP_DIR}/run.out" 2> "${TMP_DIR}/run.err"
run_status=$?
set -e

if [[ "${list_status}" -ne 2 ]]; then
  echo "[case-41] expected --list-cases to fail for relative default cases-dir" >&2
  cat "${TMP_DIR}/list.out" >&2 || true
  cat "${TMP_DIR}/list.err" >&2 || true
  exit 1
fi

if [[ "${run_status}" -ne 2 ]]; then
  echo "[case-41] expected profile execution to fail for relative default cases-dir" >&2
  cat "${TMP_DIR}/run.out" >&2 || true
  cat "${TMP_DIR}/run.err" >&2 || true
  exit 1
fi

grep -q "unprofiled eval cases found" "${TMP_DIR}/list.err"
grep -q "99-temp.case.sh" "${TMP_DIR}/list.err"
grep -q "unprofiled eval cases found" "${TMP_DIR}/run.err"
grep -q "99-temp.case.sh" "${TMP_DIR}/run.err"
