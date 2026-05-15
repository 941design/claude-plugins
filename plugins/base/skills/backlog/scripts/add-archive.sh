#!/usr/bin/env bash
# add-archive.sh — append an entry directly to archive[].
#
# Used by base:project-curator's `append_rejection` action — an in-run
# abandoned approach that has no corresponding finding entry. Distinct
# from `resolve.sh --as rejected`, which closes an existing finding.
#
# USAGE
#   add-archive.sh --text "<approach>" --reason "<why rejected>" [--date YYYY-MM-DD]
#
# The archive is append-only; this script never modifies existing
# entries (use mark-archive-adr.sh for the adr-tagging case).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

text=""
reason=""
date_str="$(today)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --text)   text="$2"; shift 2 ;;
    --reason) reason="$2"; shift 2 ;;
    --date)   date_str="$2"; shift 2 ;;
    *) echo "Error: unknown argument: $1" >&2; exit 1 ;;
  esac
done

[[ -z "$text" ]]   && { echo "Error: --text is required" >&2; exit 1; }
[[ -z "$reason" ]] && { echo "Error: --reason is required" >&2; exit 1; }

if [[ ! "$date_str" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  echo "Error: --date must be YYYY-MM-DD" >&2
  exit 1
fi

entry_json="$(jq -n \
  --arg date "$date_str" \
  --arg text "$text" \
  --arg reason "$reason" \
  '{date: $date, text: $text, reason: $reason}')"

mutate_backlog '.archive += [$e]' --argjson e "$entry_json"

text_trunc="${text:0:60}"
[[ ${#text} -gt 60 ]] && text_trunc="${text_trunc}…"
echo "Archived: $text_trunc"
