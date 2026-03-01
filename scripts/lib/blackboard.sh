#!/usr/bin/env bash
set -euo pipefail

BLACKBOARD_DIR_NAME=".blackboard"

blackboard_ensure_stage_router() {
  local lib_dir stage_router_path

  if declare -F stage_router_validate_route >/dev/null 2>&1; then
    return 0
  fi

  lib_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  stage_router_path="${lib_dir}/stage-router.sh"

  if [[ -f "${stage_router_path}" ]]; then
    # shellcheck source=/dev/null
    source "${stage_router_path}"
  fi

  declare -F stage_router_validate_route >/dev/null 2>&1
}

blackboard_now_utc() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

blackboard_root() {
  local project_dir="$1"
  printf '%s/%s' "${project_dir}" "${BLACKBOARD_DIR_NAME}"
}

blackboard_init() {
  local project_dir="$1"
  local bb_root

  bb_root="$(blackboard_root "${project_dir}")"

  mkdir -p \
    "${bb_root}/artifacts" \
    "${bb_root}/artifacts/qa" \
    "${bb_root}/events" \
    "${bb_root}/integration/waves" \
    "${bb_root}/integration/tasks" \
    "${bb_root}/feedback/qa" \
    "${bb_root}/feedback/integration" \
    "${bb_root}/jobs" \
    "${bb_root}/state"

  : > "${bb_root}/events/events.jsonl"
}

blackboard_write_json() {
  local project_dir="$1"
  local rel_path="$2"
  local json_content="$3"
  local abs_path

  abs_path="$(blackboard_root "${project_dir}")/${rel_path}"
  mkdir -p "$(dirname "${abs_path}")"
  printf '%s\n' "${json_content}" > "${abs_path}"
}

blackboard_emit_event() {
  local project_dir="$1"
  local event_type="$2"
  local from_stage="$3"
  local to_stage="$4"
  local payload_json="${5:-}"
  local event_json
  local events_file
  local ts
  local status="accepted"
  local blocked_reason=""

  events_file="$(blackboard_root "${project_dir}")/events/events.jsonl"
  ts="$(blackboard_now_utc)"

  if ! blackboard_ensure_stage_router; then
    status="rejected"
    blocked_reason="non_adjacent_stage_route"
  elif ! stage_router_validate_route "${from_stage}" "${to_stage}"; then
    status="rejected"
    blocked_reason="non_adjacent_stage_route"
  fi

  if [[ -z "${payload_json}" ]]; then
    payload_json='{}'
  fi

  # Emit one JSON object per line by encoding the full event in Perl.
  event_json="$(perl -MJSON::PP -e '
    use strict;
    use warnings;
    my ($ts, $type, $from, $to, $status, $blocked_reason, $payload_raw) = @ARGV;
    my $payload = eval { decode_json($payload_raw) };
    if ($@) {
      $payload = {};
    }
    my %event = (
      ts => $ts,
      type => $type,
      from_stage => $from,
      to_stage => $to,
      status => $status,
      blocked_reason => $blocked_reason,
      payload => $payload,
    );
    print encode_json(\%event);
  ' "${ts}" "${event_type}" "${from_stage}" "${to_stage}" "${status}" "${blocked_reason}" "${payload_json}" 2>/dev/null || true)"

  if [[ -z "${event_json}" ]]; then
    event_json="$(perl -MJSON::PP -e '
      use strict;
      use warnings;
      my ($ts, $type, $from, $to, $status, $blocked_reason) = @ARGV;
      my %event = (
        ts => $ts,
        type => $type,
        from_stage => $from,
        to_stage => $to,
        status => $status,
        blocked_reason => $blocked_reason,
        payload => {},
      );
      print encode_json(\%event);
    ' "${ts}" "${event_type}" "${from_stage}" "${to_stage}" "${status}" "${blocked_reason}" 2>/dev/null || true)"
  fi

  printf '%s\n' "${event_json}" >> "${events_file}"

  [[ "${status}" == "accepted" ]]
}

blackboard_event_count() {
  local project_dir="$1"
  local type="$2"
  local events_file

  events_file="$(blackboard_root "${project_dir}")/events/events.jsonl"
  if [[ ! -f "${events_file}" ]]; then
    printf '0'
    return
  fi

  grep -c "\"type\":\"${type}\"" "${events_file}" || true
}
