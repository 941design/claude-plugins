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
# Returns 0 if the file passes structural checks. Prints errors to stderr.
# Enforces every invariant the schema declares: top-level shape, slug
# uniqueness, required fields, slug/scope/date patterns, enum
# constraints, anchor mutual-exclusion. Update both this function and
# plugins/base/schemas/backlog.schema.json when adding fields.
validate_backlog() {
  local path="$1"
  # First: is the file even valid JSON?
  if ! jq empty "$path" >/dev/null 2>&1; then
    echo "Schema validation failed for $path: not valid JSON" >&2
    return 1
  fi
  local errors
  errors="$(jq -r '
    def kebab: test("^[a-z0-9][a-z0-9-]*$");
    def ymd:   test("^[0-9]{4}-[0-9]{2}-[0-9]{2}$");
    def deferred_reasons: ["spec-gap","already-resolved","escalated","arch-debate-required","legacy-orphan"];
    def epic_statuses:    ["PLANNED","IN_PROGRESS","DONE","ESCALATED","UNKNOWN"];

    [
      (if .version != 3 then "version must be 3, got: \(.version)" else empty end),
      (if (.epics // null) | type != "array" then "epics must be an array" else empty end),
      (if (.findings // null) | type != "array" then "findings must be an array" else empty end),
      (if (.archive // null) | type != "array" then "archive must be an array" else empty end),

      (.findings | group_by(.slug) | map(select(length > 1) | "duplicate finding slug: \(.[0].slug)") | .[]),

      (.findings[]? | select((.slug // "") == "" or ((.slug // "") | kebab | not)) | "finding slug invalid: \(.slug // "<null>")"),
      (.findings[]? | select((.slug // "") | length > 53) | "finding slug exceeds 53 chars (50 base + up to -99 suffix): \(.slug)"),
      (.findings[]? | select((.scope // "") == "" or ((.scope // "") | kebab | not)) | "finding \(.slug // "?") scope invalid: \(.scope // "<null>")"),
      (.findings[]? | select((.text // "") == "") | "finding \(.slug // "?") missing text"),
      (.findings[]? | select((.created_at // "") | ymd | not) | "finding \(.slug // "?") created_at must be YYYY-MM-DD"),

      (.findings[]? | select(.deferred != null) | select((.deferred.reason // "") | IN(deferred_reasons[]) | not) | "finding \(.slug) has invalid deferred.reason: \(.deferred.reason // "<null>")"),
      (.findings[]? | select(.deferred != null) | select((.deferred.detail // "") == "") | "finding \(.slug) deferred.detail missing"),
      (.findings[]? | select(.deferred != null) | select((.deferred.stamped_at // "") | ymd | not) | "finding \(.slug) deferred.stamped_at must be YYYY-MM-DD"),

      (.findings[]? | select(.anchor != null) | select((.anchor.path // "") == "") | "finding \(.slug) anchor missing path"),
      (.findings[]? | select(.anchor != null) | select((.anchor.line != null) and (.anchor.range != null)) | "finding \(.slug) anchor cannot have both line and range"),
      (.findings[]? | select(.anchor != null and .anchor.range != null) | select((.anchor.range | type) != "array" or (.anchor.range | length) != 2) | "finding \(.slug) anchor.range must be [start, end]"),

      (.epics[]? | select((.path // "") | test("^specs/epic-[a-z0-9-]+/$") | not) | "epic path malformed: \(.path // "<null>")"),
      (.epics[]? | select((.status // "") | IN(epic_statuses[]) | not) | "epic \(.path) has invalid status: \(.status // "<null>")"),

      (.archive[]? | select((.date // "") | ymd | not) | "archive entry date must be YYYY-MM-DD: \(.text // "?")"),
      (.archive[]? | select((.text // "") == "") | "archive entry missing text"),
      (.archive[]? | select((.reason // "") == "") | "archive entry missing reason: \(.text)"),
      (.archive[]? | select(.adr != null) | select((.adr // "") | test("^ADR-[0-9]+$") | not) | "archive entry has invalid adr: \(.adr)")
    ] | .[]
  ' "$path" 2>&1 || true)"

  if [[ -n "$errors" ]]; then
    echo "Schema validation failed for $path:" >&2
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      printf '  %s\n' "$line" >&2
    done <<< "$errors"
    return 1
  fi
}

# mutate_backlog <jq-program> [<jq-args...>]
# Reads the current BACKLOG.json, applies the jq program, stamps
# updated_at, validates the proposed content against the schema, then
# atomically writes back ONLY if validation passes. If validation fails,
# the on-disk file is untouched and the script exits non-zero — this is
# the safety guarantee every writer relies on.
mutate_backlog() {
  local path
  path="$(require_backlog)"
  local program="$1"
  shift
  local out
  out="$(jq --indent 2 "$@" --arg now "$(now_iso)" "$program | .updated_at = \$now" "$path")"
  # Validate the proposed content via a scratch file BEFORE replacing the
  # canonical target. The scratch file is under $TMPDIR, not next to the
  # target, so a validation failure cannot leave a half-written sibling
  # next to BACKLOG.json.
  local scratch
  scratch="$(mktemp)"
  # shellcheck disable=SC2064
  trap "rm -f '$scratch'" RETURN
  printf '%s\n' "$out" > "$scratch"
  if ! validate_backlog "$scratch"; then
    echo "Error: refusing to write — mutation produced schema-invalid JSON. $path was not modified." >&2
    return 1
  fi
  # Validation passed; commit atomically.
  printf '%s\n' "$out" | atomic_write "$path"
}

# slug_exists <slug>
# Returns 0 if slug appears in findings[], non-zero otherwise.
slug_exists() {
  local slug="$1"
  local path
  path="$(require_backlog)"
  jq -e --arg s "$slug" '.findings[] | select(.slug == $s)' "$path" >/dev/null 2>&1
}

# classify_epic_status <epic-dir>
# Emits one of PLANNED / IN_PROGRESS / DONE / ESCALATED / UNKNOWN by
# aggregating on-disk evidence (epic-state.json, spec.md done markers,
# story dirs). No literal-value synonym table — non-canonical state
# values do not collapse the epic into UNKNOWN; the spec marker or
# story evidence reaches the right verdict instead.
#
# This is the single canonical classifier used by /base:backlog init,
# /base:backlog migrate-v3, /base:next-epic, and /base:orient Rule 2.
# Keep it in sync with base:next-epic Step 2 (the user-facing prose).
classify_epic_status() {
  local epic_dir="$1"
  local state_file="$epic_dir/epic-state.json"
  local spec_file="$epic_dir/spec.md"
  local state_status="" state_phase=""
  local state_escalated=0 spec_done=0
  local stories_total=0 stories_done=0
  local has_story_dirs=0

  [[ -f "$spec_file" ]] || { echo "UNKNOWN"; return; }

  if [[ -f "$state_file" ]]; then
    state_status="$(jq -r '.status // ""' "$state_file" 2>/dev/null || true)"
    state_phase="$(jq -r '.phase  // ""' "$state_file" 2>/dev/null || true)"
    if jq -e '.escalated // .escalation // empty' "$state_file" >/dev/null 2>&1; then
      state_escalated=1
    fi
  fi

  if grep -E -q '^(#+ Implementation Summary|#+ Done|Status:[[:space:]]+Implemented)' "$spec_file" 2>/dev/null; then
    spec_done=1
  fi

  local d
  for d in "$epic_dir"/S[0-9]*-*/; do
    [[ -d "$d" ]] || continue
    has_story_dirs=1
    if [[ -f "$d/result.json" ]]; then
      stories_total=$((stories_total + 1))
      if jq -e '.status == "done" or .done == true' "$d/result.json" >/dev/null 2>&1; then
        stories_done=$((stories_done + 1))
      fi
    fi
  done

  if [[ "$state_escalated" -eq 1 || "$state_status" == "escalated" ]]; then
    echo "ESCALATED"; return
  fi
  if [[ "$state_status" == "done" || "$spec_done" -eq 1 ]]; then
    echo "DONE"; return
  fi
  if [[ "$stories_total" -gt 0 && "$stories_done" -eq "$stories_total" ]]; then
    echo "DONE"; return
  fi
  if [[ "$state_status" == "planning" || "$state_status" == "in_progress" ]]; then
    echo "IN_PROGRESS"; return
  fi
  if [[ -n "$state_phase" || "$has_story_dirs" -eq 1 ]]; then
    echo "IN_PROGRESS"; return
  fi
  if [[ -f "$state_file" && -n "$state_status" ]]; then
    # Writer set something non-canonical and no other evidence either way —
    # bias to IN_PROGRESS so RESUME mode's RECONCILE surfaces it.
    echo "IN_PROGRESS"; return
  fi
  echo "PLANNED"
}
