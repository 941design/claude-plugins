#!/usr/bin/env bash
# add-finding.sh — append a slug-keyed, scope-tagged finding.
#
# USAGE
#   add-finding.sh \
#     --text "<one-line text>" \
#     --anchor <path[:line]|path:N-M|-> \
#     [--scope <X>]            # default: inferred from anchor
#     [--slug <slug>]          # default: derived from text
#     [--created <YYYY-MM-DD>] # default: today
#
# RULES
#   - text and anchor are required.
#   - scope inference (when --scope omitted):
#       anchor starts with plugins/base/    → base-plugin
#       anchor starts with plugins/<name>/  → <name>
#       anchor is `-` or no match           → any
#   - slug derivation (when --slug omitted) follows derive-slug.sh.
#     Collision → append -2, -3, ... at write time.
#
# EXIT CODES
#   0  finding added; slug printed to stdout
#   1  invalid input (missing required field, bad format)
#   2  slug derivation failed (text too short)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

text=""
anchor_raw=""
scope=""
slug=""
created="$(today)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --text)    text="$2"; shift 2 ;;
    --anchor)  anchor_raw="$2"; shift 2 ;;
    --scope)   scope="$2"; shift 2 ;;
    --slug)    slug="$2"; shift 2 ;;
    --created) created="$2"; shift 2 ;;
    --help|-h)
      sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "Error: unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

[[ -z "$text" ]]       && { echo "Error: --text is required" >&2; exit 1; }
[[ -z "$anchor_raw" ]] && { echo "Error: --anchor is required (use - for cross-cutting)" >&2; exit 1; }

if [[ ! "$created" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  echo "Error: --created must be YYYY-MM-DD, got: $created" >&2
  exit 1
fi

# ---- parse anchor --------------------------------------------------------
anchor_json="null"
if [[ "$anchor_raw" != "-" ]]; then
  # Support path, path:line, path:N-M
  if [[ "$anchor_raw" =~ ^(.+):([0-9]+)-([0-9]+)$ ]]; then
    anchor_json="$(jq -n --arg p "${BASH_REMATCH[1]}" --argjson s "${BASH_REMATCH[2]}" --argjson e "${BASH_REMATCH[3]}" '{path: $p, range: [$s, $e]}')"
  elif [[ "$anchor_raw" =~ ^(.+):([0-9]+)$ ]]; then
    anchor_json="$(jq -n --arg p "${BASH_REMATCH[1]}" --argjson l "${BASH_REMATCH[2]}" '{path: $p, line: $l}')"
  else
    anchor_json="$(jq -n --arg p "$anchor_raw" '{path: $p}')"
  fi
fi

# ---- infer scope ---------------------------------------------------------
if [[ -z "$scope" ]]; then
  if [[ "$anchor_raw" == "-" ]]; then
    scope="any"
  elif [[ "$anchor_raw" =~ ^plugins/base/ ]]; then
    scope="base-plugin"
  elif [[ "$anchor_raw" =~ ^plugins/([a-z0-9-]+)/ ]]; then
    scope="${BASH_REMATCH[1]}"
  else
    scope="any"
  fi
fi

if [[ ! "$scope" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
  echo "Error: invalid --scope: $scope (must match ^[a-z0-9][a-z0-9-]*\$)" >&2
  exit 1
fi

# ---- derive slug ---------------------------------------------------------
if [[ -z "$slug" ]]; then
  if ! slug="$("$SCRIPT_DIR/derive-slug.sh" "$text")"; then
    exit 2
  fi
fi

if [[ ! "$slug" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
  echo "Error: invalid --slug: $slug (must match ^[a-z0-9][a-z0-9-]*\$)" >&2
  exit 1
fi

# ---- collision handling --------------------------------------------------
base_slug="$slug"
n=2
while slug_exists "$slug"; do
  slug="${base_slug}-${n}"
  n=$((n + 1))
done

# ---- compose + write -----------------------------------------------------
finding_json="$(jq -n \
  --arg slug "$slug" \
  --arg scope "$scope" \
  --argjson anchor "$anchor_json" \
  --arg text "$text" \
  --arg created "$created" \
  '{slug: $slug, scope: $scope, anchor: $anchor, text: $text, created_at: $created}')"

mutate_backlog '.findings += [$f]' --argjson f "$finding_json"

# Surface backlog-pressure nudge after write
count="$(jq '.findings | length' "$(backlog_path)")"
text_trunc="${text:0:60}"
[[ ${#text} -gt 60 ]] && text_trunc="${text_trunc}…"
echo "Added $slug [scope:$scope]: $text_trunc"
if [[ "$count" -gt 15 ]]; then
  echo "Findings now at $count; consider \`/base:orient\` to triage."
fi
printf '%s\n' "$slug"
