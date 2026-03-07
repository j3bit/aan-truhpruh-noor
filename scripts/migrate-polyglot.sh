#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="${PWD}"
REGISTRY_PATH="tasks/stacks.json"
DRY_RUN=0

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/migrate-polyglot.sh [--project-dir <path>] [--registry <path>] [--dry-run]

Description:
  Migrates legacy single-stack task contracts to the polyglot registry model.
  - Replaces task metadata `Gate Stack` with `Stack Registry`
  - Replaces DAG metadata `gate_stack` with `stack_registry`
  - Adds `nodes[].gate_stacks` when missing
  - Creates `tasks/stacks.json` when absent
  - Creates *.bak backups before file rewrites

Options:
  --project-dir  Target project root (default: current working directory).
  --registry     Registry path to write into metadata (default: tasks/stacks.json).
  --dry-run      Show planned changes without writing files.
USAGE
}

error() {
  echo "[migrate-polyglot] ERROR: $*" >&2
}

info() {
  echo "[migrate-polyglot] $*"
}

default_owned_paths_json() {
  local stack="$1"
  case "${stack}" in
    python)
      cat <<'EOF_JSON'
["**/*.py", "pyproject.toml", "requirements*.txt", "setup.py"]
EOF_JSON
      ;;
    node)
      cat <<'EOF_JSON'
["**/*.js", "**/*.mjs", "**/*.cjs", "**/*.ts", "**/*.tsx", "package.json", "package-lock.json", "pnpm-lock.yaml", "yarn.lock"]
EOF_JSON
      ;;
    go)
      cat <<'EOF_JSON'
["**/*.go", "go.mod", "go.sum"]
EOF_JSON
      ;;
    *)
      cat <<'EOF_JSON'
["**/*"]
EOF_JSON
      ;;
  esac
}

ensure_stack_adapter() {
  local stack="$1"
  local adapter_rel="templates/stacks/${stack}/check.adapter.sh"
  local adapter_abs="${PROJECT_DIR}/${adapter_rel}"

  if [[ -f "${adapter_abs}" ]]; then
    return 0
  fi

  if [[ "${DRY_RUN}" -eq 1 ]]; then
    info "WOULD_CREATE ${adapter_rel} (placeholder adapter)"
    return 0
  fi

  mkdir -p "$(dirname "${adapter_abs}")"
  cat > "${adapter_abs}" <<EOF_ADAPTER
#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="\${PWD}"

while [[ \$# -gt 0 ]]; do
  case "\$1" in
    --project-dir)
      [[ \$# -ge 2 ]] || { echo "[${stack}-check] ERROR: --project-dir requires a value" >&2; exit 2; }
      PROJECT_DIR="\$2"
      shift 2
      ;;
    --changed-only)
      shift
      ;;
    -h|--help)
      echo "Usage: check.adapter.sh --project-dir <path> [--changed-only]"
      exit 0
      ;;
    *)
      echo "[${stack}-check] ERROR: unknown argument \$1" >&2
      exit 2
      ;;
  esac
done

if [[ ! -d "\${PROJECT_DIR}" ]]; then
  echo "[${stack}-check] ERROR: project directory not found: \${PROJECT_DIR}" >&2
  exit 2
fi

echo "[${stack}-check] INFO: placeholder adapter for stack '${stack}' (no checks configured yet)."
exit 0
EOF_ADAPTER
  chmod +x "${adapter_abs}"
  info "CREATED ${adapter_rel} (placeholder adapter)"
}

backup_and_write() {
  local path="$1"
  local content_file="$2"
  local changed=0

  if [[ ! -f "${path}" ]]; then
    changed=1
  elif ! cmp -s "${path}" "${content_file}"; then
    changed=1
  fi

  if [[ "${changed}" -eq 0 ]]; then
    return 1
  fi

  if [[ "${DRY_RUN}" -eq 1 ]]; then
    info "WOULD_UPDATE ${path#${PROJECT_DIR}/}"
    return 0
  fi

  if [[ -f "${path}" ]]; then
    cp "${path}" "${path}.bak"
  else
    mkdir -p "$(dirname "${path}")"
  fi
  cat "${content_file}" > "${path}"
  info "UPDATED ${path#${PROJECT_DIR}/}"
  return 0
}

