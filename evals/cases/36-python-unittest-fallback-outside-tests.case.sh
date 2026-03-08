#!/usr/bin/env bash
set -euo pipefail

ROOT="${EVAL_REPO_ROOT:-$(pwd)}"
TMP_DIR="$(mktemp -d)"
TARGET="${TMP_DIR}/python-unittest-fallback"
TOOLS_DIR="${TMP_DIR}/tools"
trap 'rm -rf "${TMP_DIR}"' EXIT

mkdir -p "${TARGET}/apps/app" "${TARGET}/packages" "${TARGET}/tests" "${TOOLS_DIR}"

if command -v python3 >/dev/null 2>&1; then
  ln -s "$(command -v python3)" "${TOOLS_DIR}/python3"
elif command -v python >/dev/null 2>&1; then
  ln -s "$(command -v python)" "${TOOLS_DIR}/python"
else
  echo "[case-36] INFO: python not installed; skipping"
  exit 0
fi

if command -v ruff >/dev/null 2>&1; then
  ln -s "$(command -v ruff)" "${TOOLS_DIR}/ruff"
fi

cat > "${TARGET}/apps/app/test_failure.py" <<'EOF'
import unittest


class FailingTest(unittest.TestCase):
    def test_fail(self) -> None:
        self.assertEqual(1, 2)
EOF

set +e
PATH="${TOOLS_DIR}:/usr/bin:/bin" bash "${ROOT}/templates/stacks/python/check.adapter.sh" --project-dir "${TARGET}" > "${TMP_DIR}/adapter.log" 2>&1
status=$?
set -e

if [[ "${status}" -eq 0 ]]; then
  echo "[case-36] python adapter passed despite failing unittest outside tests/" >&2
  cat "${TMP_DIR}/adapter.log" >&2
  exit 1
fi

grep -q "unittest discovery (apps/app, test\\*.py)" "${TMP_DIR}/adapter.log"
grep -q "FAILED (failures=1)" "${TMP_DIR}/adapter.log"
