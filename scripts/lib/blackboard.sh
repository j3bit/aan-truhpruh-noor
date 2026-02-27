#!/usr/bin/env bash
set -euo pipefail

BLACKBOARD_DIR_NAME=".blackboard"

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
    "${bb_root}/events" \
    "${bb_root}/integration/waves" \
    "${bb_root}/integration/tasks" \
    "${bb_root}/feedback/qa" \
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
  local compact_payload
  local events_file
  local ts
  local status="accepted"
  local blocked_reason=""

  events_file="$(blackboard_root "${project_dir}")/events/events.jsonl"
  ts="$(blackboard_now_utc)"

  if ! stage_router_validate_route "${from_stage}" "${to_stage}"; then
    status="rejected"
    blocked_reason="non_adjacent_stage_route"
  fi

  if [[ -z "${payload_json}" ]]; then
    payload_json='{}'
  fi

  # Keep events.jsonl line-oriented by normalizing payload JSON to one compact line.
  if ! compact_payload="$(printf '%s' "${payload_json}" | perl -MJSON::PP -e '
    use strict;
    use warnings;
    local $/;
    my $raw = <STDIN>;
    my $obj = eval { decode_json($raw) };
    if ($@) {
      exit 1;
    }
    print encode_json($obj);
  ' 2>/dev/null)"; then
    compact_payload='{}'
  fi
  payload_json="${compact_payload}"

  printf '{"ts":"%s","type":"%s","from_stage":"%s","to_stage":"%s","status":"%s","blocked_reason":"%s","payload":%s}\n' \
    "${ts}" "${event_type}" "${from_stage}" "${to_stage}" "${status}" "${blocked_reason}" "${payload_json}" >> "${events_file}"

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
