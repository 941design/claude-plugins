# Cache Policies and Invalidation

## Cache Policies

CloudFront cache policies control what goes into the cache key and how long
objects are cached. Always create a custom cache policy rather than relying
on defaults for production deployments.

### Standard Static Site Cache Policy

```typescript
const cachePolicy = new aws.cloudfront.CachePolicy("site-cache-policy", {
  defaultTtl: 86400,    // 1 day
  maxTtl: 31536000,     // 1 year
  minTtl: 0,
  parametersInCacheKeyAndForwardedToOrigin: {
    cookiesConfig: { cookieBehavior: "none" },
    headersConfig: { headerBehavior: "none" },
    queryStringsConfig: { queryStringBehavior: "none" },
    enableAcceptEncodingGzip: true,
    enableAcceptEncodingBrotli: true,
  },
});
```

### Key Parameters

- **cookieBehavior: "none"** — don't include cookies in cache key (static sites
  don't need them; including cookies destroys cache hit rate)
- **headerBehavior: "none"** — don't vary cache by headers
- **queryStringBehavior: "none"** — ignore query strings for caching
- **enableAcceptEncodingGzip/Brotli: true** — serve compressed variants
  automatically (CloudFront compresses on the fly when `compress: true` is
  set on the behavior)

### TTL Strategy

| Content Type | Recommended TTL | Approach |
|---|---|---|
| HTML pages | 1 hour–1 day | Short TTL + invalidation on deploy |
| Hashed assets (`app.a1b2c3.js`) | 1 year | Immutable — filename changes on content change |
| Images | 1 week–1 month | Medium TTL, invalidate if needed |
| API responses | 0–60 seconds | Use managed `CachingDisabled` policy |

For Next.js static exports, `_next/static/` assets are content-hashed and
safe to cache for 1 year. Only `index.html` and other HTML files need
invalidation on deploy.

## CloudFront Functions for URL Rewriting

Clean URLs (e.g., `/about` → `/about.html`) require a CloudFront Function
on the viewer-request event:

```typescript
const htmlRewriteFn = new aws.cloudfront.Function("html-rewrite-fn", {
  runtime: "cloudfront-js-1.0",
  comment: "Rewrite clean URLs to .html and folders to index.html",
  code: `
function handler(event) {
  var req = event.request;
  var uri = req.uri;

  if (uri.endsWith('/')) {
    req.uri = uri + 'index.html';
    return req;
  }

  if (!uri.includes('.')) {
    req.uri = uri + '.html';
  }

  return req;
}
`,
});

// Attach to distribution:
defaultCacheBehavior: {
  // ... other settings ...
  functionAssociations: [{
    eventType: "viewer-request",
    functionArn: htmlRewriteFn.arn,
  }],
},
```

## Invalidation Strategies

### 1. AWS CLI (Simple, Manual)

```bash
aws cloudfront create-invalidation \
  --distribution-id E2X4SO2H8JPF4L \
  --paths "/index.html" \
  --profile my-profile
```

Good for Makefile targets:

```makefile
DISTRIBUTION_ID := E2X4SO2H8JPF4L

invalidate:
	aws cloudfront create-invalidation \
		--distribution-id $(DISTRIBUTION_ID) \
		--paths "/index.html" --profile my-profile
```

### 2. Lambda Invocation (Automated via Pulumi)

Deploy a Lambda that invalidates on each `pulumi up`. Uses a timestamp
trigger to force re-invocation:

```typescript
const invalidateFn = new aws.lambda.Function("cf-invalidate-fn", {
  role: lambdaRole.arn,
  runtime: "nodejs20.x",
  handler: "index.handler",
  timeout: 120,
  environment: {
    variables: {
      DISTRIBUTION_ID: pulumi.interpolate`${distributionId}`,
      PATHS: "/index.html",
    },
  },
  code: new pulumi.asset.AssetArchive({
    "index.mjs": new pulumi.asset.FileAsset("./invalidate.mjs"),
  }),
});

// Trigger on every deployment:
new aws.lambda.Invocation("cf-invalidate-invoke", {
  functionName: invalidateFn.name,
  triggers: { timestamp: new Date().toISOString() },
  input: "{}",
});
```

Lambda handler (`invalidate.mjs`):

```javascript
import {
  CloudFrontClient,
  CreateInvalidationCommand,
} from "@aws-sdk/client-cloudfront";

export const handler = async () => {
  const client = new CloudFrontClient({});
  const DistributionId = process.env.DISTRIBUTION_ID;
  const Paths = (process.env.PATHS || "/index.html")
    .split(",")
    .map(s => s.trim());
  const CallerReference = `pulumi-${Date.now()}`;

  return await client.send(new CreateInvalidationCommand({
    DistributionId,
    InvalidationBatch: {
      CallerReference,
      Paths: { Quantity: Paths.length, Items: Paths },
    },
  }));
};
```

IAM policy for the Lambda:

```typescript
new aws.iam.RolePolicy("invalidate-policy", {
  role: lambdaRole.id,
  policy: aws.iam.getPolicyDocumentOutput({
    statements: [
      {
        sid: "Logs",
        actions: [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ],
        resources: ["arn:aws:logs:*:*:*"],
      },
      {
        sid: "Invalidate",
        actions: ["cloudfront:CreateInvalidation"],
        resources: [
          pulumi.interpolate
            `arn:aws:cloudfront::${accountId}:distribution/${distributionId}`,
        ],
      },
    ],
  }).json,
});
```

### 3. Pulumi Dynamic Resource (Custom Provider)

For tighter Pulumi integration, create a dynamic resource that invalidates
as part of the resource lifecycle:

```typescript
import * as pulumi from "@pulumi/pulumi";
import * as aws from "@aws-sdk/client-cloudfront";

interface InvalidationArgs {
  distributionId: pulumi.Input<string>;
  paths: pulumi.Input<string[]>;
}

type InvalidationInputs = pulumi.Unwrap<InvalidationArgs>;

class InvalidationProvider implements pulumi.dynamic.ResourceProvider {
  async create(inputs: InvalidationInputs) {
    const cf = new aws.CloudFrontClient({});
    const res = await cf.send(new aws.CreateInvalidationCommand({
      DistributionId: inputs.distributionId,
      InvalidationBatch: {
        CallerReference: Date.now().toString(),
        Paths: { Quantity: inputs.paths.length, Items: inputs.paths },
      },
    }));
    return { id: res.Invalidation!.Id! };
  }

  async diff() {
    return { changes: true, replaces: ["paths", "distributionId"] };
  }
}

export class CloudFrontInvalidation extends pulumi.dynamic.Resource {
  constructor(
    name: string,
    args: InvalidationArgs,
    opts?: pulumi.CustomResourceOptions,
  ) {
    super(new InvalidationProvider(), name, args, opts);
  }
}
```

Usage:

```typescript
new CloudFrontInvalidation("invalidate-index", {
  distributionId: distribution.id,
  paths: ["/index.html"],
}, { dependsOn: [...bucketObjects, distribution] });
```

## Invalidation Cost

- First 1,000 invalidation paths per month are free.
- Each path beyond 1,000 costs $0.005.
- Wildcard `/*` counts as one path.
- Prefer `/*` for full-site invalidations over listing individual files.
