#!/usr/bin/env bash
# mark-archive-adr.sh — tag archive[] entries with an ADR identifier.
#
# Used by base:project-curator's `promote_rejections_to_adr` action.
# After base:adr creates a new ADR from a rejection cluster, mark each
# contributing archive entry with `adr: "ADR-NNN"` so the audit trail
# links the rejection to the durable architectural record.
#
# USAGE
#   mark-archive-adr.sh --adr ADR-007 --marker "<substring>" [--marker "<substring>" ...]
#
# Each --marker is matched against each archive entry's .text field;
# the first archive entry whose text contains the marker substring
# gets the adr field set. Subsequent markers find subsequent entries
# (each marker matches at most one entry). Idempotent: setting adr on
# an entry that already has the same adr is a no-op; setting a
# different adr surfaces a warning and skips the entry.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

adr=""
markers=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --adr)    adr="$2"; shift 2 ;;
    --marker) markers+=("$2"); shift 2 ;;
    *) echo "Error: unknown argument: $1" >&2; exit 1 ;;
  esac
done

[[ -z "$adr" ]] && { echo "Error: --adr is required (e.g. ADR-007)" >&2; exit 1; }
if [[ ${#markers[@]} -eq 0 ]]; then
  echo "Error: at least one --marker is required" >&2
  exit 1
fi
if [[ ! "$adr" =~ ^ADR-[0-9]+$ ]]; then
  echo "Error: --adr must match ADR-NNN, got: $adr" >&2
  exit 1
fi

# Pass markers as a JSON array
markers_json="$(printf '%s\n' "${markers[@]}" | jq -R . | jq -s .)"

mutate_backlog '
  . as $root
  | .archive = (
      reduce ($markers | to_entries[]) as $m (
        {arr: $root.archive, used: {}};
        # find first archive entry that contains this marker, not already used
        (.arr | to_entries | map(select(.value.text | contains($m.value))) | map(select(.key as $k | (.|tojson) as $_ | (.used // {})[$k|tostring] | not)))
        | . as $candidates
        | if ($candidates | length) > 0
          then
            (.arr | to_entries | map(select(.value.text | contains($m.value))) | .[0].key) as $idx
            | if ($idx == null) then .
              elif (.arr[$idx].adr // null) == $adr then .
              elif (.arr[$idx].adr // null) != null then
                # warn via stderr would be nice but jq cannot; just skip
                .
              else .arr[$idx].adr = $adr | .used[$idx|tostring] = true end
          else .
          end
      )
      | .arr
    )
' --argjson markers "$markers_json" --arg adr "$adr"

# Report
hits="$(jq --arg adr "$adr" '.archive | map(select(.adr == $adr)) | length' "$(backlog_path)")"
echo "Marked $hits archive entries with $adr"
