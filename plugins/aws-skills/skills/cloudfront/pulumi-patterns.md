# Pulumi Patterns for CloudFront Deployments

## Project Structure

Typical layout for a project with both application code and infrastructure:

```
project/
├── app/                    # Application source (Next.js, React, etc.)
├── out/                    # Build output (static files)
├── infrastructure/
│   ├── package.json        # Pulumi dependencies
│   ├── tsconfig.json
│   ├── deploy-site/        # Stack: S3 + CloudFront distribution
│   │   ├── Pulumi.yaml
│   │   ├── Pulumi.staging.yaml
│   │   └── index.ts
│   ├── invalidate/         # Stack: CloudFront invalidation Lambda
│   │   ├── Pulumi.yaml
│   │   ├── Pulumi.staging.yaml
│   │   ├── index.ts
│   │   └── invalidate.mjs
│   └── deploy-backend/     # Stack: Lambda functions, API Gateway, etc.
│       ├── Pulumi.yaml
│       └── index.ts
├── Makefile
└── package.json
```

## Pulumi.yaml Configuration

Each stack needs a `Pulumi.yaml` with name, runtime, and backend:

```yaml
name: deploy-site
runtime: nodejs
backend:
  url: "s3://my-pulumi-state-bucket/?region=eu-central-1"
```

Using S3 backend keeps state management self-hosted (no Pulumi Cloud dependency).

## Stack References

When one stack needs outputs from another (e.g., invalidation stack needs the
distribution ID from the deploy stack):

```typescript
const ref = new pulumi.StackReference("organization/deploy-site/staging");
const distributionId = ref.getOutput("distributionId");
const bucketName = ref.requireOutput("bucketName");
```

Exports from the referenced stack:

```typescript
export const distributionId = cdn.id;
export const bucketName = siteBucket.bucket;
```

## Cross-Account / Cross-Region Providers

For Lambda@Edge (must be us-east-1) or cross-account deployments:

```typescript
const accountId = pulumi.output(
  aws.getCallerIdentity()
).apply(id => id.accountId);

const edgeProvider = new aws.Provider("usEast1", {
  region: "us-east-1",
  allowedAccountIds: [accountId],
  assumeRole: {
    roleArn: pulumi.interpolate
      `arn:aws:iam::${accountId}:role/deployment-role`,
  },
});

// Use with resources:
const edgeFunc = new aws.lambda.Function("edge-fn", {
  // ...
}, { provider: edgeProvider });
```

## Pulumi Dependencies

Standard `package.json` for CloudFront deployments:

```json
{
  "dependencies": {
    "@pulumi/aws": "^7.8.0",
    "@pulumi/pulumi": "^3.203.0",
    "mime-types": "^3.0.1"
  },
  "devDependencies": {
    "@types/mime-types": "^3.0.1",
    "@types/node": "^24.0.0",
    "typescript": "^5.9.0"
  }
}
```

For dynamic resources using the AWS SDK directly:

```json
{
  "dependencies": {
    "@aws-sdk/client-cloudfront": "^3.0.0"
  }
}
```

## Makefile Integration

Deployment targets that build the app and run Pulumi:

```makefile
ENV_FILE ?= .env.production

build: build-frontend build-infrastructure

build-frontend:
	yarn build

build-infrastructure:
	yarn --cwd infrastructure install --immutable --mode=skip-build
	npx tsc -p infrastructure

deploy-frontend:
	yarn install --immutable --mode=skip-build
	yarn --cwd infrastructure install --immutable
	npx tsc -p infrastructure
	bash -c 'set -a; [ -f $(ENV_FILE) ] && . $(ENV_FILE); set +a; yarn build'
	cd infrastructure/deploy-site && \
		pulumi stack select operations && \
		pulumi up --refresh --yes

invalidate:
	aws cloudfront create-invalidation \
		--distribution-id $(DISTRIBUTION_ID) \
		--paths "/index.html" --profile my-profile
```

Key patterns:
- `--immutable --mode=skip-build` for reproducible installs
- `set -a; . .env; set +a` to load environment before build
- `pulumi stack select` + `pulumi up --yes` for CI/CD
- `--refresh` to reconcile state with actual AWS resources

## Multi-Environment Stacks

Use Pulumi stack configs for environment-specific values:

**Pulumi.staging.yaml:**
```yaml
config:
  aws:region: eu-central-1
  project:domain: staging.example.com
```

**Pulumi.production.yaml:**
```yaml
config:
  aws:region: eu-central-1
  project:domain: example.com
```

Access in code:

```typescript
const config = new pulumi.Config("project");
const domain = config.require("domain");
```

## Secrets Management

For sensitive values (API tokens, OAuth secrets):

```typescript
const config = new pulumi.Config();
const apiToken = config.requireSecret("api-token");

const secret = new aws.secretsmanager.Secret("api-token");
new aws.secretsmanager.SecretVersion("api-token", {
  secretId: secret.id,
  secretString: apiToken,
});
```

Set secrets via CLI:
```bash
pulumi config set --secret api-token "sk-..."
```

## Scheduled Lambda (Cron)

For periodic tasks (data fetching, report generation):

```typescript
const schedule = new aws.cloudwatch.EventRule("daily-fetch", {
  scheduleExpression: "cron(0 0 * * ? *)", // midnight UTC daily
});

new aws.cloudwatch.EventTarget("daily-fetch-target", {
  rule: schedule.name,
  arn: fetcherLambda.arn,
});

new aws.lambda.Permission("allow-schedule", {
  action: "lambda:InvokeFunction",
  function: fetcherLambda.name,
  principal: "events.amazonaws.com",
  sourceArn: schedule.arn,
});
```

## File Upload Pattern

Walk the build output directory and upload each file with correct MIME type:

```typescript
import { lookup } from "mime-types";

function walk(dir: string): string[] {
  return fs.readdirSync(dir).flatMap(f => {
    const p = path.join(dir, f);
    return fs.statSync(p).isDirectory() ? walk(p) : [p];
  });
}

for (const filePath of walk(siteDir)) {
  const relativePath = path.relative(siteDir, filePath);
  new aws.s3.BucketObject(relativePath, {
    bucket: siteBucket,
    source: new pulumi.asset.FileAsset(filePath),
    contentType: lookup(filePath) || undefined,
    key: relativePath,
  });
}
```

**Important:** Use `mime-types` to set `contentType` — S3 does not auto-detect
MIME types. Without it, browsers may not render CSS, JS, or images correctly.
