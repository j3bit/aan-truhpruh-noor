#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="${PWD}"
STACK=""
OUT_FILE=""
MAX_COMPLEXITY=60
HAS_RG=0

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

find_files_by_stack() {
  case "${STACK}" in
    python)
      find "${PROJECT_DIR}" -type f -name '*.py' \
        -not -path '*/.git/*' \
        -not -path '*/node_modules/*' \
        -not -path '*/.orchestration/*' \
        -not -path '*/.blackboard/*' \
        | sort
      ;;
    node)
      find "${PROJECT_DIR}" -type f \( -name '*.js' -o -name '*.mjs' -o -name '*.cjs' -o -name '*.ts' -o -name '*.tsx' \) \
        -not -path '*/.git/*' \
        -not -path '*/node_modules/*' \
        -not -path '*/.orchestration/*' \
        -not -path '*/.blackboard/*' \
        | sort
      ;;
    go)
      find "${PROJECT_DIR}" -type f -name '*.go' \
        -not -path '*/.git/*' \
        -not -path '*/node_modules/*' \
        -not -path '*/.orchestration/*' \
        -not -path '*/.blackboard/*' \
        | sort
      ;;
  esac
}

search_pattern_projectwide() {
  local pattern="$1"
  local out_file="$2"
  if [[ "${HAS_RG}" -eq 1 ]]; then
    rg -n --hidden --glob '!.git/**' --glob '!.orchestration/**' --glob '!.blackboard/**' --glob '!node_modules/**' \
      "${pattern}" "${PROJECT_DIR}" >> "${out_file}" || true
    return 0
  fi

  grep -R -nE \
    --exclude-dir=.git \
    --exclude-dir=.orchestration \
    --exclude-dir=.blackboard \
    --exclude-dir=node_modules \
    -- "${pattern}" "${PROJECT_DIR}" >> "${out_file}" || true
}

search_pattern_stack_files() {
  local pattern="$1"
  local out_file="$2"

  if [[ "${HAS_RG}" -eq 1 ]]; then
    case "${STACK}" in
      python)
        rg -n --glob '*.py' "${pattern}" "${PROJECT_DIR}" >> "${out_file}" || true
        ;;
      node)
        rg -n --glob '*.{js,mjs,cjs,ts,tsx}' "${pattern}" "${PROJECT_DIR}" >> "${out_file}" || true
        ;;
      go)
        rg -n --glob '*.go' "${pattern}" "${PROJECT_DIR}" >> "${out_file}" || true
        ;;
    esac
    return 0
  fi

  while IFS= read -r file_path; do
    [[ -z "${file_path}" ]] && continue
    grep -nE -- "${pattern}" "${file_path}" >> "${out_file}" || true
  done < <(find_files_by_stack)
}

count_complexity_tokens() {
  local file_path="$1"
  if [[ "${HAS_RG}" -eq 1 ]]; then
    rg -o '\b(if|for|while|case|catch)\b|&&|\|\|' "${file_path}" 2>/dev/null | wc -l | tr -d ' '
    return 0
  fi
  (grep -Eo '\b(if|for|while|case|catch)\b|&&|\|\|' "${file_path}" || true) | wc -l | tr -d ' '
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
if command -v rg >/dev/null 2>&1; then
  HAS_RG=1
fi

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
search_pattern_projectwide \
  '(AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|-----BEGIN (RSA|EC|DSA|OPENSSH) PRIVATE KEY-----)' \
  "${SECURITY_FILE}"

case "${STACK}" in
  python)
    search_pattern_stack_files '(eval\(|exec\(|subprocess\..*shell\s*=\s*True)' "${SECURITY_FILE}"
    ;;
  node)
    search_pattern_stack_files '(eval\(|new Function\(|child_process\.(exec|execSync)\()' "${SECURITY_FILE}"
    ;;
  go)
    search_pattern_stack_files '(exec\.Command\("(sh|bash)"|fmt\.Sprintf\(.*SELECT.*\+)' "${SECURITY_FILE}"
    ;;
esac

# Convention heuristics (hard gate)
if [[ -d "${PROJECT_DIR}/scripts" ]]; then
  while IFS= read -r script_file; do
    if ! grep -q '^set -euo pipefail' "${script_file}"; then
      echo "${script_file}: missing 'set -euo pipefail'" >> "${CONVENTION_FILE}"
    fi
  done < <(find "${PROJECT_DIR}/scripts" -type f -name '*.sh' | sort)
fi

# Complexity heuristics (hard gate)
while IFS= read -r file_path; do
  [[ -z "${file_path}" ]] && continue
  token_count="$(count_complexity_tokens "${file_path}")"
  if [[ "${token_count}" -gt "${MAX_COMPLEXITY}" ]]; then
    echo "${file_path}: token_complexity=${token_count} threshold=${MAX_COMPLEXITY}" >> "${COMPLEXITY_FILE}"
  fi
done < <(find_files_by_stack)

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
