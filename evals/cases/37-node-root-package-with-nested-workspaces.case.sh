#!/usr/bin/env bash
set -euo pipefail

ROOT="${EVAL_REPO_ROOT:-$(pwd)}"
TMP_DIR="$(mktemp -d)"
TARGET="${TMP_DIR}/node-root-package-workspaces"
trap 'rm -rf "${TMP_DIR}"' EXIT

mkdir -p "${TARGET}/apps/web" "${TARGET}/packages" "${TARGET}/tests"

if ! command -v node >/dev/null 2>&1; then
  echo "[case-37] INFO: node not installed; skipping"
  exit 0
fi

cat > "${TARGET}/package.json" <<'EOF'
{
  "name": "root",
  "private": true
}
EOF

cat > "${TARGET}/apps/web/package.json" <<'EOF'
{
  "name": "web",
  "private": true,
  "scripts": {
    "test": "node missing-file.js"
  }
}
EOF

cat > "${TARGET}/apps/web/index.js" <<'EOF'
console.log("ok");
EOF

set +e
bash "${ROOT}/templates/stacks/node/check.adapter.sh" --project-dir "${TARGET}" > "${TMP_DIR}/adapter.log" 2>&1
status=$?
set -e

if [[ "${status}" -eq 0 ]]; then
  echo "[case-37] node adapter passed despite failing nested workspace test script" >&2
  cat "${TMP_DIR}/adapter.log" >&2
  exit 1
fi

grep -q "package script: test (apps/web)" "${TMP_DIR}/adapter.log"
