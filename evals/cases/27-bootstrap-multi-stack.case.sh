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

test -d "${TARGET}/apps"
test -d "${TARGET}/packages"
test -d "${TARGET}/tests"
test -d "${TARGET}/infra"
test ! -d "${TARGET}/services"
test ! -d "${TARGET}/examples"
test -f "${TARGET}/templates/stacks/rust/check.adapter.sh"
test -f "${TARGET}/tasks/stacks.json"

jq -e '
  .version == 1 and
  (.stacks | length == 3) and
  all(.stacks[]; .projects[0].path == ".") and
  any(.stacks[]; .name == "python") and
  any(.stacks[]; .name == "node") and
  any(.stacks[]; .name == "rust")
' "${TARGET}/tasks/stacks.json" >/dev/null

(cd "${TARGET}" && bash ./scripts/validate-contracts.sh --project-dir . >/dev/null)
