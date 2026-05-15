#!/usr/bin/env bash
# list.sh — filter and print findings.
#
# USAGE
#   list.sh [--status open|deferred|all] [--scope <X>] [--scope-prefix <X>]
#           [--format json|table|compact] [--include-archive]
#
# DEFAULTS
#   --status open       — exclude deferred findings (most common case)
#   --format compact    — one-line-per-finding, scannable in a terminal
#
# FILTERS
#   --status open       — findings with no .deferred
#   --status deferred   — findings with .deferred
#   --status all        — both
#   --scope X           — exact scope match
#   --scope-prefix X    — scope or anchor.path starts with X (e.g.
#                         "plugins/base/" surfaces all base-plugin work)
#   --include-archive   — also print ## Archive entries
#
# EXIT CODES
#   0  success (regardless of count)
#   1  BACKLOG.json missing

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

status_filter="open"
scope=""
scope_prefix=""
format="compact"
include_archive="no"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --status)          status_filter="$2"; shift 2 ;;
    --scope)           scope="$2"; shift 2 ;;
    --scope-prefix)    scope_prefix="$2"; shift 2 ;;
    --format)          format="$2"; shift 2 ;;
    --include-archive) include_archive="yes"; shift ;;
    --help|-h)
      sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Error: unknown argument: $1" >&2; exit 1 ;;
  esac
done

path="$(require_backlog)"

# Build the jq filter
filter='.findings'
case "$status_filter" in
  open)     filter="$filter | map(select(.deferred == null))" ;;
  deferred) filter="$filter | map(select(.deferred != null))" ;;
  all)      ;;
  *) echo "Error: --status must be open|deferred|all" >&2; exit 1 ;;
esac

if [[ -n "$scope" ]]; then
  filter="$filter | map(select(.scope == \$scope))"
fi

if [[ -n "$scope_prefix" ]]; then
  filter="$filter | map(select((.scope == \$pfx) or ((.anchor.path // \"\") | startswith(\$pfx))))"
fi

case "$format" in
  json)
    jq --arg scope "$scope" --arg pfx "$scope_prefix" "$filter" "$path"
    ;;
  table)
    # Use awk for tab-aligned output instead of column(1) — portable.
    jq --arg scope "$scope" --arg pfx "$scope_prefix" -r "$filter | (
      [\"SLUG\",\"SCOPE\",\"ANCHOR\",\"STATUS\",\"DATE\"],
      (.[] | [
        .slug,
        .scope,
        (if .anchor == null then \"-\" elif .anchor.range then \"\(.anchor.path):\(.anchor.range[0])-\(.anchor.range[1])\" elif .anchor.line then \"\(.anchor.path):\(.anchor.line)\" else .anchor.path end),
        (if .deferred then \"DEFERRED:\(.deferred.reason)\" else \"open\" end),
        .created_at
      ])
    ) | @tsv" "$path" \
      | awk -F'\t' '
          { for (i = 1; i <= NF; i++) { if (length($i) > w[i]) w[i] = length($i); rows[NR, i] = $i } NRECS = NR; NFIELDS = (NF > NFIELDS ? NF : NFIELDS) }
          END {
            for (r = 1; r <= NRECS; r++) {
              for (c = 1; c <= NFIELDS; c++) {
                printf "%-*s%s", w[c], rows[r, c], (c < NFIELDS ? "  " : "\n")
              }
            }
          }'
    ;;
  compact)
    jq --arg scope "$scope" --arg pfx "$scope_prefix" -r "$filter[] | (
      \"\(.slug) [scope:\(.scope)] \" +
      (if .anchor == null then \"- \" elif .anchor.range then \"\(.anchor.path):\(.anchor.range[0])-\(.anchor.range[1]) \" elif .anchor.line then \"\(.anchor.path):\(.anchor.line) \" else \"\(.anchor.path) \" end) +
      (if .deferred then \"[DEFERRED:\(.deferred.reason)] \" else \"\" end) +
      .text +
      \" (\(.created_at))\"
    )" "$path"
    ;;
  *) echo "Error: --format must be json|table|compact" >&2; exit 1 ;;
esac

if [[ "$include_archive" == "yes" ]]; then
  echo
  echo "--- Archive ---"
  case "$format" in
    json)    jq '.archive' "$path" ;;
    table|compact)
      jq -r '.archive[] | "\(.date) — \(.text) — \(.reason)\(if .adr then " [→ \(.adr)]" else "" end)"' "$path"
      ;;
  esac
fi
