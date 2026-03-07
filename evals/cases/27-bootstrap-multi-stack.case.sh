#!/usr/bin/env bash
set -euo pipefail

ROOT="${EVAL_REPO_ROOT:-$(pwd)}"
TMP_DIR="$(mktemp -d)"
TARGET="${TMP_DIR}/bootstrap-multi-stack"
trap 'rm -rf "${TMP_DIR}"' EXIT

bash "${ROOT}/scripts/bootstrap-new-project.sh" \
  --name "bootstrap-multi-stack" \
  --stacks python,node,rust \
  --dest "${TARGET}"

test -d "${TARGET}/services/python-hello"
test -d "${TARGET}/services/node-hello"
test -d "${TARGET}/services/rust-hello"
test -f "${TARGET}/services/rust-hello/README.md"
test -f "${TARGET}/templates/stacks/rust/check.adapter.sh"
test -f "${TARGET}/tasks/stacks.json"

jq -e '
  .version == 1 and
  (.stacks | length == 3) and
  any(.stacks[]; .name == "python" and .projects[0].path == "services/python-hello") and
  any(.stacks[]; .name == "node" and .projects[0].path == "services/node-hello") and
  any(.stacks[]; .name == "rust" and .projects[0].path == "services/rust-hello")
' "${TARGET}/tasks/stacks.json" >/dev/null

(cd "${TARGET}" && bash ./scripts/validate-contracts.sh --project-dir . >/dev/null)
