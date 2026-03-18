---
name: cloudfront-update
description: >-
  Maintenance skill that refreshes the CloudFront deployment knowledge base by
  fetching the latest Pulumi AWS provider docs, AWS CloudFront updates, and
  deployment best practices. Updates agent memory with new findings and
  timestamps.
disable-model-invocation: true
user-invocable: true
argument-hint: "[optional: specific topic to update]"
allowed-tools: Read, Grep, Glob, Write, Edit, WebFetch, WebSearch, Bash
context: fork
agent: cloudfront-researcher
---

## Knowledge Refresh Task

You are running a knowledge refresh for the CloudFront deployment knowledge
base. This is a maintenance task — do NOT answer user questions, only update
your agent memory.

**Important:** Write all findings to your agent memory directory ONLY. Never
modify files in the plugin/skill directory — those are read-only artifacts
managed by the plugin update mechanism.

If arguments were provided, focus on: $ARGUMENTS
Otherwise, perform a full refresh.

## Refresh Procedure

### 1. Fetch Latest from Primary Sources

Fetch documentation and release notes from each source. Use WebFetch for
raw content and WebSearch for recent developments.

**Sources to check:**

| Source | URL to fetch |
|---|---|
| Pulumi AWS provider | https://github.com/pulumi/pulumi-aws |
| Pulumi AWS CloudFront docs | https://www.pulumi.com/registry/packages/aws/api-docs/cloudfront/ |
| Pulumi AWS S3 docs | https://www.pulumi.com/registry/packages/aws/api-docs/s3/ |
| Pulumi AWS Lambda docs | https://www.pulumi.com/registry/packages/aws/api-docs/lambda/ |
| AWS CloudFront updates | https://aws.amazon.com/cloudfront/getting-started/ |

**For each source, capture:**
- Current Pulumi AWS provider version
- New or modified resource properties
- Breaking changes or deprecation notices
- New CloudFront features (functions, OAC updates, cache policy changes)
- Best practice changes

### 2. Search for Recent Developments

Use WebSearch for:
- "pulumi aws cloudfront" — new examples, breaking changes
- "aws cloudfront origin access control" — OAC updates
- "cloudfront functions" OR "lambda@edge" — new capabilities
- "pulumi s3 static site" — deployment pattern updates
- "aws cloudfront cache policy" — cache configuration changes

### 3. Update Agent Memory

Write all findings to your agent memory directory. Never modify plugin files.

**MEMORY.md** — update with:
- `last_fetch_date: <unix-timestamp>`
- Current Pulumi AWS provider version
- Key CloudFront feature changes
- Summary of what changed since last fetch

**Topic files** — update or create as needed:

| File | What to record |
|---|---|
| `deployment-patterns.md` | New or changed deployment patterns and configurations |
| `gotchas.md` | New pitfalls discovered, resolved issues |
| `changelog.md` | Version changes, breaking changes, deprecations |
| `corrections.md` | Anything that differs from the supporting documents shipped with the plugin — these corrections take precedence when answering |

### 4. Report

Output a concise summary of what was found:
- Key changes since last refresh
- New Pulumi AWS provider version
- New CloudFront features or deprecations
- Any corrections to the shipped supporting documents
- Issues encountered (404s, missing data, etc.)
