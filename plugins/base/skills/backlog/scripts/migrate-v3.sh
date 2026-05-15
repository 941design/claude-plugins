#!/usr/bin/env bash
# migrate-v3.sh — one-shot conversion BACKLOG.md (v2) → BACKLOG.json (v3).
#
# USAGE
#   migrate-v3.sh                     # in-place: reads ./BACKLOG.md, writes ./BACKLOG.json,
#                                       deletes the .md (via `git rm` if tracked)
#   migrate-v3.sh --dry-run           # emit JSON to stdout, do not write or delete
#   migrate-v3.sh --keep-md           # write JSON, do not delete BACKLOG.md
#   migrate-v3.sh --from <md-path>    # explicit input path (defaults to <repo-root>/BACKLOG.md)
#
# IDEMPOTENT
#   - If BACKLOG.json already exists and BACKLOG.md does not, exit 0
#     with "already migrated".
#   - If both exist, refuses to overwrite without --force (avoids
#     clobbering a JSON edited after the markdown).
#
# PARSING
#   v2 grammar (see references/format.md):
#     ## Epics    → `- <path>/ — <STATUS> — <next_action>`
#     ## Findings → `- <slug> [scope:<X>] — \`<anchor>\` — [DEFERRED:r:d] <text> (YYYY-MM-DD)`
#     ## Archive  → `- YYYY-MM-DD — <text> — <reason>[ [→ ADR-NNN]]`
#
#   Em-dash separator is U+2014 (UTF-8 bytes e2 80 94). Section
#   boundaries: ^## <Header>$ to next ^## OR ^---$ OR EOF.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

dry_run="no"
keep_md="no"
force="no"
md_path=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) dry_run="yes"; shift ;;
    --keep-md) keep_md="yes"; shift ;;
    --force)   force="yes"; shift ;;
    --from)    md_path="$2"; shift 2 ;;
    *) echo "Error: unknown argument: $1" >&2; exit 1 ;;
  esac
done

ROOT="$(repo_root)"
[[ -z "$md_path" ]] && md_path="$ROOT/BACKLOG.md"
JSON_PATH="$ROOT/BACKLOG.json"

# ---- idempotency ---------------------------------------------------------
if [[ ! -f "$md_path" && -f "$JSON_PATH" ]]; then
  echo "Already migrated: $JSON_PATH exists and $md_path is gone."
  exit 0
fi

if [[ ! -f "$md_path" ]]; then
  echo "Error: no source file at $md_path" >&2
  exit 1
fi

if [[ -f "$JSON_PATH" && "$force" != "yes" && "$dry_run" != "yes" ]]; then
  echo "Error: $JSON_PATH already exists. Use --force to overwrite, or --dry-run to preview." >&2
  exit 1
fi

# ---- parse the markdown --------------------------------------------------
#
# Awk emits one TSV record per item, with leading section tag:
#   E\t<path>\t<status>\t<next_action>
#   F\t<slug>\t<scope>\t<anchor_raw>\t<deferred_blob>\t<text>\t<date>
#   A\t<date>\t<text>\t<reason>\t<adr_or_empty>
#
# anchor_raw is the literal `<anchor>` token including any backticks
# or bare `-`. deferred_blob is "<reason>::<detail>" or empty.

