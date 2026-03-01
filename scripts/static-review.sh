#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="${PWD}"
STACK=""
OUT_FILE=""
MAX_COMPLEXITY=60

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/static-review.sh \
    --project-dir <path> \
    --stack <python|node|go> \
    [--out-file <path>] \
    [--max-complexity <int>]
USAGE
}

error() {
  echo "[static-review] ERROR: $*" >&2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-dir)
      PROJECT_DIR="$2"
      shift 2
      ;;
    --stack)
      STACK="$2"
      shift 2
      ;;
    --out-file)
      OUT_FILE="$2"
      shift 2
      ;;
    --max-complexity)
      MAX_COMPLEXITY="$2"
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

if [[ -z "${STACK}" ]]; then
  error "--stack is required"
  exit 2
fi

case "${STACK}" in
  python|node|go) ;;
  *)
    error "Unsupported stack '${STACK}'"
    exit 2
    ;;
esac

if [[ ! -d "${PROJECT_DIR}" ]]; then
  error "Project directory does not exist: ${PROJECT_DIR}"
  exit 2
fi
PROJECT_DIR="$(cd -- "${PROJECT_DIR}" && pwd -P)"

if [[ -z "${OUT_FILE}" ]]; then
  OUT_FILE="${PROJECT_DIR}/.orchestration/reports/static-review.json"
fi
if [[ "${OUT_FILE}" != /* ]]; then
  OUT_FILE="${PROJECT_DIR}/${OUT_FILE}"
fi
mkdir -p "$(dirname "${OUT_FILE}")"

SECURITY_FILE="$(mktemp)"
COMPLEXITY_FILE="$(mktemp)"
CONVENTION_FILE="$(mktemp)"
trap 'rm -f "${SECURITY_FILE}" "${COMPLEXITY_FILE}" "${CONVENTION_FILE}"' EXIT

# Security heuristics (hard gate)
rg -n --hidden --glob '!.git/**' --glob '!.orchestration/**' --glob '!.blackboard/**' --glob '!node_modules/**' \
  '(AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|-----BEGIN (RSA|EC|DSA|OPENSSH) PRIVATE KEY-----)' \
  "${PROJECT_DIR}" > "${SECURITY_FILE}" || true

case "${STACK}" in
  python)
    rg -n --glob '*.py' '(eval\(|exec\(|subprocess\..*shell\s*=\s*True)' "${PROJECT_DIR}" >> "${SECURITY_FILE}" || true
    ;;
  node)
    rg -n --glob '*.{js,mjs,cjs,ts,tsx}' '(eval\(|new Function\(|child_process\.(exec|execSync)\()' "${PROJECT_DIR}" >> "${SECURITY_FILE}" || true
    ;;
  go)
    rg -n --glob '*.go' '(exec\.Command\("(sh|bash)"|fmt\.Sprintf\(.*SELECT.*\+)' "${PROJECT_DIR}" >> "${SECURITY_FILE}" || true
    ;;
esac

# Convention heuristics (hard gate)
if [[ -d "${PROJECT_DIR}/scripts" ]]; then
  while IFS= read -r script_file; do
    if ! rg -q '^set -euo pipefail' "${script_file}"; then
      echo "${script_file}: missing 'set -euo pipefail'" >> "${CONVENTION_FILE}"
    fi
  done < <(find "${PROJECT_DIR}/scripts" -type f -name '*.sh' | sort)
fi

# Complexity heuristics (hard gate)
case "${STACK}" in
  python)
    FILE_GLOB='*.py'
    ;;
  node)
    FILE_GLOB='*.js *.mjs *.cjs *.ts *.tsx'
    ;;
  go)
    FILE_GLOB='*.go'
    ;;
esac

# Build file list based on stack without relying on bash4 arrays.
for pattern in ${FILE_GLOB}; do
  while IFS= read -r file_path; do
    [[ -z "${file_path}" ]] && continue
    token_count="$(rg -o '\b(if|for|while|case|catch)\b|&&|\|\|' "${file_path}" | wc -l | tr -d ' ')"
    if [[ "${token_count}" -gt "${MAX_COMPLEXITY}" ]]; then
      echo "${file_path}: token_complexity=${token_count} threshold=${MAX_COMPLEXITY}" >> "${COMPLEXITY_FILE}"
    fi
  done < <(find "${PROJECT_DIR}" -type f -name "${pattern}" -not -path '*/.git/*' -not -path '*/node_modules/*' -not -path '*/.orchestration/*' -not -path '*/.blackboard/*' | sort)
done

SECURITY_COUNT="$(grep -c . "${SECURITY_FILE}" || true)"
CONVENTION_COUNT="$(grep -c . "${CONVENTION_FILE}" || true)"
COMPLEXITY_COUNT="$(grep -c . "${COMPLEXITY_FILE}" || true)"

PASSED=true
if [[ "${SECURITY_COUNT}" -gt 0 || "${CONVENTION_COUNT}" -gt 0 || "${COMPLEXITY_COUNT}" -gt 0 ]]; then
  PASSED=false
fi

to_json_array() {
  local file="$1"
  perl -MJSON::PP -e '
    use strict;
    use warnings;
    my ($path) = @ARGV;
    my @rows;
    if (open my $fh, "<", $path) {
      while (my $line = <$fh>) {
        chomp $line;
        next if $line eq "";
        push @rows, $line;
      }
      close $fh;
    }
    print encode_json(\@rows);
  ' "${file}"
}

SECURITY_JSON="$(to_json_array "${SECURITY_FILE}")"
CONVENTION_JSON="$(to_json_array "${CONVENTION_FILE}")"
COMPLEXITY_JSON="$(to_json_array "${COMPLEXITY_FILE}")"

NOW_UTC="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

cat > "${OUT_FILE}" <<EOF_JSON
{
  "generated_at": "${NOW_UTC}",
  "stack": "${STACK}",
  "max_complexity": ${MAX_COMPLEXITY},
  "security_count": ${SECURITY_COUNT},
  "convention_count": ${CONVENTION_COUNT},
  "complexity_count": ${COMPLEXITY_COUNT},
  "passed": ${PASSED},
  "security_findings": ${SECURITY_JSON},
  "convention_findings": ${CONVENTION_JSON},
  "complexity_findings": ${COMPLEXITY_JSON}
}
EOF_JSON

cat "${OUT_FILE}"

if [[ "${PASSED}" == "true" ]]; then
  exit 0
fi

exit 1
