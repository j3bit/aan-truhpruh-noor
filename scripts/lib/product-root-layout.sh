#!/usr/bin/env bash
set -euo pipefail

product_root_error() {
  echo "[product-root] ERROR: $*" >&2
}

product_root_required_dirs() {
  cat <<'EOF_DIRS'
apps
packages
tests
tests/integration
infra
infra/env
docs/adr
docs/specs
EOF_DIRS
}

product_root_default_owned_paths_json() {
  local stack="$1"

  case "${stack}" in
    python)
      cat <<'EOF_JSON'
["apps/**/*.py","packages/**/*.py","tests/**/*.py","pyproject.toml","requirements*.txt","setup.py","apps/**/pyproject.toml","packages/**/pyproject.toml","tests/**/pyproject.toml","apps/**/requirements*.txt","packages/**/requirements*.txt","tests/**/requirements*.txt","apps/**/setup.py","packages/**/setup.py","tests/**/setup.py"]
EOF_JSON
      ;;
    node)
      cat <<'EOF_JSON'
["apps/**/*.{js,jsx,mjs,cjs,ts,tsx}","packages/**/*.{js,jsx,mjs,cjs,ts,tsx}","tests/**/*.{js,jsx,mjs,cjs,ts,tsx}","package.json","package-lock.json","pnpm-lock.yaml","yarn.lock","apps/**/package.json","packages/**/package.json","tests/**/package.json","apps/**/package-lock.json","packages/**/package-lock.json","tests/**/package-lock.json","apps/**/pnpm-lock.yaml","packages/**/pnpm-lock.yaml","tests/**/pnpm-lock.yaml","apps/**/yarn.lock","packages/**/yarn.lock","tests/**/yarn.lock"]
EOF_JSON
      ;;
    go)
      cat <<'EOF_JSON'
["apps/**/*.go","packages/**/*.go","tests/**/*.go","go.mod","go.sum","go.work","apps/**/go.mod","packages/**/go.mod","tests/**/go.mod","apps/**/go.sum","packages/**/go.sum","tests/**/go.sum"]
EOF_JSON
      ;;
    *)
      cat <<'EOF_JSON'
["apps/**","packages/**","tests/**","infra/**"]
EOF_JSON
      ;;
  esac
}

product_root_scaffold_readme() {
  local rel_dir="$1"

  case "${rel_dir}" in
    apps)
      cat <<'EOF_README'
# Apps

Deployable product applications live here. Create one directory per app or runtime boundary.
EOF_README
      ;;
    packages)
      cat <<'EOF_README'
# Packages

Reusable libraries and shared modules live here. Apps may depend on packages; packages must not depend on app internals.
EOF_README
      ;;
    tests)
      cat <<'EOF_README'
# Tests

Cross-cutting integration and end-to-end tests live here. Keep product code in `apps/` or `packages/`.
EOF_README
      ;;
    infra)
      cat <<'EOF_README'
# Infra

Environment, deployment, and operational configuration live here.
EOF_README
      ;;
    docs/adr)
      cat <<'EOF_README'
# ADR

Record architecture decisions here.
EOF_README
      ;;
    docs/specs)
      cat <<'EOF_README'
# Specs

Store API, protocol, and interface specifications here.
EOF_README
      ;;
    tests/integration)
      cat <<'EOF_README'
# Integration Tests

Put multi-component integration tests here.
EOF_README
      ;;
    infra/env)
      cat <<'EOF_README'
# Environment

Environment-specific configuration belongs here.
EOF_README
      ;;
    *)
      return 1
      ;;
  esac
}

product_root_write_missing_readme() {
  local project_dir="$1"
  local rel_dir="$2"
  local readme_path="${project_dir}/${rel_dir}/README.md"

  if [[ -f "${readme_path}" ]]; then
    return 0
  fi

  mkdir -p "$(dirname "${readme_path}")"
  product_root_scaffold_readme "${rel_dir}" > "${readme_path}"
}

product_root_ensure_scaffold() {
  local project_dir="$1"
  local rel_dir=""

  while IFS= read -r rel_dir; do
    [[ -n "${rel_dir}" ]] || continue
    mkdir -p "${project_dir}/${rel_dir}"
  done < <(product_root_required_dirs)

  product_root_write_missing_readme "${project_dir}" "apps"
  product_root_write_missing_readme "${project_dir}" "packages"
  product_root_write_missing_readme "${project_dir}" "tests"
  product_root_write_missing_readme "${project_dir}" "tests/integration"
  product_root_write_missing_readme "${project_dir}" "infra"
  product_root_write_missing_readme "${project_dir}" "infra/env"
  product_root_write_missing_readme "${project_dir}" "docs/adr"
  product_root_write_missing_readme "${project_dir}" "docs/specs"
}

product_root_write_stack_registry() {
  local project_dir="$1"
  shift

  local stacks=("$@")
  local registry_path="${project_dir}/tasks/stacks.json"
  local tmp_file=""
  local idx=0
  local stack=""
  local owned_paths_json=""

  if [[ "${#stacks[@]}" -eq 0 ]]; then
    product_root_error "at least one stack is required to write tasks/stacks.json"
    return 1
  fi

  mkdir -p "$(dirname "${registry_path}")"
  tmp_file="$(mktemp "${TMPDIR:-/tmp}/product-root-registry.XXXXXX")"

  {
    echo '{'
    echo '  "version": 1,'
    echo '  "stacks": ['

    for idx in "${!stacks[@]}"; do
      stack="${stacks[$idx]}"
      owned_paths_json="$(product_root_default_owned_paths_json "${stack}")"

      echo '    {'
      echo "      \"name\": \"${stack}\","
      echo "      \"adapter\": \"templates/stacks/${stack}/check.adapter.sh\","
      echo '      "projects": ['
      echo '        {'
      echo '          "path": ".",'
      echo "          \"owned_paths\": ${owned_paths_json}"
      echo '        }'
      echo '      ]'

      if [[ "${idx}" -lt $(( ${#stacks[@]} - 1 )) ]]; then
        echo '    },'
      else
        echo '    }'
      fi
    done

    echo '  ]'
    echo '}'
  } > "${tmp_file}"

  mv "${tmp_file}" "${registry_path}"
}

product_root_validate_registry_policy() {
  local registry_abs="$1"

  perl -MJSON::PP -e '
    use strict;
    use warnings;

    my ($path) = @ARGV;
    local $/;

    open my $fh, "<", $path or die "open_failed\n";
    my $obj = decode_json(<$fh>);
    close $fh;

    die "missing_stacks\n" unless ref($obj->{stacks}) eq "ARRAY";

    for my $stack (@{$obj->{stacks}}) {
      die "invalid_stack\n" unless ref($stack) eq "HASH";
      die "missing_projects\n" unless ref($stack->{projects}) eq "ARRAY";

      for my $project (@{$stack->{projects}}) {
        die "invalid_project\n" unless ref($project) eq "HASH";
        die "non_root_project_path\n" unless $project->{path} eq ".";
        die "missing_owned_paths\n" unless ref($project->{owned_paths}) eq "ARRAY";

        for my $owned (@{$project->{owned_paths}}) {
          die "invalid_owned_path\n" unless defined $owned && !ref($owned) && $owned ne "";
          die "forbidden_owned_prefix\n" if $owned =~ m{\A(?:services|examples)(?:/|$)};
        }
      }
    }
  ' "${registry_abs}" >/dev/null 2>&1
}
