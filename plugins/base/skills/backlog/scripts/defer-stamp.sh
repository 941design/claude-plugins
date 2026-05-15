#!/usr/bin/env bash
# defer-stamp.sh — set findings[i].deferred on an existing finding.
#
# USAGE
#   defer-stamp.sh <slug> --reason <ENUM> --detail "<text>"
#                  [--stamped-at <YYYY-MM-DD>]   # default: today
#   defer-stamp.sh <slug> --clear                # un-stamp
#
# REASON ∈ {spec-gap, already-resolved, escalated, arch-debate-required, legacy-orphan}
#
# Replaces the v2 markdown stamp-mutation (Edit after the 2nd em-dash).
# Eliminates the brittle "stamp falls outside the anchored line range"
# failure mode — the stamp is now a structured field, not positional
# markdown.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

slug="${1:-}"
[[ -z "$slug" ]] && { echo "Usage: defer-stamp.sh <slug> --reason X --detail Y | --clear" >&2; exit 1; }
shift

reason=""
detail=""
stamped_at="$(today)"
clear="no"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --reason)     reason="$2"; shift 2 ;;
    --detail)     detail="$2"; shift 2 ;;
    --stamped-at) stamped_at="$2"; shift 2 ;;
    --clear)      clear="yes"; shift ;;
    *) echo "Error: unknown argument: $1" >&2; exit 1 ;;
  esac
done

if ! slug_exists "$slug"; then
  echo "Error: no finding with slug: $slug" >&2
  exit 1
fi

if [[ "$clear" == "yes" ]]; then
  mutate_backlog '
    .findings = (.findings | map(if .slug == $slug then del(.deferred) else . end))
  ' --arg slug "$slug"
  echo "Cleared defer-stamp on $slug"
  exit 0
fi

case "$reason" in
  spec-gap|already-resolved|escalated|arch-debate-required|legacy-orphan) ;;
  "") echo "Error: --reason is required" >&2; exit 1 ;;
  *)  echo "Error: invalid --reason: $reason (must be one of spec-gap|already-resolved|escalated|arch-debate-required|legacy-orphan)" >&2; exit 1 ;;
esac

[[ -z "$detail" ]] && { echo "Error: --detail is required" >&2; exit 1; }

if [[ ! "$stamped_at" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  echo "Error: --stamped-at must be YYYY-MM-DD" >&2
  exit 1
fi

stamp_json="$(jq -n \
  --arg reason "$reason" \
  --arg detail "$detail" \
  --arg stamped_at "$stamped_at" \
  '{reason: $reason, detail: $detail, stamped_at: $stamped_at}')"

mutate_backlog '
  .findings = (.findings | map(if .slug == $slug then .deferred = $stamp else . end))
' --arg slug "$slug" --argjson stamp "$stamp_json"

echo "Stamped $slug: DEFERRED:$reason:${detail:0:60}$( [[ ${#detail} -gt 60 ]] && echo … )"
