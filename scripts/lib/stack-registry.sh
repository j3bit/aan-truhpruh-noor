#!/usr/bin/env bash
set -euo pipefail

stack_registry_error() {
  echo "[stack-registry] ERROR: $*" >&2
}

stack_registry_resolve_path() {
  local project_dir="$1"
  local registry_path="${2:-tasks/stacks.json}"

  if [[ -z "${registry_path}" ]]; then
    registry_path="tasks/stacks.json"
  fi

  if [[ "${registry_path}" == /* ]]; then
    printf '%s\n' "${registry_path}"
  else
    printf '%s/%s\n' "${project_dir}" "${registry_path}"
  fi
}

stack_registry_collect_changed_files() {
  local project_dir="$1"
  local out_file="$2"

  : > "${out_file}"

  if ! command -v git >/dev/null 2>&1; then
    return 0
  fi

  if ! git -C "${project_dir}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    return 0
  fi

  {
    {
      git -C "${project_dir}" diff --name-only --diff-filter=ACMRTUXB
      git -C "${project_dir}" diff --cached --name-only --diff-filter=ACMRTUXB
      git -C "${project_dir}" ls-files --others --exclude-standard
    } | sed '/^$/d' | sort -u
  } > "${out_file}"
}

stack_registry_validate() {
  local registry_abs="$1"
  local project_dir="$2"

  if [[ ! -f "${registry_abs}" ]]; then
    stack_registry_error "registry file not found: ${registry_abs}"
    return 1
  fi

  if ! perl -MJSON::PP -e '
    use strict;
    use warnings;

    my ($registry_path, $project_dir) = @ARGV;
    local $/;

    open my $fh, "<", $registry_path or die "open_failed\n";
    my $raw = <$fh>;
    close $fh;

    my $obj = decode_json($raw);

    die "missing_version\n" unless exists $obj->{version};
    die "invalid_version\n" unless $obj->{version} == 1;
    die "missing_stacks\n" unless ref($obj->{stacks}) eq "ARRAY";
    die "empty_stacks\n" unless @{$obj->{stacks}};

    my %seen;

    for my $stack (@{$obj->{stacks}}) {
      die "invalid_stack_entry\n" unless ref($stack) eq "HASH";
      die "missing_stack_name\n" unless defined $stack->{name};
      my $name = $stack->{name};
      die "invalid_stack_name_${name}\n" unless $name =~ /\A[a-z0-9][a-z0-9_-]*\z/;
      die "duplicate_stack_name_${name}\n" if $seen{$name}++;

      die "missing_adapter_${name}\n" unless defined $stack->{adapter};
      my $adapter = $stack->{adapter};
      die "invalid_adapter_${name}\n" unless !ref($adapter) && $adapter ne "";

      my $adapter_abs = ($adapter =~ m{\A/}) ? $adapter : "$project_dir/$adapter";
      die "adapter_not_found_${name}_$adapter\n" unless -f $adapter_abs;

      die "missing_projects_${name}\n" unless ref($stack->{projects}) eq "ARRAY";
      die "empty_projects_${name}\n" unless @{$stack->{projects}};

      for my $project (@{$stack->{projects}}) {
        die "invalid_project_${name}\n" unless ref($project) eq "HASH";
        die "missing_project_path_${name}\n" unless defined $project->{path};
        my $path = $project->{path};
        die "invalid_project_path_${name}\n" unless !ref($path) && $path ne "";

        my $project_abs = ($path =~ m{\A/}) ? $path : "$project_dir/$path";
        die "project_dir_not_found_${name}_$path\n" unless -d $project_abs;

        die "missing_owned_paths_${name}_$path\n" unless ref($project->{owned_paths}) eq "ARRAY";
        die "empty_owned_paths_${name}_$path\n" unless @{$project->{owned_paths}};

        for my $owned (@{$project->{owned_paths}}) {
          die "invalid_owned_path_${name}_$path\n" unless defined $owned && !ref($owned) && $owned ne "";
        }
      }
    }
  ' "${registry_abs}" "${project_dir}" >/dev/null 2>&1; then
    stack_registry_error "invalid registry schema or references: ${registry_abs}"
    return 1
  fi

  return 0
}

stack_registry_list_names() {
  local registry_abs="$1"

  perl -MJSON::PP -e '
    use strict;
    use warnings;
    my ($path) = @ARGV;
    local $/;
    open my $fh, "<", $path or die;
    my $raw = <$fh>;
    close $fh;
    my $obj = decode_json($raw);
    for my $stack (@{$obj->{stacks}}) {
      print $stack->{name}, "\n";
    }
  ' "${registry_abs}"
}

stack_registry_stack_exists() {
  local registry_abs="$1"
  local stack_name="$2"

  stack_registry_list_names "${registry_abs}" | grep -Fxq "${stack_name}"
}

stack_registry_adapter_for() {
  local registry_abs="$1"
  local stack_name="$2"

  perl -MJSON::PP -e '
    use strict;
    use warnings;
    my ($path, $name) = @ARGV;
    local $/;
    open my $fh, "<", $path or die;
    my $raw = <$fh>;
    close $fh;
    my $obj = decode_json($raw);
    for my $stack (@{$obj->{stacks}}) {
      next unless $stack->{name} eq $name;
      print $stack->{adapter};
      exit 0;
    }
    exit 1;
  ' "${registry_abs}" "${stack_name}"
}

stack_registry_project_rows() {
  local registry_abs="$1"
  local stack_name="$2"

  perl -MJSON::PP -e '
    use strict;
    use warnings;
    my ($path, $name) = @ARGV;
    local $/;
    open my $fh, "<", $path or die;
    my $raw = <$fh>;
    close $fh;
    my $obj = decode_json($raw);

    for my $stack (@{$obj->{stacks}}) {
      next unless $stack->{name} eq $name;
      for my $project (@{$stack->{projects}}) {
        my $joined = join(",", @{$project->{owned_paths}});
        print $project->{path}, "|", $joined, "\n";
      }
      exit 0;
    }
    exit 1;
  ' "${registry_abs}" "${stack_name}"
}

stack_registry_glob_to_regex() {
  local glob="$1"
  local regex="^"
  local length=0
  local i=0
  local char next_char next_next_char

  length="${#glob}"
  while (( i < length )); do
    char="${glob:i:1}"
    case "${char}" in
      '*')
        next_char=""
        next_next_char=""
        if (( i + 1 < length )); then
          next_char="${glob:i+1:1}"
        fi
        if (( i + 2 < length )); then
          next_next_char="${glob:i+2:1}"
        fi

        if [[ "${next_char}" == "*" ]]; then
          if [[ "${next_next_char}" == "/" ]]; then
            # Support globstar directory semantics: zero or more directories.
            regex+="([^/]*/)*"
            i=$((i + 3))
          else
            regex+=".*"
            i=$((i + 2))
          fi
        else
          regex+="[^/]*"
          i=$((i + 1))
        fi
        ;;
      '?')
        regex+="[^/]"
        i=$((i + 1))
        ;;
      '.')
        regex+="\\."
        i=$((i + 1))
        ;;
      '^'|'$'|'+'|'('|')'|'['|']'|'{'|'}'|'|'|'\\')
        regex+="\\${char}"
        i=$((i + 1))
        ;;
      *)
        regex+="${char}"
        i=$((i + 1))
        ;;
    esac
  done

  regex+="$"
  printf '%s\n' "${regex}"
}

