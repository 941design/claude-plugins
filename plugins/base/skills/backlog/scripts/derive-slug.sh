#!/usr/bin/env bash
# derive-slug.sh — coin a kebab-case slug from a finding's text.
#
# USAGE
#   derive-slug.sh "<text>"
#   echo "<text>" | derive-slug.sh -
#
# EXIT CODES
#   0  success — slug printed to stdout
#   2  text too short/generic to yield 4 meaningful words (caller must
#      ask the user to rephrase; there is no fallback ID scheme)
#
# RULES (from references/format.md ### Slug derivation)
#   1. Tokenise on whitespace and punctuation.
#   2. Lowercase ASCII; strip non-ASCII.
#   3. Drop stopwords: the / a / an / is / are / and / or / to / of /
#      in / on / for / this / that / it / be / do
#   4. Take first 4-6 meaningful words.
#   5. Hyphen-join. Max 50 chars; truncate at a word boundary.
#   6. If fewer than 4 meaningful words remain, exit 2.

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: derive-slug.sh \"<text>\"   (or '-' to read stdin)" >&2
  exit 64
fi

if [[ "$1" == "-" ]]; then
  text="$(cat)"
else
  text="$1"
fi

# Tokenise + filter + assemble in one awk pass. Awk is portable and
# handles the UTF-8 stripping deterministically.
slug="$(printf '%s' "$text" | awk '
  BEGIN {
    # Stopword set
    split("the a an is are and or to of in on for this that it be do", stopword_arr, " ")
    for (i in stopword_arr) stopwords[stopword_arr[i]] = 1
  }
  {
    # Lowercase
    line = tolower($0)
    # Strip non-ASCII bytes (keep [\x20-\x7E])
    n = length(line)
    out = ""
    for (i = 1; i <= n; i++) {
      c = substr(line, i, 1)
      b = ord_lookup[c]
      if (b == "") {
        # First time seeing this character — initialise lookup
        if (c >= " " && c <= "~") {
          ord_lookup[c] = 1
          b = 1
        } else {
          ord_lookup[c] = 0
          b = 0
        }
      }
      if (b == 1) out = out c
    }
    # Replace any non-alphanumeric with single spaces
    gsub(/[^a-z0-9]+/, " ", out)
    # Split into tokens
    n = split(out, toks, " ")
    count = 0
    slug = ""
    for (i = 1; i <= n; i++) {
      t = toks[i]
      if (t == "") continue
      if (t in stopwords) continue
      if (count >= 6) break
      if (slug == "") slug = t
      else slug = slug "-" t
      count++
    }
    # Enforce minimum 4 meaningful words
    if (count < 4) {
      print ""
      exit 0
    }
    # Cap at 50 chars; truncate on hyphen boundary
    if (length(slug) > 50) {
      # Find the last hyphen at or before position 50
      cut = 50
      while (cut > 0 && substr(slug, cut, 1) != "-") cut--
      if (cut > 0) slug = substr(slug, 1, cut - 1)
      else slug = substr(slug, 1, 50)
    }
    print slug
  }
')"

if [[ -z "$slug" ]]; then
  echo "Error: text too short or too generic to yield 4 meaningful words." >&2
  echo "  Input: $text" >&2
  echo "  Rephrase with more specific vocabulary and try again." >&2
  exit 2
fi

printf '%s\n' "$slug"
