#!/usr/bin/env bash
# init.sh — bootstrap BACKLOG.json + CLAUDE.md pointer.
#
# Idempotent — running on an already-initialised repo is safe; each
# substep checks its own precondition independently so partial state
# can be repaired.
#
# Seeds ## Epics from existing specs/epic-*/ directories on first
# creation only. epic-state.json#status mapping:
#   planning|in_progress → IN_PROGRESS
#   done                 → DONE
#   escalated            → ESCALATED
#   (missing or malformed) → UNKNOWN

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

ROOT="$(repo_root)"
BACKLOG="$ROOT/BACKLOG.json"
CLAUDE_MD="$ROOT/CLAUDE.md"

created_backlog="no"
created_pointer="no"
seeded_count=0

# ---- Step 1: create BACKLOG.json if missing -----------------------------
if [[ ! -f "$BACKLOG" ]]; then
  # Seed epics from disk
  epics_json="[]"
  if [[ -d "$ROOT/specs" ]]; then
    while IFS= read -r dir; do
      [[ -z "$dir" ]] && continue
      rel="${dir#$ROOT/}"
      # Trailing slash, repo-relative
      epic_path="${rel%/}/"
      state_file="$dir/epic-state.json"
      status="UNKNOWN"
      if [[ -f "$state_file" ]]; then
        raw_status="$(jq -r '.status // "UNKNOWN"' "$state_file" 2>/dev/null || echo "UNKNOWN")"
        case "$raw_status" in
          planning|in_progress) status="IN_PROGRESS" ;;
          done)                 status="DONE" ;;
          escalated)            status="ESCALATED" ;;
          *)                    status="UNKNOWN" ;;
        esac
      fi
      epics_json="$(printf '%s' "$epics_json" | jq \
        --arg path "$epic_path" \
        --arg status "$status" \
        --arg seeded_on "$(today)" \
        '. += [{path: $path, status: $status, next_action: "seeded by /base:backlog init \($seeded_on)"}]')"
      seeded_count=$((seeded_count + 1))
    done < <(find "$ROOT/specs" -maxdepth 1 -type d -name "epic-*" 2>/dev/null | sort)
  fi

  jq -n \
    --arg now "$(now_iso)" \
    --argjson epics "$epics_json" \
    '{version: 3, updated_at: $now, epics: $epics, findings: [], archive: []}' \
    | jq --indent 2 . \
    | atomic_write "$BACKLOG"
  created_backlog="yes"
fi

# ---- Step 2: add CLAUDE.md pointer if missing ----------------------------
if [[ ! -f "$CLAUDE_MD" ]]; then
  cat >"$CLAUDE_MD" <<'EOF'
# Project Guidelines

EOF
fi

if ! grep -q 'BACKLOG\.json' "$CLAUDE_MD"; then
  cat >>"$CLAUDE_MD" <<'EOF'

## Project state
Project orientation lives in `BACKLOG.json` (machine-readable;
validated by `plugins/base/schemas/backlog.schema.json`). On a fresh
session — or when resuming work after idle time — run `/base:orient` to
get a 3-line "you are here" plus ranked next moves. From the shell, use
`plugins/base/skills/backlog/scripts/list.sh` to inspect findings. Do
not inline backlog content into this file.
EOF
  created_pointer="yes"
fi

# Validate the file we just touched
validate_backlog "$BACKLOG"

# ---- Step 3: report ------------------------------------------------------
if [[ "$created_backlog" == "yes" && "$created_pointer" == "yes" ]]; then
  echo "Initialized: created BACKLOG.json (seeded $seeded_count epics) + CLAUDE.md pointer."
  [[ $seeded_count -gt 0 ]] && echo "Run \`/base:orient\` to triage."
elif [[ "$created_backlog" == "yes" ]]; then
  echo "Repaired: CLAUDE.md pointer was present; created BACKLOG.json (seeded $seeded_count epics)."
  [[ $seeded_count -gt 0 ]] && echo "Run \`/base:orient\` to triage."
elif [[ "$created_pointer" == "yes" ]]; then
  echo "Repaired: BACKLOG.json was present; added missing CLAUDE.md pointer."
else
  echo "Already initialised: nothing to do."
fi