stack_registry_path_matches_glob() {
  local path_value="$1"
  local glob_pattern="$2"
  local regex

  regex="$(stack_registry_glob_to_regex "${glob_pattern}")"
  [[ "${path_value}" =~ ${regex} ]]
}

stack_registry_select_from_changed() {
  local registry_abs="$1"
  local changed_files_file="$2"
  local selected_tmp
  local stack_name project_path owned_csv owned_list
  local owned_path full_glob changed_file
  local stack_matched

  selected_tmp="$(mktemp)"

  while IFS= read -r stack_name; do
    [[ -n "${stack_name}" ]] || continue
    stack_matched=0

    while IFS='|' read -r project_path owned_csv; do
      [[ -n "${project_path}" ]] || continue
      owned_list="${owned_csv},"
      while [[ -n "${owned_list}" ]]; do
        owned_path="${owned_list%%,*}"
        if [[ "${owned_list}" == *,* ]]; then
          owned_list="${owned_list#*,}"
        else
          owned_list=""
        fi
        [[ -n "${owned_path}" ]] || continue

        if [[ "${project_path}" == "." ]]; then
          full_glob="${owned_path}"
        else
          full_glob="${project_path%/}/${owned_path}"
        fi
        full_glob="${full_glob#./}"

        while IFS= read -r changed_file; do
          [[ -n "${changed_file}" ]] || continue
          changed_file="${changed_file#./}"
          if stack_registry_path_matches_glob "${changed_file}" "${full_glob}"; then
            stack_matched=1
            break
          fi
        done < "${changed_files_file}"

        if [[ "${stack_matched}" -eq 1 ]]; then
          break
        fi
      done

      if [[ "${stack_matched}" -eq 1 ]]; then
        break
      fi
    done < <(stack_registry_project_rows "${registry_abs}" "${stack_name}")

    if [[ "${stack_matched}" -eq 1 ]]; then
      printf '%s\n' "${stack_name}" >> "${selected_tmp}"
    fi
  done < <(stack_registry_list_names "${registry_abs}")

  while IFS= read -r stack_name; do
    [[ -n "${stack_name}" ]] || continue
    if grep -Fxq "${stack_name}" "${selected_tmp}"; then
      printf '%s\n' "${stack_name}"
    fi
  done < <(stack_registry_list_names "${registry_abs}")

  rm -f "${selected_tmp}"
}

stack_registry_csv_to_lines() {
  local csv="$1"
  printf '%s\n' "${csv}" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed '/^$/d'
}

stack_registry_csv_normalize() {
  local csv="$1"
  stack_registry_csv_to_lines "${csv}" | awk '!seen[$0]++'
}
