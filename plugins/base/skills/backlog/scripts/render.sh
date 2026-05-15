#!/usr/bin/env bash
# render.sh — terminal-friendly rendering of BACKLOG.json.
#
# USAGE
#   render.sh [--format orient|short]
#
# FORMATS
#   orient  — full picture: ## Epics, ## Findings (open + deferred
#             split), ## Archive. Used by /base:orient.
#   short   — one-line summary (counts).
#
# This script is the canonical "show me the backlog" view for humans.
# It is read-only. To machine-consume, use list.sh --format json.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

format="orient"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --format) format="$2"; shift 2 ;;
    *) echo "Error: unknown argument: $1" >&2; exit 1 ;;
  esac
done

path="$(require_backlog)"

case "$format" in
  short)
    jq -r '"\(.epics | length) epic(s), \(.findings | map(select(.deferred == null)) | length) open finding(s), \(.findings | map(select(.deferred != null)) | length) deferred, \(.archive | length) archived"' "$path"
    ;;
  orient)
    jq -r '
      (
        "## Epics",
        (if (.epics | length) == 0
         then "  (no epics yet)"
         else (.epics[] | "  - \(.path) — \(.status)\(if .next_action then " — \(.next_action)" else "" end)")
         end),
        "",
        "## Findings (open)",
        (
          (.findings | map(select(.deferred == null))) as $open |
          if ($open | length) == 0
          then "  (no open findings)"
          else ($open[] | "  - \(.slug) [scope:\(.scope)] — \(if .anchor == null then "-" elif .anchor.range then "`\(.anchor.path):\(.anchor.range[0])-\(.anchor.range[1])`" elif .anchor.line then "`\(.anchor.path):\(.anchor.line)`" else "`\(.anchor.path)`" end) — \(.text) (\(.created_at))")
          end
        ),
        "",
        "## Findings (deferred)",
        (
          (.findings | map(select(.deferred != null))) as $def |
          if ($def | length) == 0
          then "  (none)"
          else ($def[] | "  - \(.slug) [scope:\(.scope)] — \(if .anchor == null then "-" elif .anchor.range then "`\(.anchor.path):\(.anchor.range[0])-\(.anchor.range[1])`" elif .anchor.line then "`\(.anchor.path):\(.anchor.line)`" else "`\(.anchor.path)`" end) — [DEFERRED:\(.deferred.reason)] \(.text) (\(.created_at))")
          end
        ),
        "",
        "## Archive",
        (
          if (.archive | length) == 0
          then "  (no rejections yet)"
          else (.archive[] | "  - \(.date) — \(.text) — \(.reason)\(if .adr then " [→ \(.adr)]" else "" end)")
          end
        )
      )
    ' "$path"
    ;;
  *) echo "Error: --format must be orient|short" >&2; exit 1 ;;
esac
