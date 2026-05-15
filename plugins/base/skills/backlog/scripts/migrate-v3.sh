#!/usr/bin/env bash
# migrate-v3.sh — best-effort conversion BACKLOG.md (v2) → BACKLOG.json (v3).
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
#   - If both exist, refuses to overwrite without --force.
#
# BEST-EFFORT INTERPRETATION
#   The v2 ## Epics section in practice contained three flavours of row:
#     1. Real v3-shape epic dirs (specs/epic-<slug>/).
#     2. Spec files that document an epic-shaped idea but were never
#        scaffolded (specs/foo.md, docs/bar.md).
#     3. Freeform infrastructure todos with no on-disk path.
#   Only flavour 1 fits v3's epics[] grammar. Flavours 2 and 3 are real
#   work-we-know-about and belong in findings[]. This script demotes
#   them rather than failing the whole migration.
#
#   Per-epic status for kept rows is re-derived from on-disk evidence
#   (epic-state.json, spec markers, story dirs) — the same evidence
#   classifier next-epic uses. The v2 markdown's status text is not
#   consulted; the dir is the truth.
#
#   Rows that point at a missing dir AND cannot be turned into a finding
#   (e.g. derive-slug rejects the text) are quarantined in
#   BACKLOG.migration-report.md and not written to BACKLOG.json. The
#   user can hand-edit and re-run.
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
REPORT_PATH="$ROOT/BACKLOG.migration-report.md"

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
# Awk emits one TSV record per item, with leading section tag.
# Epic rows are emitted as-is (the v2 status text travels along but is
# discarded later — kept rows get an evidence-based classification, demoted
# rows ignore it). Source line numbers are emitted so the migration report
# can point users back to the markdown.
#
#   E\t<line>\t<path>\t<v2_status>\t<next_action>
#   F\t<slug>\t<scope>\t<anchor_raw>\t<deferred_blob>\t<text>\t<date>
#   A\t<date>\t<text>\t<reason>\t<adr_or_empty>

tsv="$(awk '
  BEGIN {
    section = ""
    SEP = " \xE2\x80\x94 "    # space + em-dash + space
  }

  /^## Epics[[:space:]]*$/    { section = "epics"; next }
  /^## Findings[[:space:]]*$/ { section = "findings"; next }
  /^## Archive[[:space:]]*$/  { section = "archive"; next }
  /^## /                       { section = ""; next }
  /^---[[:space:]]*$/          { section = ""; next }

  !/^- / { next }
  /^- _no [^_]+ yet_/ { next }

  {
    rest = substr($0, 3)

    if (section == "epics") {
      n = split(rest, parts, SEP)
      if (n >= 2) {
        epic_path = parts[1]
        v2status  = parts[2]
        next_act  = (n >= 3 ? parts[3] : "")
        for (i = 4; i <= n; i++) next_act = next_act SEP parts[i]
        if (substr(epic_path, length(epic_path)) != "/") epic_path = epic_path "/"
        gsub(/\t/, " ", epic_path); gsub(/\t/, " ", v2status); gsub(/\t/, " ", next_act)
        printf "E\t%d\t%s\t%s\t%s\n", NR, epic_path, v2status, next_act
      }
    }
    else if (section == "findings") {
      n = split(rest, parts, SEP)
      if (n >= 3) {
        head    = parts[1]
        anchor  = parts[2]
        tail    = parts[3]
        for (i = 4; i <= n; i++) tail = tail SEP parts[i]

        slug = head
        scope = "any"
        if (match(head, /[[:space:]]*\[scope:[^]]+\][[:space:]]*$/)) {
          scope_tok = substr(head, RSTART, RLENGTH)
          slug = substr(head, 1, RSTART - 1)
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", slug)
          if (match(scope_tok, /\[scope:[^]]+\]/)) {
            sv = substr(scope_tok, RSTART + 7, RLENGTH - 8)
            scope = sv
          }
        }

        gsub(/^`|`$/, "", anchor)

        deferred_blob = ""
        if (match(tail, /^\[DEFERRED:[^]]+\][[:space:]]*/)) {
          stamp = substr(tail, RSTART, RLENGTH)
          tail = substr(tail, RSTART + RLENGTH)
          inner = stamp
          gsub(/^[[:space:]]*\[|\][[:space:]]*$/, "", inner)
          sub(/^DEFERRED:/, "", inner)
          pos = index(inner, ":")
          if (pos > 0) {
            reason = substr(inner, 1, pos - 1)
            detail = substr(inner, pos + 1)
            deferred_blob = reason "\x1f" detail
          }
        }

        date = ""
        if (match(tail, /[[:space:]]*\([0-9]{4}-[0-9]{2}-[0-9]{2}[^)]*\)[[:space:]]*$/)) {
          datepart = substr(tail, RSTART, RLENGTH)
          tail = substr(tail, 1, RSTART - 1)
          if (match(datepart, /[0-9]{4}-[0-9]{2}-[0-9]{2}/)) {
            date = substr(datepart, RSTART, RLENGTH)
          }
        } else if (match(tail, /[0-9]{4}-[0-9]{2}-[0-9]{2}/)) {
          date = substr(tail, RSTART, RLENGTH)
        }
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", tail)

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

