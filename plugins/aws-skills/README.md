# aws-skills

Skills for deploying and managing serverless frontends on
[AWS](https://aws.amazon.com/) using CloudFront + S3 with
[Pulumi](https://www.pulumi.com/) as the infrastructure-as-code tool.

- **CloudFront** — deploy static sites and SPAs with S3 origins, Origin
  Access Control, cache policies, CloudFront Functions for URL rewriting,
  Lambda@Edge for authentication, and automated invalidation strategies

## Installation

```bash
/plugin marketplace add 941design/claude-plugins
/plugin install aws-skills@941design
```

## Skills

### `/aws-skills:cloudfront [question]`

Advisory skill. Answers questions about:

- S3 + CloudFront static site deployment with Pulumi
- Origin Access Control (OAC) configuration
- Cache policies and compression
- CloudFront Functions for URL rewriting (clean URLs)
- Lambda@Edge viewer-request authentication (Google OAuth, etc.)
- CloudFront invalidation strategies (CLI, Lambda, Pulumi dynamic resources)
- Multi-environment deployments with Pulumi stack references
- Custom domains with ACM certificates
- Makefile-based deployment workflows

**Auto-invokes** when Claude detects CloudFront deployment questions. Runs in
an isolated agent context with persistent memory.

**Self-updating:** Checks documentation freshness on each invocation. If
supporting documents are older than 7 days, automatically fetches the latest
from Pulumi docs and AWS references before answering.

### `/aws-skills:cloudfront-update [topic]`

Manual maintenance skill. Fetches the latest Pulumi AWS provider docs, AWS
CloudFront updates, and deployment best practices, then updates agent memory.

```bash
# Full update
/aws-skills:cloudfront-update

# Targeted update
/aws-skills:cloudfront-update cache policies
```

## Agent

### cloudfront-researcher

Custom agent with user-scoped persistent memory
(`~/.claude/agent-memory/cloudfront-researcher/`). Accumulates knowledge across
sessions — deployment patterns, Pulumi API changes, AWS service updates, and
common pitfalls.

Both cloudfront skills run in this agent's context, sharing the same memory.

### First Run

Agent memory is user-scoped and lives outside the plugin directory. Plugin
files are never modified at runtime — all dynamic state lives in agent memory.

On first invocation, the agent detects that its memory is empty and
automatically runs a full knowledge refresh, fetching from Pulumi docs and
AWS references. This adds latency to the first invocation but requires no
manual setup. Subsequent invocations reuse cached memory and only refresh when
stale (>7 days). When memory and supporting docs conflict, the agent trusts
its memory (latest fetch) over the shipped docs.

To force a rebuild at any time:

```bash
/aws-skills:cloudfront-update
```

## Supporting Documents

### CloudFront

Four read-only reference files:

| File | Content |
|---|---|
| `static-site-pattern.md` | Complete S3 + CloudFront deployment: bucket, OAC, cache policy, distribution, bucket policy |
| `lambda-edge-auth.md` | Lambda@Edge authentication: Google OAuth, cookie sessions, cross-region deployment |
| `cache-and-invalidation.md` | Cache policies, CloudFront Functions for URL rewriting, invalidation strategies |
| `pulumi-patterns.md` | Project structure, stack references, Makefile integration, secrets, multi-environment |

## Primary Sources

| Source | Link |
|---|---|
| Pulumi AWS provider | [pulumi/pulumi-aws](https://github.com/pulumi/pulumi-aws) |
| Pulumi AWS docs | [pulumi.com/registry/packages/aws](https://www.pulumi.com/registry/packages/aws/) |
| AWS CloudFront docs | [docs.aws.amazon.com/cloudfront](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/) |
| AWS S3 docs | [docs.aws.amazon.com/s3](https://docs.aws.amazon.com/AmazonS3/latest/userguide/) |

## Development

Load the plugin directly:

```bash
claude --plugin-dir ./plugins/aws-skills
```
