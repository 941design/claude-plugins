#!/usr/bin/env bash
# list-plugin-bound-findings.sh — surface findings whose anchor points
# at the base plugin source repo.
#
# Thin wrapper around `list.sh --scope-prefix plugins/base/` since
# BACKLOG migrated to JSON in v3. Kept under its original filename for
# backwards compatibility with external callers.
#
# USAGE
#   list-plugin-bound-findings.sh                 # ./BACKLOG.json
#   list-plugin-bound-findings.sh --help

set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'EOF'
list-plugin-bound-findings.sh — surface plugin-bound findings.

A finding is plugin-bound iff its anchor.path begins with `plugins/base/`.

This is now a thin wrapper around list.sh; for richer filters
(status, scope, format) use list.sh directly.

  list-plugin-bound-findings.sh        # equivalent to:
  list.sh --scope-prefix plugins/base/ --format compact --status all
EOF
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/list.sh" --scope-prefix "plugins/base/" --format compact --status all
