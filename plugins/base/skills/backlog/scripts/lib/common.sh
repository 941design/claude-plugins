#!/usr/bin/env bash
# common.sh — shared helpers for backlog scripts.
#
# All write scripts source this. Provides:
#   - jq availability check
#   - repo-root + BACKLOG.json location
#   - atomic write helper
#   - schema validation (jq-based; full Draft-2020-12 validation needs ajv,
#     but the critical invariants — slug uniqueness, scope/anchor/date
#     shape, required fields, deferred-reason enum — are enforced here)
#   - today's date in YYYY-MM-DD
#   - ISO-8601 timestamp

set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: 'jq' is required but not on PATH." >&2
  echo "Install jq (https://jqlang.org/) and try again." >&2
  exit 127
fi

repo_root() {
  if root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
    printf '%s\n' "$root"
  else
    echo "Error: not inside a git repository. BACKLOG.json is project state and belongs in version control." >&2
    return 1
  fi
}

backlog_path() {
  printf '%s/BACKLOG.json\n' "$(repo_root)"
}

require_backlog() {
  local p
  p="$(backlog_path)"
  if [[ ! -f "$p" ]]; then
    echo "Error: BACKLOG.json not found at $p" >&2
    echo "Run /base:backlog init first." >&2
    return 1
  fi
  printf '%s\n' "$p"
}

today() {
  date +%Y-%m-%d
}

now_iso() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

# atomic_write <target-path> <content-on-stdin>
# Reads stdin, writes to a tmp file next to target, validates JSON, then mv -f.
atomic_write() {
  local target="$1"
  local tmp
  tmp="$(mktemp "${target}.XXXXXX")"
  # shellcheck disable=SC2064
  trap "rm -f '$tmp'" RETURN
  cat >"$tmp"
  if ! jq empty "$tmp" >/dev/null 2>&1; then
    echo "Error: refusing to write — tmp file is not valid JSON. Target $target was not modified." >&2
    return 1
  fi
  mv -f "$tmp" "$target"
}

# validate_backlog <path>
# Returns 0 if the file passes structural checks. Prints first error to stderr.
# Checks: top-level shape (version, epics, findings, archive), slug
# uniqueness in findings[], required fields, enum constraints.
validate_backlog() {
  local path="$1"
  local errors
  errors="$(jq -r '
    def errors:
      [
        (if .version != 3 then "version must be 3, got: \(.version)" else empty end),
        (if (.epics | type) != "array" then "epics must be an array" else empty end),
        (if (.findings | type) != "array" then "findings must be an array" else empty end),
        (if (.archive | type) != "array" then "archive must be an array" else empty end),
        (.findings | group_by(.slug) | map(select(length > 1) | "duplicate finding slug: \(.[0].slug)") | .[]),
        (.findings[]? | select(.slug == null or .slug == "") | "finding missing slug"),
        (.findings[]? | select(.scope == null or .scope == "") | "finding \(.slug // "?") missing scope"),
        (.findings[]? | select(.text == null or .text == "") | "finding \(.slug // "?") missing text"),
        (.findings[]? | select(.created_at == null or (.created_at | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}$") | not)) | "finding \(.slug // "?") created_at must be YYYY-MM-DD"),
        (.findings[]? | select(.deferred != null) | select(.deferred.reason | IN("spec-gap","already-resolved","escalated","arch-debate-required","legacy-orphan") | not) | "finding \(.slug) has invalid deferred.reason: \(.deferred.reason)"),
        (.findings[]? | select(.anchor != null) | select((.anchor.line != null) and (.anchor.range != null)) | "finding \(.slug) anchor cannot have both line and range"),
        (.epics[]? | select((.path // "") | test("^specs/epic-[a-z0-9-]+/$") | not) | "epic path malformed: \(.path)"),
        (.epics[]? | select(.status | IN("PLANNED","IN_PROGRESS","DONE","ESCALATED","UNKNOWN") | not) | "epic \(.path) has invalid status: \(.status)"),
        (.archive[]? | select(.date == null or (.date | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}$") | not)) | "archive entry date must be YYYY-MM-DD: \(.text // "?")")
      ];
    errors | .[]
  ' "$path" 2>&1 || true)"

  if [[ -n "$errors" ]]; then
    echo "Schema validation failed for $path:" >&2
    printf '  %s\n' $errors >&2 2>/dev/null || printf '%s\n' "$errors" >&2
    return 1
  fi
}

# mutate_backlog <jq-program> [<jq-args...>]
# Reads the current BACKLOG.json, applies the jq program, stamps
# updated_at, validates, atomically writes back.
mutate_backlog() {
  local path
  path="$(require_backlog)"
  local program="$1"
  shift
  local out
  out="$(jq --indent 2 "$@" --arg now "$(now_iso)" "$program | .updated_at = \$now" "$path")"
  printf '%s\n' "$out" | atomic_write "$path"
  validate_backlog "$path"
}

# slug_exists <slug>
# Returns 0 if slug appears in findings[], non-zero otherwise.
slug_exists() {
  local slug="$1"
  local path
  path="$(require_backlog)"
  jq -e --arg s "$slug" '.findings[] | select(.slug == $s)' "$path" >/dev/null 2>&1
}