tsv="$(awk '
  BEGIN {
    section = ""
    SEP = " \xE2\x80\x94 "    # space + em-dash + space
  }

  # Section detection
  /^## Epics[[:space:]]*$/    { section = "epics"; next }
  /^## Findings[[:space:]]*$/ { section = "findings"; next }
  /^## Archive[[:space:]]*$/  { section = "archive"; next }
  /^## /                       { section = ""; next }
  /^---[[:space:]]*$/          { section = ""; next }

  # Skip non-bullet lines
  !/^- / { next }

  # Skip placeholders
  /^- _no [^_]+ yet_/ { next }

  {
    rest = substr($0, 3)     # strip leading "- "

    if (section == "epics") {
      n = split(rest, parts, SEP)
      if (n >= 2) {
        epic_path = parts[1]
        status    = parts[2]
        next_act  = (n >= 3 ? parts[3] : "")
        # Normalize path: ensure trailing slash
        if (substr(epic_path, length(epic_path)) != "/") epic_path = epic_path "/"
        printf "E\t%s\t%s\t%s\n", epic_path, status, next_act
      }
    }
    else if (section == "findings") {
      n = split(rest, parts, SEP)
      if (n >= 3) {
        head    = parts[1]
        anchor  = parts[2]
        tail    = parts[3]
        # If there are more em-dashes inside the text, rejoin
        for (i = 4; i <= n; i++) tail = tail SEP parts[i]

        # head: "<slug> [scope:<X>]"
        slug = head
        scope = "any"
        if (match(head, /[[:space:]]*\[scope:[^]]+\][[:space:]]*$/)) {
          scope_tok = substr(head, RSTART, RLENGTH)
          slug = substr(head, 1, RSTART - 1)
          # strip whitespace and the [scope:...] wrapper
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", slug)
          if (match(scope_tok, /\[scope:[^]]+\]/)) {
            sv = substr(scope_tok, RSTART + 7, RLENGTH - 8)  # inside the brackets
            scope = sv
          }
        }

        # anchor: strip surrounding backticks if present, else bare "-"
        gsub(/^`|`$/, "", anchor)

        # tail: leading [DEFERRED:reason:detail] is optional;
        # trailing " (YYYY-MM-DD)" is mandatory
        deferred_blob = ""
        if (match(tail, /^\[DEFERRED:[^]]+\][[:space:]]*/)) {
          stamp = substr(tail, RSTART, RLENGTH)
          tail = substr(tail, RSTART + RLENGTH)
          # inner: DEFERRED:<reason>:<detail>
          inner = stamp
          gsub(/^[[:space:]]*\[|\][[:space:]]*$/, "", inner)
          sub(/^DEFERRED:/, "", inner)
          # split on first colon
          pos = index(inner, ":")
          if (pos > 0) {
            reason = substr(inner, 1, pos - 1)
            detail = substr(inner, pos + 1)
            deferred_blob = reason "\x1f" detail   # use unit-separator to avoid colon clash
          }
        }

        # extract trailing date — bare (YYYY-MM-DD) or tolerant
        # (YYYY-MM-DD; ...) for legacy entries where the writer
        # smuggled extra info into the parens.
        date = ""
        if (match(tail, /[[:space:]]*\([0-9]{4}-[0-9]{2}-[0-9]{2}[^)]*\)[[:space:]]*$/)) {
          datepart = substr(tail, RSTART, RLENGTH)
          tail = substr(tail, 1, RSTART - 1)
          if (match(datepart, /[0-9]{4}-[0-9]{2}-[0-9]{2}/)) {
            date = substr(datepart, RSTART, RLENGTH)
          }
        } else if (match(tail, /[0-9]{4}-[0-9]{2}-[0-9]{2}/)) {
          # last-resort: keep the date but leave the tail intact —
          # the writer may have inlined the date into the prose
          date = substr(tail, RSTART, RLENGTH)
        }
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", tail)

        # Escape tabs in fields just in case
        gsub(/\t/, " ", slug); gsub(/\t/, " ", scope); gsub(/\t/, " ", anchor)
        gsub(/\t/, " ", deferred_blob); gsub(/\t/, " ", tail); gsub(/\t/, " ", date)

        printf "F\t%s\t%s\t%s\t%s\t%s\t%s\n", slug, scope, anchor, deferred_blob, tail, date
      }
    }
    else if (section == "archive") {
      n = split(rest, parts, SEP)
      if (n >= 3) {
        date_field = parts[1]
        text_field = parts[2]
        reason_field = parts[3]
        adr_field = ""
        for (i = 4; i <= n; i++) reason_field = reason_field SEP parts[i]
        # Check for trailing " [→ ADR-NNN]" on reason
        if (match(reason_field, /[[:space:]]*\[→[[:space:]]*ADR-[0-9]+\][[:space:]]*$/)) {
          adr_block = substr(reason_field, RSTART, RLENGTH)
          reason_field = substr(reason_field, 1, RSTART - 1)
          if (match(adr_block, /ADR-[0-9]+/)) adr_field = substr(adr_block, RSTART, RLENGTH)
        }
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", date_field)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", text_field)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", reason_field)
        printf "A\t%s\t%s\t%s\t%s\n", date_field, text_field, reason_field, adr_field
      }
    }
  }
' "$md_path")"

# ---- assemble JSON via jq ------------------------------------------------
#
# Read TSV from stdin, build per-section arrays, emit final object.

