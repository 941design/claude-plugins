#!/usr/bin/env bash
# add-epic.sh — append (or update) an entry in epics[].
#
# USAGE
#   add-epic.sh --path <specs/epic-foo/> --status <STATUS> [--next-action "..."]
#
# STATUS ∈ {PLANNED, IN_PROGRESS, DONE, ESCALATED, UNKNOWN}
#
# If an entry for the same path already exists, it is updated in place
# (status + next_action). Otherwise a new entry is appended.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

path=""
status=""
next_action=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --path)        path="$2"; shift 2 ;;
    --status)      status="$2"; shift 2 ;;
    --next-action) next_action="$2"; shift 2 ;;
    *) echo "Error: unknown argument: $1" >&2; exit 1 ;;
  esac
done

[[ -z "$path" ]]   && { echo "Error: --path is required (e.g. specs/epic-foo/)" >&2; exit 1; }
[[ -z "$status" ]] && { echo "Error: --status is required" >&2; exit 1; }

if [[ ! "$path" =~ ^specs/epic-[a-z0-9-]+/$ ]]; then
  echo "Error: --path must match specs/epic-<slug>/, got: $path" >&2
  exit 1
fi

case "$status" in
  PLANNED|IN_PROGRESS|DONE|ESCALATED|UNKNOWN) ;;
  *) echo "Error: invalid --status: $status" >&2; exit 1 ;;
esac

entry_json="$(jq -n \
  --arg path "$path" \
  --arg status "$status" \
  --arg na "$next_action" \
  'if $na == "" then {path: $path, status: $status} else {path: $path, status: $status, next_action: $na} end')"

mutate_backlog '
  if any(.epics[]; .path == $e.path)
    then .epics = (.epics | map(if .path == $e.path then $e else . end))
    else .epics += [$e]
  end
' --argjson e "$entry_json"

echo "Epic $path: $status${next_action:+ — $next_action}"
