#!/usr/bin/env bash
# get.sh — fetch a single finding by slug.
#
# USAGE
#   get.sh <slug>           # prints the finding as JSON; exit 1 if not found
#   get.sh <slug> --field text   # print one field as a raw string

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

slug="${1:-}"
[[ -z "$slug" ]] && { echo "Usage: get.sh <slug> [--field <name>]" >&2; exit 1; }
shift || true

field=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --field) field="$2"; shift 2 ;;
    *) echo "Error: unknown argument: $1" >&2; exit 1 ;;
  esac
done

path="$(require_backlog)"

if [[ -n "$field" ]]; then
  out="$(jq -r --arg slug "$slug" --arg field "$field" '.findings[] | select(.slug == $slug) | .[$field] // empty' "$path")"
  if [[ -z "$out" ]]; then
    echo "Error: no finding with slug $slug (or field $field empty)" >&2
    exit 1
  fi
  printf '%s\n' "$out"
else
  out="$(jq --arg slug "$slug" '.findings[] | select(.slug == $slug)' "$path")"
  if [[ -z "$out" ]]; then
    echo "Error: no finding with slug $slug" >&2
    exit 1
  fi
  printf '%s\n' "$out"
fi
