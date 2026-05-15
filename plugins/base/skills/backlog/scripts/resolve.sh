#!/usr/bin/env bash
# resolve.sh — close a finding via one of four resolution paths.
#
# USAGE
#   resolve.sh <slug> --as done-mechanical
#   resolve.sh <slug> --as done --target <spec-path>
#   resolve.sh <slug> --as rejected --reason "<text>"
#   resolve.sh <slug> --as promoted --target <spec-path>
#
# RESOLUTION PATHS (see references/format.md ## Resolution paths)
#   done             — finding removed; caller is responsible for the
#                      spec amendment (this script only mutates BACKLOG.json).
#                      Pass --target to record the spec path that received
#                      the amendment; recorded in the resolve log only.
#   done-mechanical  — finding removed. Git is the record. No spec
#                      change, no archive entry.
#   rejected         — finding removed AND appended to ## Archive with
#                      verbatim text + reason. Never expires.
#   promoted         — finding removed; caller (typically /base:feature
#                      backlog:<slug>) is responsible for creating the
#                      specs/epic-*/ dir and adding the epic via
#                      add-epic.sh. No archive entry.
#
# EXIT CODES
#   0  finding resolved
#   1  invalid input or no such slug

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

slug="${1:-}"
[[ -z "$slug" ]] && { echo "Usage: resolve.sh <slug> --as <done|done-mechanical|rejected|promoted> [...]" >&2; exit 1; }
shift

action=""
target=""
reason=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --as)     action="$2"; shift 2 ;;
    --target) target="$2"; shift 2 ;;
    --reason) reason="$2"; shift 2 ;;
    *) echo "Error: unknown argument: $1" >&2; exit 1 ;;
  esac
done

if ! slug_exists "$slug"; then
  echo "Error: no finding with slug: $slug" >&2
  exit 1
fi

path="$(require_backlog)"

case "$action" in
  done-mechanical|promoted)
    mutate_backlog '
      .findings = (.findings | map(select(.slug != $slug)))
    ' --arg slug "$slug"
    echo "Resolved $slug as $action."
    ;;

  done)
    [[ -z "$target" ]] && { echo "Error: --target is required for --as done (spec path that received the amendment)" >&2; exit 1; }
    mutate_backlog '
      .findings = (.findings | map(select(.slug != $slug)))
    ' --arg slug "$slug"
    echo "Resolved $slug as done→spec:$target."
    echo "  (Spec amendment is the caller's responsibility; this script only mutates BACKLOG.json.)"
    ;;

  rejected)
    [[ -z "$reason" ]] && { echo "Error: --reason is required for --as rejected" >&2; exit 1; }
    finding_json="$(jq --arg slug "$slug" '.findings[] | select(.slug == $slug)' "$path")"
    finding_text="$(printf '%s' "$finding_json" | jq -r '.text')"
    today_str="$(today)"
    mutate_backlog '
      .findings = (.findings | map(select(.slug != $slug)))
      | .archive += [{
          date: $today,
          text: $text,
          reason: $reason,
          source_slug: $slug
        }]
    ' --arg slug "$slug" --arg today "$today_str" --arg text "$finding_text" --arg reason "$reason"
    echo "Resolved $slug as rejected: $reason"
    echo "  Archived under $today_str."
    ;;

  "")
    echo "Error: --as is required (done|done-mechanical|rejected|promoted)" >&2
    exit 1
    ;;
  *)
    echo "Error: invalid --as value: $action" >&2
    exit 1
    ;;
esac