normalize_stack_list() {
  tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed '/^$/d' | awk '!seen[$0]++'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
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
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      error "unknown argument: $1"
      usage
      exit 2
      ;;
  esac
done

if [[ ! -d "${PROJECT_DIR}" ]]; then
  error "project directory does not exist: ${PROJECT_DIR}"
  exit 2
fi
PROJECT_DIR="$(cd "${PROJECT_DIR}" && pwd -P)"

if [[ "${REGISTRY_PATH}" == /* ]]; then
  REGISTRY_ABS="${REGISTRY_PATH}"
else
  REGISTRY_ABS="${PROJECT_DIR}/${REGISTRY_PATH}"
fi

if [[ "${REGISTRY_ABS}" == "${PROJECT_DIR}/"* ]]; then
  REGISTRY_REL="${REGISTRY_ABS#${PROJECT_DIR}/}"
else
  REGISTRY_REL="${REGISTRY_ABS}"
fi

TASKS_DIR="${PROJECT_DIR}/tasks"
if [[ ! -d "${TASKS_DIR}" ]]; then
  error "missing tasks directory: ${TASKS_DIR}"
  exit 1
fi

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

touch "${TMP_DIR}/stack-names.txt"

LEGACY_FOUND=0
for legacy_file in "${TASKS_DIR}"/tasks-*.md "${TASKS_DIR}"/dag-*.md; do
  [[ -f "${legacy_file}" ]] || continue
  if grep -qE '^- Gate Stack:' "${legacy_file}"; then
    LEGACY_FOUND=1
    break
  fi
done
if [[ "${LEGACY_FOUND}" -eq 0 ]]; then
  for legacy_file in "${TASKS_DIR}"/tasks-*.md; do
    [[ -f "${legacy_file}" ]] || continue
    if grep -qE '\./scripts/check\.sh --stack ' "${legacy_file}"; then
      LEGACY_FOUND=1
      break
    fi
  done
fi
if [[ "${LEGACY_FOUND}" -eq 0 ]]; then
  for legacy_file in "${TASKS_DIR}"/dag-*.json; do
    [[ -f "${legacy_file}" ]] || continue
    if perl -MJSON::PP -e '
      use strict;
      use warnings;
      my ($path) = @ARGV;
      local $/;
      open my $fh, "<", $path or exit 1;
      my $raw = <$fh>;
      close $fh;
      my $obj = eval { decode_json($raw) };
      exit 1 if !$obj || ref($obj) ne "HASH";
      if (ref($obj->{metadata}) eq "HASH" && exists $obj->{metadata}{gate_stack}) {
        exit 0;
      }
      exit 1;
    ' "${legacy_file}" >/dev/null 2>&1; then
      LEGACY_FOUND=1
      break
    fi
  done
fi

# 1) Collect stack names from legacy contracts.
while IFS= read -r task_file; do
  awk '
    /^- Gate Stack:/ {
      line = $0
      sub(/^- Gate Stack:[[:space:]]*/, "", line)
      gsub(/`/, "", line)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
      if (line != "") print line
    }
  ' "${task_file}" >> "${TMP_DIR}/stack-names.txt"
done < <(find "${TASKS_DIR}" -maxdepth 1 -type f -name 'tasks-*.md' | sort)

while IFS= read -r dag_file; do
  perl -MJSON::PP -e '
    use strict;
    use warnings;
    my ($path) = @ARGV;
    local $/;
    open my $fh, "<", $path or exit 0;
    my $raw = <$fh>;
    close $fh;
    my $obj = eval { decode_json($raw) };
    exit 0 if !$obj || ref($obj) ne "HASH";
    if (ref($obj->{metadata}) eq "HASH" && defined $obj->{metadata}{gate_stack}) {
      print $obj->{metadata}{gate_stack}, "\n";
    }
    if (ref($obj->{nodes}) eq "ARRAY") {
      for my $node (@{$obj->{nodes}}) {
        next unless ref($node) eq "HASH";
        next unless ref($node->{gate_stacks}) eq "ARRAY";
        for my $stack (@{$node->{gate_stacks}}) {
          next if !defined $stack || ref($stack);
          print $stack, "\n";
        }
      }
    }
  ' "${dag_file}" >> "${TMP_DIR}/stack-names.txt"
done < <(find "${TASKS_DIR}" -maxdepth 1 -type f -name 'dag-*.json' | sort)

if [[ -f "${REGISTRY_ABS}" ]]; then
  perl -MJSON::PP -e '
    use strict;
    use warnings;
    my ($path) = @ARGV;
    local $/;
    open my $fh, "<", $path or exit 0;
    my $raw = <$fh>;
    close $fh;
    my $obj = eval { decode_json($raw) };
    exit 0 if !$obj || ref($obj) ne "HASH";
    exit 0 unless ref($obj->{stacks}) eq "ARRAY";
    for my $stack (@{$obj->{stacks}}) {
      next unless ref($stack) eq "HASH";
      next unless defined $stack->{name};
      next if ref($stack->{name});
      print $stack->{name}, "\n";
    }
  ' "${REGISTRY_ABS}" >> "${TMP_DIR}/stack-names.txt"
fi

STACK_NAMES=()
while IFS= read -r stack_name; do
  [[ -n "${stack_name}" ]] && STACK_NAMES+=("${stack_name}")
done < <(normalize_stack_list < "${TMP_DIR}/stack-names.txt")
if [[ "${#STACK_NAMES[@]}" -eq 0 ]]; then
  STACK_NAMES=("python")
fi

DEFAULT_STACK="${STACK_NAMES[0]}"
info "Discovered stacks: $(IFS=,; echo "${STACK_NAMES[*]}")"

# 2) Ensure adapters exist for discovered stacks.
for stack in "${STACK_NAMES[@]}"; do
  ensure_stack_adapter "${stack}"
done

# 3) Migrate tasks markdown metadata + gate command examples.
TASKS_CHANGED=0
while IFS= read -r task_file; do
  tmp="${TMP_DIR}/$(basename "${task_file}").migrated"
  perl -e '
    use strict;
    use warnings;
    my ($path, $registry) = @ARGV;
    local $/;
    open my $fh, "<", $path or die "open_failed\n";
    my $text = <$fh>;
    close $fh;

    $text =~ s/^- Gate Stack:[^\n]*\n/- Stack Registry: `$registry`\n/mg;
    $text =~ s#\./scripts/check\.sh --stack [^`\s]+#./scripts/check.sh --stacks auto#g;
    if ($text !~ /^- Stack Registry:/m) {
      $text =~ s/^- Planning Artifact:[^\n]*\n/$&- Stack Registry: `$registry`\n/m;
    }

    print $text;
  ' "${task_file}" "${REGISTRY_REL}" > "${tmp}"
  if backup_and_write "${task_file}" "${tmp}"; then
    TASKS_CHANGED=$((TASKS_CHANGED + 1))
  fi
done < <(find "${TASKS_DIR}" -maxdepth 1 -type f -name 'tasks-*.md' | sort)

# 4) Migrate DAG markdown metadata.
DAG_MD_CHANGED=0
while IFS= read -r dag_md_file; do
  tmp="${TMP_DIR}/$(basename "${dag_md_file}").migrated"
  perl -e '
    use strict;
    use warnings;
    my ($path, $registry) = @ARGV;
    local $/;
    open my $fh, "<", $path or die "open_failed\n";
    my $text = <$fh>;
    close $fh;

    $text =~ s/^- Gate Stack:[^\n]*\n/- Stack Registry: `$registry`\n/mg;
    if ($text !~ /^- Stack Registry:/m) {
      $text =~ s/^- Tasks:[^\n]*\n/$&- Stack Registry: `$registry`\n/m;
    }

    print $text;
  ' "${dag_md_file}" "${REGISTRY_REL}" > "${tmp}"
  if backup_and_write "${dag_md_file}" "${tmp}"; then
    DAG_MD_CHANGED=$((DAG_MD_CHANGED + 1))
  fi
done < <(find "${TASKS_DIR}" -maxdepth 1 -type f -name 'dag-*.md' | sort)

# 5) Migrate DAG JSON metadata and node gate_stacks.
DAG_JSON_CHANGED=0
while IFS= read -r dag_json_file; do
  tmp="${TMP_DIR}/$(basename "${dag_json_file}").migrated"
  perl -MJSON::PP -e '
    use strict;
    use warnings;
    my ($path, $registry, $fallback) = @ARGV;
    local $/;
    open my $fh, "<", $path or die "open_failed\n";
    my $raw = <$fh>;
    close $fh;
    my $obj = decode_json($raw);
    die "invalid_json\n" unless ref($obj) eq "HASH";
    $obj->{metadata} = {} unless ref($obj->{metadata}) eq "HASH";
    my $legacy = $obj->{metadata}{gate_stack};
    $obj->{metadata}{stack_registry} = $registry;
    delete $obj->{metadata}{gate_stack};
    my $resolved = defined($legacy) && !ref($legacy) && $legacy ne "" ? $legacy : $fallback;
    die "missing_nodes\n" unless ref($obj->{nodes}) eq "ARRAY";
    for my $node (@{$obj->{nodes}}) {
      die "invalid_node\n" unless ref($node) eq "HASH";
      if (!(ref($node->{gate_stacks}) eq "ARRAY" && @{$node->{gate_stacks}})) {
        $node->{gate_stacks} = [$resolved];
      }
    }
    print JSON::PP->new->ascii->pretty->canonical->encode($obj);
  ' "${dag_json_file}" "${REGISTRY_REL}" "${DEFAULT_STACK}" > "${tmp}"
  if backup_and_write "${dag_json_file}" "${tmp}"; then
    DAG_JSON_CHANGED=$((DAG_JSON_CHANGED + 1))
  fi
done < <(find "${TASKS_DIR}" -maxdepth 1 -type f -name 'dag-*.json' | sort)

# 6) Create or update stack registry.
registry_tmp="${TMP_DIR}/stacks.json"
{
  echo '{'
  echo '  "version": 1,'
  echo '  "stacks": ['
  for idx in "${!STACK_NAMES[@]}"; do
    stack="${STACK_NAMES[$idx]}"
    owned_paths_json="$(default_owned_paths_json "${stack}")"
    echo '    {'
    echo "      \"name\": \"${stack}\","
    echo "      \"adapter\": \"templates/stacks/${stack}/check.adapter.sh\","
    echo '      "projects": ['
    echo '        {'
    echo '          "path": ".",'
    echo "          \"owned_paths\": ${owned_paths_json}"
    echo '        }'
    echo '      ]'
    if [[ "${idx}" -lt $(( ${#STACK_NAMES[@]} - 1 )) ]]; then
      echo '    },'
    else
      echo '    }'
    fi
  done
  echo '  ]'
  echo '}'
} > "${registry_tmp}"

REGISTRY_CHANGED=0
if [[ -f "${REGISTRY_ABS}" && "${LEGACY_FOUND}" -eq 0 ]]; then
  info "No legacy markers found and registry already exists; skipping registry rewrite"
else
  if backup_and_write "${REGISTRY_ABS}" "${registry_tmp}"; then
    REGISTRY_CHANGED=1
  fi
fi

info "Migration summary:"
info "  tasks markdown updated: ${TASKS_CHANGED}"
info "  DAG markdown updated: ${DAG_MD_CHANGED}"
info "  DAG json updated: ${DAG_JSON_CHANGED}"
info "  registry updated: ${REGISTRY_CHANGED}"

if [[ "${DRY_RUN}" -eq 1 ]]; then
  info "Dry-run complete. No files were written."
else
  info "Migration complete."
fi