# ---- post-process epic rows: keep / demote / quarantine -----------------
#
# Per-epic status for kept rows is re-derived from on-disk evidence via
# lib/common.sh#classify_epic_status — the single canonical classifier
# shared with /base:backlog init, /base:next-epic, and /base:orient.

epic_tsv=""
finding_tsv=""
archive_tsv=""
demoted_count=0
quarantined_count=0
demoted_report=""
quarantined_report=""

EPIC_PATH_RE='^specs/epic-[a-z0-9-]+/$'

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  case "$line" in
    E$'\t'*)
      IFS=$'\t' read -r _tag src_line epath v2status next_act <<< "$line"
      if [[ "$epath" =~ $EPIC_PATH_RE && -d "$ROOT/${epath%/}" ]]; then
        derived_status="$(classify_epic_status "$ROOT/${epath%/}")"
        # Re-emit in the simpler downstream shape: E\t<path>\t<status>\t<next>
        epic_tsv+="E"$'\t'"$epath"$'\t'"$derived_status"$'\t'"$next_act"$'\n'
      else
        # Demote: build a finding from the v2 row.
        if [[ -n "$next_act" ]]; then
          ftext="${epath%/}: $next_act"
        else
          ftext="${epath%/}"
        fi
        if slug="$(printf '%s\n' "$ftext" | "$SCRIPT_DIR/derive-slug.sh" - 2>/dev/null)"; then
          # Anchor: only if the v2 path looks like a real anchor target.
          path_stripped="${epath%/}"
          anchor_raw="-"
          if [[ "$path_stripped" == specs/* || "$path_stripped" == docs/* || "$path_stripped" == plugins/* ]]; then
            anchor_raw="$path_stripped"
          fi
          finding_tsv+="F"$'\t'"$slug"$'\t'"any"$'\t'"$anchor_raw"$'\t'""$'\t'"$ftext"$'\t'"$(today)"$'\n'
          demoted_count=$((demoted_count + 1))
          demoted_report+="- BACKLOG.md:${src_line} — \`${epath%/}\` → finding \`${slug}\` (v2 status: \`${v2status}\`)"$'\n'
        else
          quarantined_count=$((quarantined_count + 1))
          quarantined_report+="- BACKLOG.md:${src_line} — \`${epath%/}\` (no slug derivable from text \"${ftext}\"; rephrase or scaffold an epic dir, then re-run)"$'\n'
        fi
      fi
      ;;
    F$'\t'*)
      finding_tsv+="$line"$'\n'
      ;;
    A$'\t'*)
      archive_tsv+="$line"$'\n'
      ;;
  esac
done <<< "$tsv"

combined_tsv="${epic_tsv}${finding_tsv}${archive_tsv}"

# ---- assemble JSON via jq ------------------------------------------------

json_out="$(printf '%s' "$combined_tsv" | jq -Rsn --arg now "$(now_iso)" '
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

  [inputs] | .[0] | split("\n") | map(select(length > 0))
  | map(split("\t"))
  | (map(select(.[0] == "E")) | map({
      path: .[1],
      status: .[2],
      next_action: .[3]
    } | with_entries(select(.value != "" and .value != null)))) as $epics
  | (map(select(.[0] == "F")) | map(
      . as $row
      | ($row[4] // "") as $defblob
      | (if $defblob == "" then null
         else
           ($defblob | split("")) as $parts
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

# ---- collision-resolve duplicate slugs -----------------------------------
# v2 → v3 demotion may collide with an existing v2 finding slug or with
# another demoted slug; suffix deterministically.
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
  if [[ "$demoted_count" -gt 0 || "$quarantined_count" -gt 0 ]]; then
    {
      echo
      echo "# DRY-RUN migration report (would write $REPORT_PATH)"
      [[ "$demoted_count" -gt 0 ]] && { echo; echo "## Demoted to findings ($demoted_count)"; echo; printf '%s' "$demoted_report"; }
      [[ "$quarantined_count" -gt 0 ]] && { echo; echo "## Quarantined ($quarantined_count)"; echo; printf '%s' "$quarantined_report"; }
    } >&2
  fi
  exit 0
fi

# ---- sanity validation BEFORE writing ------------------------------------
# After the demote/quarantine pass the candidate JSON should be schema-valid
# by construction. validate_backlog stays as a safety net for migration-code
# bugs (not user-data bugs); if it fails here the script aborts and points
# at the offending entries — that is a code defect, not legacy markdown.
scratch="$(mktemp)"
trap 'rm -f "$scratch"' EXIT
printf '%s\n' "$json_out" | jq --indent 2 . > "$scratch"
if ! validate_backlog "$scratch"; then
  echo "Error: migration produced schema-invalid JSON (this is a migrate-v3.sh bug, not a BACKLOG.md problem)." >&2
  echo "       $JSON_PATH was not modified. Please report with the BACKLOG.md content." >&2
  exit 1
fi

# ---- write JSON ----------------------------------------------------------
cat "$scratch" | atomic_write "$JSON_PATH"

n_epics="$(jq '.epics | length' "$JSON_PATH")"
n_findings="$(jq '.findings | length' "$JSON_PATH")"
n_deferred="$(jq '.findings | map(select(.deferred != null)) | length' "$JSON_PATH")"
n_archive="$(jq '.archive | length' "$JSON_PATH")"

# ---- write migration report (if any non-trivial interpretation happened) -
if [[ "$demoted_count" -gt 0 || "$quarantined_count" -gt 0 ]]; then
  {
    echo "# BACKLOG migration report"
    echo
    echo "Generated $(today) by \`plugins/base/skills/backlog/scripts/migrate-v3.sh\`."
    echo
    echo "The v2 \`BACKLOG.md\` contained rows under \`## Epics\` that did not fit v3's"
    echo "\`specs/epic-<slug>/\` shape. Best-effort interpretation made the calls below."
    echo "Edit \`BACKLOG.json\` directly (via \`scripts/*.sh\`) to override; this report is"
    echo "informational and is not consulted by any /base: surface."
    if [[ "$demoted_count" -gt 0 ]]; then
      echo
      echo "## Demoted to findings ($demoted_count)"
      echo
      echo "These rows pointed at a path that was not a v3-shape epic dir but were"
      echo "interpretable as work-we-know-about. They have been demoted into"
      echo "\`findings[]\` and can be promoted via \`/base:feature backlog:<slug>\` or"
      echo "closed via \`/base:backlog resolve <slug>\`."
      echo
      printf '%s' "$demoted_report"
    fi
    if [[ "$quarantined_count" -gt 0 ]]; then
      echo
      echo "## Quarantined ($quarantined_count)"
      echo
      echo "These rows could not be interpreted automatically and are NOT in"
      echo "\`BACKLOG.json\`. The original \`BACKLOG.md\` has been removed (or kept with"
      echo "\`--keep-md\`); recover the lines from git history if needed."
      echo
      printf '%s' "$quarantined_report"
    fi
  } > "$REPORT_PATH"
  report_msg=" (see $REPORT_PATH)"
else
  # No interpretation happened; clean up any stale report from a prior run.
  [[ -f "$REPORT_PATH" ]] && rm -f "$REPORT_PATH"
  report_msg=""
fi

# ---- remove BACKLOG.md ---------------------------------------------------
if [[ "$keep_md" != "yes" ]]; then
  md_rel="${md_path#$ROOT/}"
  if git -C "$ROOT" ls-files --error-unmatch "$md_rel" >/dev/null 2>&1; then
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
if [[ "$demoted_count" -gt 0 || "$quarantined_count" -gt 0 ]]; then
  echo "  Demoted from epics → findings: $demoted_count    Quarantined: $quarantined_count${report_msg}"
fi
