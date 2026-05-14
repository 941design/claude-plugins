#!/usr/bin/env bash
# list-plugin-bound-findings.sh
#
# PURPOSE
#   One-shot triage utility: in a consumer project, surface finding
#   bullets in BACKLOG.md whose anchor points at the `base` plugin's
#   source files and therefore cannot be dispatched from the consumer
#   repo. Prints line numbers + bullets so the user can clean up in a
#   text editor.
#
# WHY THIS EXISTS
#   Pre-3f4ab19 BACKLOG-write surfaces (`/base:next` Step 3, the
#   project-curator's autonomous `append_finding`) leaked plugin-bound
#   entries into consumer BACKLOGs whose anchors point at
#   `plugins/base/...` files that live in the base plugin source repo
#   (941design/claude-plugins), not in the consumer. This script makes
#   the legacy leak visible so the user can delete or port each entry.
#
# DETECTION
#   A `## Findings` bullet is classified plugin-bound iff its **anchor**
#   (the path before ` — `, after stripping optional surrounding
#   backticks) begins with `plugins/base/`. Case-sensitive prefix match
#   on the parsed anchor only.
#
#   Free-text mentions of `base:<cmd>` or `/base:<cmd>` in the bullet's
#   `<text>` are NOT classified plugin-bound — bullet prose frequently
#   references base commands as context for consumer work (e.g.
#   `src/foo.ts — fails when invoked from /base:bug` is consumer code
#   anchored at consumer source). Anchor-only is the narrowest signal
#   that reliably indicates plugin-source targeting.
#
#   Sibling sites that share this intent but adapt to their own
#   structured fields — keep them aligned when intent changes:
#     - plugins/base/agents/retro-synthesizer.md  (and bug-retro-…)
#         Hard Rule 5 matches `\b(plugins/base/|base:[a-z-]+|/base:[a-z-]+)\b`
#         against the structured `**Suggested change:**` field. Retros
#         have a dedicated target field; the broader regex is safe there.
#     - plugins/base/commands/next.md  (Step 3 `plugin-bound` bucket)
#         Matches bullet anchor against the `plugins/base/` prefix.
#     - plugins/base/agents/project-curator.md
#         `append_finding` Eligibility matches the decision `anchor`
#         against the `plugins/base/` prefix. `append_rejection`
#         Eligibility has no `anchor` field and matches the `text`
#         substring `plugins/base/` only (narrower than the synthesizer
#         to avoid false positives on rejection prose).
#
# INVOCATION
#   list-plugin-bound-findings.sh                 # ./BACKLOG.md
#   list-plugin-bound-findings.sh --path <path>   # custom path
#   list-plugin-bound-findings.sh --help
#
# EXIT CODES
#   0  success (regardless of how many matches were found)
#   1  BACKLOG.md not found at <path>
#   2  <path> has no `## Findings` section (malformed BACKLOG)

set -euo pipefail

PROG="$(basename "$0")"

usage() {
  cat <<'EOF'
list-plugin-bound-findings.sh — surface plugin-bound bullets in BACKLOG.md

USAGE
  list-plugin-bound-findings.sh [--path <path>] [--help]

OPTIONS
  --path <path>   BACKLOG.md path. Defaults to ./BACKLOG.md.
  --help          Show this help.

DETECTION
  A bullet is plugin-bound iff its anchor (the path before ` — `,
  with optional surrounding backticks stripped) begins with
  `plugins/base/`. Free-text mentions of `base:<cmd>` or `/base:<cmd>`
  in the bullet body are NOT classified plugin-bound — those frequently
  describe consumer work that references a base command.

OUTPUT
  Prints each matching bullet as `<line-no>: <full bullet line>`. After
  the listing, prints suggested actions: port each entry to
  claude-plugins/BACKLOG.md (the base plugin source repo), or delete it
  from this file. The script makes no mutations — the user does the
  cleanup in a text editor.

EXIT CODES
  0  success (any N, including 0)
  1  file not found
  2  missing `## Findings` section

This script has no external dependencies beyond awk and a POSIX shell.
EOF
}

# --- arg parsing --------------------------------------------------------
path="./BACKLOG.md"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --path)
      if [[ $# -lt 2 ]]; then
        echo "Error: --path requires an argument" >&2
        exit 1
      fi
      path="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Error: unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

# --- preflight ----------------------------------------------------------
if [[ ! -f "$path" ]]; then
  echo "Error: BACKLOG.md not found at $path" >&2
  exit 1
fi

if ! grep -qE '^## Findings$' "$path"; then
  echo "Error: $path has no ## Findings section; not a valid BACKLOG file." >&2
  exit 2
fi

# --- detection (awk over the ## Findings block only) -------------------
#
# Parse each bullet inside the ## Findings section. Split on " — "
# (em-dash with surrounding spaces). The text before is the anchor.
# Strip a single optional pair of surrounding backticks. Match the
# anchor against the prefix `plugins/base/`.
#
# Awk index() is byte-level, so the em-dash (UTF-8 e2 80 94) matches
# reliably across BSD/GNU/mawk on UTF-8 input.
#
# Section scope: from the line `^## Findings$` (exclusive) up to the
# next `^## ` heading OR a bare `^---$` separator OR EOF.
matches="$(awk '
  BEGIN { in_findings = 0 }
  {
    line = $0
    if (line ~ /^## Findings$/) { in_findings = 1; next }
    if (in_findings) {
      if (line ~ /^## / || line ~ /^---$/) { in_findings = 0; next }
      if (line ~ /^- /) {
        rest = substr(line, 3)
        sep = index(rest, " — ")
        if (sep > 0) {
          anchor = substr(rest, 1, sep - 1)
          sub(/^`/, "", anchor)
          sub(/`$/, "", anchor)
          if (anchor ~ /^plugins\/base\//) {
            printf "%d\t%s\n", NR, line
          }
        }
      }
    }
  }
' "$path" || true)"

if [[ -z "$matches" ]]; then
  echo "No plugin-bound findings in $path. BACKLOG is clean."
  exit 0
fi

count="$(printf '%s\n' "$matches" | wc -l | tr -d ' ')"

echo "Plugin-bound findings in $path:"
echo
printf '%s\n' "$matches" | awk -F'\t' '{ printf "  %s: %s\n", $1, $2 }'
echo
echo "Found ${count} plugin-bound finding(s)."

cat <<'EOF'

These cannot be dispatched from this consumer project — their anchors target plugin source files. For each entry, in a text editor:
  • Copy into claude-plugins/BACKLOG.md (the base plugin source repo) under ## Findings, OR
  • Delete from this BACKLOG.md if obsolete.
EOF
