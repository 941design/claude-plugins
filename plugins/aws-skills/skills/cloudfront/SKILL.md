---
name: cloudfront
description: >-
  AWS CloudFront deployment advisor. Helps deploy static sites and SPAs using
  S3 + CloudFront with Pulumi IaC. Covers distribution setup, cache policies,
  origin access control, Lambda@Edge authentication, CloudFront Functions for
  URL rewriting, invalidation strategies, and multi-environment deployments.
  Invoke for questions about serverless frontend hosting on AWS.
argument-hint: "[question about CloudFront deployment]"
allowed-tools: Read, Grep, Glob, Write, Edit, WebFetch, WebSearch, Bash
context: fork
agent: cloudfront-researcher
---

## Freshness Gate

Current Unix timestamp: !`date +%s`

Read your MEMORY.md and find the `last_fetch_date` value. If it does not
exist, or if the current timestamp minus `last_fetch_date` exceeds **604800**
(7 days), you MUST run a knowledge refresh before answering. Follow the
refresh procedure described in your agent system prompt (fetch Pulumi docs
and AWS references, write findings to agent memory only — never modify plugin
files).

If memory is fresh, proceed directly to answering.

## User Question

$ARGUMENTS

## Reference Documents

The following supporting documents are available in your skill directory at
`${CLAUDE_SKILL_DIR}/`:

| File | Content |
|---|---|
| [static-site-pattern.md](static-site-pattern.md) | Complete S3 + CloudFront static site deployment with Pulumi: bucket, OAC, cache policy, distribution, bucket policy |
| [lambda-edge-auth.md](lambda-edge-auth.md) | Lambda@Edge viewer-request authentication: Google OAuth, cookie-based sessions, cross-region deployment |
| [cache-and-invalidation.md](cache-and-invalidation.md) | Cache policies, CloudFront Functions for URL rewriting, invalidation via Lambda and AWS CLI |
| [pulumi-patterns.md](pulumi-patterns.md) | Pulumi project structure, stack references, cross-stack outputs, Makefile integration, deployment workflows |

Read the relevant documents to answer the user's question. Consult your agent
memory for additional context and prior findings.

## Response Format

- **Default to Pulumi TypeScript.** Show how to accomplish the task using
  `@pulumi/aws` resources. Only explain raw AWS API or CloudFormation when
  the user explicitly asks or when it's needed to understand Pulumi behavior.
- Provide concrete code examples showing Pulumi resource definitions.
- Always include security best practices (OAC over OAI, private buckets,
  HTTPS redirect, compression).
- Distinguish between CloudFront Functions and Lambda@Edge — recommend the
  right one for the task.
- Show Makefile targets for deployment workflows when relevant.
- If you need to fetch live documentation to verify details, do so.
