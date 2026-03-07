#!/usr/bin/env bash
set -euo pipefail

ROOT="${EVAL_REPO_ROOT:-$(pwd)}"
TMP_DIR="$(mktemp -d)"
TARGET="${TMP_DIR}/owned-path-comma-glob-selection"
LOG_FILE="${TMP_DIR}/check.log"
trap 'rm -rf "${TMP_DIR}"' EXIT

bash "${ROOT}/scripts/bootstrap-new-project.sh" \
  --name "owned-path-comma-glob-selection" \
  --stacks python,node \
  --dest "${TARGET}"

cat > "${TARGET}/tasks/stacks.json" <<'EOF_JSON'
{
  "version": 1,
  "stacks": [
    {
      "name": "python",
      "adapter": "templates/stacks/python/check.adapter.sh",
      "projects": [
        {
          "path": "services/python-hello",
          "owned_paths": ["**/*.py"]
        }
      ]
    },
    {
      "name": "node",
      "adapter": "templates/stacks/node/check.adapter.sh",
      "projects": [
        {
          "path": "services/node-hello",
          "owned_paths": ["**/*.{js,ts}"]
        }
      ]
    }
  ]
}
EOF_JSON

(
  cd "${TARGET}"
  git init -q
  git add .
  git -c user.name='eval' -c user.email='eval@example.com' commit -q -m "baseline"
)

cat > "${TARGET}/services/node-hello/new-file.ts" <<'EOF_TS'
export const value = 1;
EOF_TS

(cd "${TARGET}" && bash ./scripts/check.sh --stacks auto --changed-only > "${LOG_FILE}")

if ! grep -Fq "[check] selected_stacks=node" "${LOG_FILE}"; then
  echo "[case-31] comma-containing owned_path glob did not match node change" >&2
  cat "${LOG_FILE}" >&2
  exit 1
fi

if grep -Eq "\\[check\\] selected_stacks=(python,node|node,python)" "${LOG_FILE}"; then
  echo "[case-31] changed-only selection unexpectedly fell back to all stacks" >&2
  cat "${LOG_FILE}" >&2
  exit 1
fi
