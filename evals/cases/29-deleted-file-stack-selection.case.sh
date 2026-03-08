#!/usr/bin/env bash
set -euo pipefail

ROOT="${EVAL_REPO_ROOT:-$(pwd)}"
TMP_DIR="$(mktemp -d)"
TARGET="${TMP_DIR}/deleted-file-stack-selection"
LOG_FILE="${TMP_DIR}/check.log"
trap 'rm -rf "${TMP_DIR}"' EXIT

bash "${ROOT}/scripts/bootstrap-new-project.sh" \
  --name "deleted-file-stack-selection" \
  --stacks python,node \
  --dest "${TARGET}"

mkdir -p "${TARGET}/apps/python" "${TARGET}/apps/node" "${TARGET}/packages" "${TARGET}/tests" "${TARGET}/infra"

cat > "${TARGET}/tasks/stacks.json" <<'EOF_JSON'
{
  "version": 1,
  "stacks": [
    {
      "name": "python",
      "adapter": "templates/stacks/python/check.adapter.sh",
      "projects": [
        {
          "path": ".",
          "owned_paths": ["apps/python/**/*.py", "pyproject.toml"]
        }
      ]
    },
    {
      "name": "node",
      "adapter": "templates/stacks/node/check.adapter.sh",
      "projects": [
        {
          "path": ".",
          "owned_paths": ["apps/node/**/*.{js,ts}", "package.json"]
        }
      ]
    }
  ]
}
EOF_JSON

cat > "${TARGET}/pyproject.toml" <<'EOF_TOML'
[project]
name = "deleted-file-stack-selection"
version = "0.1.0"
EOF_TOML

cat > "${TARGET}/apps/python/main.py" <<'EOF_PY'
print("python file slated for deletion")
EOF_PY

cat > "${TARGET}/test_smoke.py" <<'EOF_PY'
import unittest


class SmokeTest(unittest.TestCase):
    def test_truth(self) -> None:
        self.assertTrue(True)


if __name__ == "__main__":
    unittest.main()
EOF_PY

cat > "${TARGET}/package.json" <<'EOF_JSON'
{
  "name": "deleted-file-stack-selection",
  "private": true
}
EOF_JSON

cat > "${TARGET}/apps/node/basic.js" <<'EOF_JS'
console.log("node baseline");
EOF_JS

(
  cd "${TARGET}"
  git init -q
  git add .
  git -c user.name='eval' -c user.email='eval@example.com' commit -q -m "baseline"
)

rm -f "${TARGET}/apps/python/main.py"
echo "// changed by eval case 29" >> "${TARGET}/apps/node/basic.js"

set +e
(cd "${TARGET}" && bash ./scripts/check.sh --stacks auto --changed-only > "${LOG_FILE}")
_status=$?
set -e

if [[ "${_status}" -ne 0 ]]; then
  echo "[case-29] check.sh failed unexpectedly" >&2
  cat "${LOG_FILE}" >&2
  exit 1
fi

if ! grep -Eq "\\[check\\] selected_stacks=(python,node|node,python)" "${LOG_FILE}"; then
  echo "[case-29] changed-only selection missed deleted-file stack" >&2
  cat "${LOG_FILE}" >&2
  exit 1
fi