json_out="$(printf '%s\n' "$tsv" | jq -Rsn --arg now "$(now_iso)" '
  def parse_anchor:
    if . == "-" or . == "" then null
    elif test(":[0-9]+-[0-9]+$") then
      capture("^(?<p>.+):(?<a>[0-9]+)-(?<b>[0-9]+)$") | {path, range: [(.a|tonumber), (.b|tonumber)]} | with_entries(select(.key != "p")) + {path: .path}
    else . end;

  # Simpler: split into helpers
  def anchor_of(raw):
    if raw == "-" or raw == "" then null
    elif (raw | test("^.+:[0-9]+-[0-9]+$")) then
      (raw | capture("^(?<path>.+):(?<s>[0-9]+)-(?<e>[0-9]+)$")) as $m
      | {path: $m.path, range: [($m.s|tonumber), ($m.e|tonumber)]}
    elif (raw | test("^.+:[0-9]+$")) then
      (raw | capture("^(?<path>.+):(?<l>[0-9]+)$")) as $m
      | {path: $m.path, line: ($m.l|tonumber)}
    else
      {path: raw}
    end;

  def map_status(raw):
    if raw == "PLANNED" then "PLANNED"
    elif raw == "IN_PROGRESS" then "IN_PROGRESS"
    elif raw == "DONE" then "DONE"
    elif raw == "ESCALATED" then "ESCALATED"
    else "UNKNOWN"
    end;

  [inputs] | .[0] | split("\n") | map(select(length > 0))
  | map(split("\t"))
  | (map(select(.[0] == "E")) | map({
      path: .[1],
      status: map_status(.[2]),
      next_action: .[3]
    } | with_entries(select(.value != "" and .value != null)))) as $epics
  | (map(select(.[0] == "F")) | map(
      . as $row
      | ($row[4] // "") as $defblob
      | (if $defblob == "" then null
         else
           ($defblob | split("")) as $parts
           | {reason: $parts[0], detail: ($parts[1] // ""), stamped_at: $row[6]}
         end) as $deferred
      | {
          slug: $row[1],
          scope: $row[2],
          anchor: anchor_of($row[3]),
          text: $row[5],
          created_at: $row[6]
        }
        + (if $deferred == null then {} else {deferred: $deferred} end)
    )) as $findings
  | (map(select(.[0] == "A")) | map(
      . as $row
      | {date: $row[1], text: $row[2], reason: $row[3]}
        + (if ($row[4] // "") == "" then {} else {adr: $row[4]} end)
    )) as $archive
  | {
      version: 3,
      updated_at: $now,
      epics: $epics,
      findings: $findings,
      archive: $archive
    }
')"

# ---- collision-resolve duplicate slugs ------------------------------------
# Defensive: if the v2 file had duplicate slugs (malformed), suffix
# them deterministically.
json_out="$(printf '%s' "$json_out" | jq '
  .findings = (
    .findings
    | reduce .[] as $f (
        {seen: {}, out: []};
        ($f.slug) as $orig
        | (if .seen[$orig] then "\($orig)-\(.seen[$orig] + 1)" else $orig end) as $new_slug
        | .seen[$orig] = ((.seen[$orig] // 1) + (if .seen[$orig] then 1 else 0 end))
        | .out += [($f | .slug = $new_slug)]
      )
    | .out
  )
')"

if [[ "$dry_run" == "yes" ]]; then
  printf '%s\n' "$json_out" | jq --indent 2 .
  exit 0
fi

# ---- validate proposed JSON BEFORE writing -------------------------------
# Validate the migrated content against the schema in a scratch file so a
# malformed input (or a parser bug) cannot leave a corrupted BACKLOG.json
# on disk.
scratch="$(mktemp)"
trap 'rm -f "$scratch"' EXIT
printf '%s\n' "$json_out" | jq --indent 2 . > "$scratch"
if ! validate_backlog "$scratch"; then
  echo "Error: migration produced schema-invalid JSON. $JSON_PATH was not modified." >&2
  exit 1
fi

# ---- write JSON ----------------------------------------------------------
cat "$scratch" | atomic_write "$JSON_PATH"

n_epics="$(jq '.epics | length' "$JSON_PATH")"
n_findings="$(jq '.findings | length' "$JSON_PATH")"
n_deferred="$(jq '.findings | map(select(.deferred != null)) | length' "$JSON_PATH")"
n_archive="$(jq '.archive | length' "$JSON_PATH")"

# ---- remove BACKLOG.md ---------------------------------------------------
# Use repo-relative pathspecs for git so older git versions (which
# reject absolute paths in pathspec) behave consistently with newer
# ones. Strip the repo-root prefix; if md_path was already relative,
# the substitution is a no-op.
if [[ "$keep_md" != "yes" ]]; then
  md_rel="${md_path#$ROOT/}"
  if git -C "$ROOT" ls-files --error-unmatch "$md_rel" >/dev/null 2>&1; then
    # -f to allow removal even when the file has staged or unstaged
    # mods — its content is fully captured in BACKLOG.json now.
    git -C "$ROOT" rm -qf "$md_rel"
  else
    rm -f "$md_path"
  fi
  removed_msg=" (removed $md_path)"
else
  removed_msg=""
fi

echo "Migrated $md_path → $JSON_PATH${removed_msg}"
echo "  Epics: $n_epics    Findings: $n_findings ($n_deferred deferred)    Archive: $n_archive"
