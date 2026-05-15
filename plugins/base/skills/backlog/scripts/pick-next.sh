#!/usr/bin/env bash
# pick-next.sh — deterministic top-candidate selector.
#
# USAGE
#   pick-next.sh [--scope <X>] [--scope-prefix <X>]
#                [--include-deferred]
#                [--format slug|json]
#
# SELECTION RULES (deterministic — no LLM)
#   1. Filter findings to active scope:
#        - If --scope X is given: keep only findings with scope==X or
#          scope=="any" (any is always in scope).
#        - If --scope-prefix X is given: keep findings whose scope==X
#          or whose anchor.path starts with X, OR scope=="any".
#        - Else: keep all findings.
#   2. Exclude deferred findings unless --include-deferred.
#   3. Sort by created_at ascending (oldest first — fairness; the
#      newest-first variant is available via --newest if needed later).
#   4. Return the first candidate, or exit 1 if none.
#
# This is the entrypoint a programmatic /base:next auto dispatch
# should use when the LLM is not in the loop. The interactive form of
# /base:next may still rank with prose reasoning.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

scope=""
scope_prefix=""
include_deferred="no"
format="slug"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scope)             scope="$2"; shift 2 ;;
    --scope-prefix)      scope_prefix="$2"; shift 2 ;;
    --include-deferred)  include_deferred="yes"; shift ;;
    --format)            format="$2"; shift 2 ;;
    *) echo "Error: unknown argument: $1" >&2; exit 1 ;;
  esac
done

path="$(require_backlog)"

filter='.findings'

# Scope filter — note that "any" passes regardless
if [[ -n "$scope" ]]; then
  filter="$filter | map(select(.scope == \$scope or .scope == \"any\"))"
elif [[ -n "$scope_prefix" ]]; then
  filter="$filter | map(select((.scope == \$pfx) or (.scope == \"any\") or ((.anchor.path // \"\") | startswith(\$pfx))))"
fi

if [[ "$include_deferred" != "yes" ]]; then
  filter="$filter | map(select(.deferred == null))"
fi

filter="$filter | sort_by(.created_at) | .[0] // empty"

result="$(jq --arg scope "$scope" --arg pfx "$scope_prefix" "$filter" "$path")"

if [[ -z "$result" || "$result" == "null" ]]; then
  echo "No actionable findings." >&2
  exit 1
fi

case "$format" in
  slug) printf '%s\n' "$result" | jq -r '.slug' ;;
  json) printf '%s\n' "$result" | jq . ;;
  *)    echo "Error: --format must be slug|json" >&2; exit 1 ;;
esac
