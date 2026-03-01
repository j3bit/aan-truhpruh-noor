#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

if [[ ! -f "${REPO_ROOT}/scripts/lib/stack-registry.sh" ]]; then
  echo "[check] ERROR: stack registry library not found" >&2
  exit 2
fi

# shellcheck source=/dev/null
source "${REPO_ROOT}/scripts/lib/stack-registry.sh"

STACKS_ARG=""
CHANGED_ONLY=0
PROJECT_DIR="${PWD}"
REGISTRY_PATH=""

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/check.sh [--stacks <csv|auto>] [--changed-only] [--project-dir <path>] [--registry <path>]

Notes:
  --stacks accepts comma-separated stack names (e.g. python,node) or auto.
  When omitted:
    - with --changed-only: auto selection from changed files
    - without --changed-only: all registered stacks

  --stack is no longer supported.

Exit Codes:
  0: all checks passed
  1: one or more checks failed
  2: configuration or input error
USAGE
}

error() {
  echo "[check] ERROR: $*" >&2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --stacks)
      [[ $# -ge 2 ]] || { error "--stacks requires a value"; usage; exit 2; }
      STACKS_ARG="$2"
      shift 2
      ;;
    --stack)
      error "--stack is removed. Use --stacks <csv|auto>"
      exit 2
      ;;
    --changed-only)
      CHANGED_ONLY=1
      shift
      ;;
    --project-dir)
      [[ $# -ge 2 ]] || { error "--project-dir requires a value"; usage; exit 2; }
      PROJECT_DIR="$2"
      shift 2
      ;;
    --registry)
      [[ $# -ge 2 ]] || { error "--registry requires a value"; usage; exit 2; }
      REGISTRY_PATH="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      error "Unknown argument: $1"
      usage
      exit 2
      ;;
  esac
done

if [[ ! -d "${PROJECT_DIR}" ]]; then
  error "Project directory does not exist: ${PROJECT_DIR}"
  exit 2
fi

PROJECT_DIR="$(cd -- "${PROJECT_DIR}" && pwd -P)"
REGISTRY_ABS="$(stack_registry_resolve_path "${PROJECT_DIR}" "${REGISTRY_PATH}")"

if [[ ! -f "${REGISTRY_ABS}" ]]; then
  error "Stack registry not found: ${REGISTRY_ABS}"
  exit 2
fi

if ! stack_registry_validate "${REGISTRY_ABS}" "${PROJECT_DIR}"; then
  error "Invalid stack registry: ${REGISTRY_ABS}"
  exit 2
fi

CONTRACT_VALIDATOR="${REPO_ROOT}/scripts/validate-contracts.sh"
if [[ ! -f "${CONTRACT_VALIDATOR}" ]]; then
  error "Contract validator not found: ${CONTRACT_VALIDATOR}"
  exit 2
fi

ARGS=(--project-dir "${PROJECT_DIR}" --registry "${REGISTRY_ABS}")
if [[ "${CHANGED_ONLY}" -eq 1 ]]; then
  ARGS+=(--changed-only)
fi

echo "[check] project_dir=${PROJECT_DIR} changed_only=${CHANGED_ONLY} registry=${REGISTRY_ABS}"

set +e
echo "[check] RUN: contract preflight"
bash "${CONTRACT_VALIDATOR}" "${ARGS[@]}"
CONTRACT_RESULT=$?
set -e
if [[ "${CONTRACT_RESULT}" -ne 0 ]]; then
  if [[ "${CONTRACT_RESULT}" -eq 1 ]]; then
    echo "[check] FAIL"
    exit 1
  fi
  echo "[check] ERROR"
  exit 2
fi

STACK_SELECTION_FILE="$(mktemp)"
CHANGED_FILES_FILE="$(mktemp)"
cleanup() {
  rm -f "${STACK_SELECTION_FILE}" "${CHANGED_FILES_FILE}"
}
trap cleanup EXIT

select_all_registered() {
  stack_registry_list_names "${REGISTRY_ABS}" > "${STACK_SELECTION_FILE}"
}

select_explicit_csv() {
  local requested="$1"
  local stack_name

  : > "${STACK_SELECTION_FILE}"
  while IFS= read -r stack_name; do
    [[ -z "${stack_name}" ]] && continue
    if ! stack_registry_stack_exists "${REGISTRY_ABS}" "${stack_name}"; then
      error "Unknown stack '${stack_name}' in --stacks"
      return 1
    fi
    printf '%s\n' "${stack_name}" >> "${STACK_SELECTION_FILE}"
  done < <(stack_registry_csv_normalize "${requested}")

  if [[ ! -s "${STACK_SELECTION_FILE}" ]]; then
    error "No stacks selected from --stacks=${requested}"
    return 1
  fi
  return 0
}

select_from_changed() {
  stack_registry_collect_changed_files "${PROJECT_DIR}" "${CHANGED_FILES_FILE}"
  stack_registry_select_from_changed "${REGISTRY_ABS}" "${CHANGED_FILES_FILE}" > "${STACK_SELECTION_FILE}"

  if [[ ! -s "${STACK_SELECTION_FILE}" ]]; then
    echo "[check] INFO: no changed-file stack match; falling back to all registered stacks"
    select_all_registered
  fi
}

if [[ -n "${STACKS_ARG}" ]]; then
  if [[ "${STACKS_ARG}" == "auto" ]]; then
    select_from_changed
  else
    select_explicit_csv "${STACKS_ARG}" || exit 2
  fi
else
  if [[ "${CHANGED_ONLY}" -eq 1 ]]; then
    select_from_changed
  else
    select_all_registered
  fi
fi

if [[ ! -s "${STACK_SELECTION_FILE}" ]]; then
  error "No stacks selected for execution"
  exit 2
fi

if [[ "${CHANGED_ONLY}" -eq 1 ]]; then
  stack_registry_collect_changed_files "${PROJECT_DIR}" "${CHANGED_FILES_FILE}"
fi

echo "[check] selected_stacks=$(paste -sd ',' "${STACK_SELECTION_FILE}")"

OVERALL_FAIL=0
OVERALL_ERROR=0

while IFS= read -r STACK_NAME; do
  [[ -z "${STACK_NAME}" ]] && continue

  ADAPTER_REL="$(stack_registry_adapter_for "${REGISTRY_ABS}" "${STACK_NAME}")"
  if [[ "${ADAPTER_REL}" == /* ]]; then
    ADAPTER_ABS="${ADAPTER_REL}"
  else
    ADAPTER_ABS="${PROJECT_DIR}/${ADAPTER_REL}"
  fi

  if [[ ! -f "${ADAPTER_ABS}" ]]; then
    error "Adapter not found for stack ${STACK_NAME}: ${ADAPTER_ABS}"
    OVERALL_ERROR=1
    continue
  fi

  while IFS='|' read -r PROJECT_PATH _OWNED; do
    [[ -z "${PROJECT_PATH}" ]] && continue

    if [[ "${PROJECT_PATH}" == /* ]]; then
      TARGET_PROJECT_DIR="${PROJECT_PATH}"
    else
      TARGET_PROJECT_DIR="${PROJECT_DIR}/${PROJECT_PATH}"
    fi

    if [[ ! -d "${TARGET_PROJECT_DIR}" ]]; then
      error "Project path for stack ${STACK_NAME} does not exist: ${TARGET_PROJECT_DIR}"
      OVERALL_ERROR=1
      continue
    fi

    echo "[check] RUN: stack=${STACK_NAME} adapter=${ADAPTER_ABS} project=${TARGET_PROJECT_DIR}"
    set +e
    ADAPTER_CMD=(bash "${ADAPTER_ABS}" --project-dir "${TARGET_PROJECT_DIR}")
    PROJECT_CHANGED_FILE=""
    if [[ "${CHANGED_ONLY}" -eq 1 ]]; then
      ADAPTER_CMD+=(--changed-only)
      PROJECT_CHANGED_FILE="$(mktemp)"

      PROJECT_PREFIX="${PROJECT_PATH#./}"
      if [[ "${PROJECT_PREFIX}" == /* ]]; then
        if [[ "${PROJECT_PREFIX}" == "${PROJECT_DIR}"/* ]]; then
          PROJECT_PREFIX="${PROJECT_PREFIX#${PROJECT_DIR}/}"
        else
          PROJECT_PREFIX=""
        fi
      fi

      if [[ -z "${PROJECT_PREFIX}" || "${PROJECT_PREFIX}" == "." ]]; then
        cat "${CHANGED_FILES_FILE}" > "${PROJECT_CHANGED_FILE}"
      else
        awk -v prefix="${PROJECT_PREFIX%/}/" '
          index($0, prefix) == 1 {
            rel = substr($0, length(prefix) + 1);
            if (rel != "") {
              print rel;
            }
          }
        ' "${CHANGED_FILES_FILE}" > "${PROJECT_CHANGED_FILE}"
      fi
    fi

    if [[ -n "${PROJECT_CHANGED_FILE}" ]]; then
      STACK_CHECK_CHANGED_FILES_FILE="${PROJECT_CHANGED_FILE}" "${ADAPTER_CMD[@]}"
    else
      "${ADAPTER_CMD[@]}"
    fi
    RESULT=$?
    if [[ -n "${PROJECT_CHANGED_FILE}" ]]; then
      rm -f "${PROJECT_CHANGED_FILE}"
    fi
    set -e

    if [[ "${RESULT}" -eq 0 ]]; then
      echo "[check] OK: stack=${STACK_NAME} project=${TARGET_PROJECT_DIR}"
    elif [[ "${RESULT}" -eq 1 ]]; then
      echo "[check] FAIL: stack=${STACK_NAME} project=${TARGET_PROJECT_DIR}"
      OVERALL_FAIL=1
    else
      echo "[check] ERROR: stack=${STACK_NAME} project=${TARGET_PROJECT_DIR}"
      OVERALL_ERROR=1
    fi
  done < <(stack_registry_project_rows "${REGISTRY_ABS}" "${STACK_NAME}")
done < "${STACK_SELECTION_FILE}"

if [[ "${OVERALL_ERROR}" -eq 1 ]]; then
  echo "[check] ERROR"
  exit 2
fi

if [[ "${OVERALL_FAIL}" -eq 1 ]]; then
  echo "[check] FAIL"
  exit 1
fi

echo "[check] PASS"
exit 0
