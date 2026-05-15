#!/usr/bin/env bash
# query.sh — run an arbitrary jq expression against BACKLOG.json.
#
# USAGE
#   query.sh '<jq expression>'
#
# Thin passthrough for ad-hoc queries when list.sh's flags don't fit.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

[[ $# -lt 1 ]] && { echo "Usage: query.sh '<jq expression>'" >&2; exit 1; }

path="$(require_backlog)"
jq "$@" "$path"
