#!/usr/bin/env bash
set -euo pipefail

ROOT="${EVAL_REPO_ROOT:-$(pwd)}"
TMP_DIR="$(mktemp -d)"
TARGET="${TMP_DIR}/hygiene-check"
trap 'rm -rf "${TMP_DIR}"' EXIT

bash "${ROOT}/scripts/bootstrap-new-project.sh" \
  --name "hygiene-check" \
  --stack python \
  --dest "${TARGET}"

if find "${TARGET}" -type d \( -name '__pycache__' -o -name '.cache' \) -print -quit | grep -q .; then
  echo "[case-07] bootstrap output contains transient cache directory" >&2
  exit 1
fi

if find "${TARGET}" -type f \( -name '*.pyc' -o -name '*.pyo' \) -print -quit | grep -q .; then
  echo "[case-07] bootstrap output contains transient bytecode artifacts" >&2
  exit 1
fi

if [[ -d "${TARGET}/evals/results" ]] && find "${TARGET}/evals/results" -type f -name '*.jsonl' -print -quit | grep -q .; then
  echo "[case-07] bootstrap output contains eval result artifacts" >&2
  exit 1
fi
