#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="${PWD}"
TASKS_FILE=""
TRD_FILE=""
PRD_FILE=""
OUT_FILE=""

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/qa-generate-scenarios.sh \
    --project-dir <path> \
    [--tasks-file <path>] \
    [--trd-file <path>] \
    [--prd-file <path>] \
    [--out-file <path>]
USAGE
}

error() {
  echo "[qa-generate] ERROR: $*" >&2
}

normalize_abs() {
  local path="$1"
  if [[ "${path}" == /* ]]; then
    printf '%s' "${path}"
  else
    printf '%s/%s' "${PROJECT_DIR}" "${path}"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-dir)
      PROJECT_DIR="$2"
      shift 2
      ;;
    --tasks-file)
      TASKS_FILE="$2"
      shift 2
      ;;
    --trd-file)
      TRD_FILE="$2"
      shift 2
      ;;
    --prd-file)
      PRD_FILE="$2"
      shift 2
      ;;
    --out-file)
      OUT_FILE="$2"
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

if [[ -z "${TASKS_FILE}" ]]; then
  candidates=("${PROJECT_DIR}"/tasks/tasks-*.md)
  if [[ ! -e "${candidates[0]}" ]]; then
    error "No tasks/tasks-*.md found"
    exit 2
  fi
  if [[ "${#candidates[@]}" -ne 1 ]]; then
    error "Multiple tasks files found; pass --tasks-file"
    exit 2
  fi
  TASKS_FILE="${candidates[0]}"
fi
TASKS_FILE="$(normalize_abs "${TASKS_FILE}")"
if [[ ! -f "${TASKS_FILE}" ]]; then
  error "Tasks file not found: ${TASKS_FILE}"
  exit 2
fi

if [[ -z "${TRD_FILE}" ]]; then
  TRD_FILE="$(awk '
    /^- TRD:/ {
      line=$0
      sub(/^- TRD:[[:space:]]*/, "", line)
      gsub(/`/, "", line)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
      print line
      exit
    }
  ' "${TASKS_FILE}")"
fi

if [[ -z "${PRD_FILE}" ]]; then
  PRD_FILE="$(awk '
    /^- PRD:/ {
      line=$0
      sub(/^- PRD:[[:space:]]*/, "", line)
      gsub(/`/, "", line)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
      print line
      exit
    }
  ' "${TASKS_FILE}")"
fi

if [[ -n "${TRD_FILE}" ]]; then
  TRD_FILE="$(normalize_abs "${TRD_FILE}")"
fi
if [[ -n "${PRD_FILE}" ]]; then
  PRD_FILE="$(normalize_abs "${PRD_FILE}")"
fi

base_name="$(basename "${TASKS_FILE}")"
id="${base_name#tasks-}"
id="${id%%-*}"
slug="${base_name#tasks-${id}-}"
slug="${slug%.md}"

if [[ -z "${OUT_FILE}" ]]; then
  OUT_FILE="${PROJECT_DIR}/.blackboard/artifacts/qa/scenarios-${id}-${slug}.json"
fi
OUT_FILE="$(normalize_abs "${OUT_FILE}")"
mkdir -p "$(dirname "${OUT_FILE}")"

TASK_IDS_FILE="$(mktemp)"
trap 'rm -f "${TASK_IDS_FILE}"' EXIT

awk '/^### T-[0-9]+:/ { gsub(/:/, "", $2); print $2 }' "${TASKS_FILE}" > "${TASK_IDS_FILE}"

TASK_IDS_JSON="$(perl -MJSON::PP -e '
  use strict;
  use warnings;
  my ($path) = @ARGV;
  open my $fh, "<", $path or die "open_failed";
  my @items;
  while (my $line = <$fh>) {
    chomp $line;
    next if $line eq "";
    push @items, $line;
  }
  close $fh;
  print encode_json(\@items);
' "${TASK_IDS_FILE}")"

NOW_UTC="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

REL_TASKS="${TASKS_FILE#${PROJECT_DIR}/}"
REL_TRD="${TRD_FILE#${PROJECT_DIR}/}"
REL_PRD="${PRD_FILE#${PROJECT_DIR}/}"

cat > "${OUT_FILE}" <<EOF_JSON
{
  "id": "${id}",
  "slug": "${slug}",
  "generated_at": "${NOW_UTC}",
  "tasks_path": "${REL_TASKS}",
  "trd_path": "${REL_TRD}",
  "prd_path": "${REL_PRD}",
  "scenario_types": ["integration", "e2e"],
  "task_ids": ${TASK_IDS_JSON},
  "notes": "TRD/PRD grounded integration and e2e scenario seed"
}
EOF_JSON

echo "${OUT_FILE}"
