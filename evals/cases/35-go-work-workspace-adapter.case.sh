#!/usr/bin/env bash
set -euo pipefail

ROOT="${EVAL_REPO_ROOT:-$(pwd)}"
TMP_DIR="$(mktemp -d)"
TARGET="${TMP_DIR}/go-work-workspace"
trap 'rm -rf "${TMP_DIR}"' EXIT

if ! command -v go >/dev/null 2>&1; then
  echo "[case-35] INFO: go not installed; skipping"
  exit 0
fi

mkdir -p "${TARGET}/apps/\$(printf injected)"

cat > "${TARGET}/go.work" <<'EOF'
go 1.22

use "./apps/$(printf injected)"
EOF

cat > "${TARGET}/apps/\$(printf injected)/go.mod" <<'EOF'
module example.com/injected

go 1.22
EOF

cat > "${TARGET}/apps/\$(printf injected)/main.go" <<'EOF'
package main

func main() {}
EOF

bash "${ROOT}/templates/stacks/go/check.adapter.sh" --project-dir "${TARGET}" > "${TMP_DIR}/adapter.log"

grep -q 'go test ./... (./apps/$(printf injected))' "${TMP_DIR}/adapter.log"
grep -q 'go vet ./... (./apps/$(printf injected))' "${TMP_DIR}/adapter.log"
