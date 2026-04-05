# GitHub Fetching Patterns

Practical patterns for fetching GitHub repository content via WebFetch and
WebSearch.

## Raw Content URLs

Fetch individual files directly without the GitHub UI wrapper:

```
https://raw.githubusercontent.com/{org}/{repo}/{branch}/{path}
```

Examples:
- `https://raw.githubusercontent.com/hzrd149/applesauce/master/README.md`
- `https://raw.githubusercontent.com/nbd-wtf/nostr-tools/master/src/index.ts`

Use this for: README, source files, configuration files, CHANGELOG.

## Repository Tree (Structure)

Get the full directory tree in one request:

```
https://api.github.com/repos/{org}/{repo}/git/trees/{branch}?recursive=1
```

This returns every file path in the repo. Use it to understand project
structure without fetching individual files. Parse the JSON response and
look for patterns in the path list.

**Note:** Large repos may return truncated results. If `truncated: true`,
fetch subtrees individually.

## Latest Release

```
https://api.github.com/repos/{org}/{repo}/releases/latest
```

Returns: tag name, release date, release notes body. Use for changelog
tracking and version detection.

For all releases (paginated):
```
https://api.github.com/repos/{org}/{repo}/releases?per_page=10
```

## Repository Metadata

```
https://api.github.com/repos/{org}/{repo}
```

Returns: description, language, topics, stars, default branch, creation date,
last push date. Useful for Tier 1 overview.

## Package Manifests

Fetch dependency information:

| Ecosystem | File |
|-----------|------|
| Node.js | `package.json` (root + workspace packages) |
| Rust | `Cargo.toml` + `Cargo.lock` |
| Go | `go.mod` |
| Python | `pyproject.toml`, `setup.py`, `requirements.txt` |
| Java/Kotlin | `build.gradle.kts`, `pom.xml` |

## CHANGELOG Locations

Projects store changelogs in various places. Check in order:

1. `CHANGELOG.md` or `CHANGES.md` in repo root
2. GitHub Releases page (API endpoint above)
3. `HISTORY.md` or `NEWS.md`
4. Monorepo: per-package CHANGELOG in package directory
5. Git tags + commit messages (last resort)

## WebSearch Patterns

Effective search queries for finding repo-related information:

```
"{org}/{repo}" changelog breaking changes
"{repo-name}" tutorial OR guide OR example
"{repo-name}" vs "{alternative}" comparison
"{repo-name}" architecture OR design OR internals
site:github.com/{org}/{repo} discussions
```

For finding related/comparable projects:
```
"{repo-name}" alternative OR similar OR "instead of"
"{technology}" "{use-case}" github
```

## Rate Limiting

GitHub API allows 60 requests/hour unauthenticated. To stay within limits:

- Prefer raw.githubusercontent.com for file content (no rate limit)
- Use the tree API once instead of listing directories individually
- Cache repository metadata — it changes infrequently
- Batch file fetches: identify all needed files first, then fetch

If you hit a rate limit (HTTP 403 with rate limit headers), note this in
the repo's `_meta.yaml` and skip to the next repo. Report the issue in the
refresh summary.

## Fallback Strategies

When primary methods fail:

1. **API unavailable** — fall back to raw.githubusercontent.com for files
2. **Private repo** — note in `_meta.yaml`, rely on WebSearch for public
   information (blog posts, docs sites, conference talks)
3. **Large repo** — use tree API to identify key directories, then fetch
   selectively rather than trying to read everything
4. **No releases** — check git tags via API, or parse CHANGELOG file
