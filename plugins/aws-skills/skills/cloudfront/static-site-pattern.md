# Static Site Deployment: S3 + CloudFront

Complete pattern for deploying a static site (Next.js export, Hugo, Vite,
etc.) to S3 with CloudFront as CDN. Uses Origin Access Control (OAC) for
secure S3 access — the bucket remains private with no public access.

## Architecture

```
User → CloudFront (HTTPS) → S3 (private, OAC)
```

- S3 bucket: private ACL, website hosting config (index/error documents)
- CloudFront: OAC-based origin, HTTPS redirect, compression
- Bucket policy: allows only CloudFront service principal via source ARN

## Complete Pulumi Example

```typescript
import * as aws from "@pulumi/aws";
import * as pulumi from "@pulumi/pulumi";
import * as fs from "fs";
import * as path from "path";
import { lookup } from "mime-types";

const siteDir = "../../out"; // Next.js export output

// --- S3 Bucket ---

const siteBucket = new aws.s3.Bucket("site-bucket", {
  website: {
    indexDocument: "index.html",
    errorDocument: "404.html",
  },
  forceDestroy: true,
  acl: "private",
});

// --- Upload Files ---

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

// --- Origin Access Control ---

const oac = new aws.cloudfront.OriginAccessControl("site-oac", {
  originAccessControlOriginType: "s3",
  signingBehavior: "always",
  signingProtocol: "sigv4",
});

// --- Cache Policy ---

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

// --- CloudFront Distribution ---

const cdn = new aws.cloudfront.Distribution("site-cdn", {
  enabled: true,
  origins: [{
    domainName: siteBucket.bucketRegionalDomainName,
    originId: siteBucket.arn,
    originAccessControlId: oac.id,
  }],
  defaultRootObject: "index.html",
  defaultCacheBehavior: {
    targetOriginId: siteBucket.arn,
    viewerProtocolPolicy: "redirect-to-https",
    allowedMethods: ["GET", "HEAD"],
    cachedMethods: ["GET", "HEAD"],
    cachePolicyId: cachePolicy.id,
    compress: true,
  },
  priceClass: "PriceClass_100",
  restrictions: {
    geoRestriction: { restrictionType: "none" },
  },
  viewerCertificate: {
    cloudfrontDefaultCertificate: true,
  },
});

// --- Bucket Policy (CloudFront-only access) ---

new aws.s3.BucketPolicy("secure-bucket-policy", {
  bucket: siteBucket.bucket,
  policy: pulumi.all([siteBucket.bucket, cdn.arn]).apply(
    ([bucket, distArn]) => JSON.stringify({
      Version: "2012-10-17",
      Statement: [{
        Sid: "AllowCloudFrontServicePrincipalReadOnly",
        Effect: "Allow",
        Principal: { Service: "cloudfront.amazonaws.com" },
        Action: "s3:GetObject",
        Resource: `arn:aws:s3:::${bucket}/*`,
        Condition: {
          StringEquals: { "AWS:SourceArn": distArn },
        },
      }],
    })
  ),
});

// --- Exports ---

export const bucketName = siteBucket.bucket;
export const cloudFrontUrl = cdn.domainName;
export const distributionId = cdn.id;
```

## Key Design Decisions

### OAC vs OAI

Origin Access Control (OAC) is the modern replacement for Origin Access
Identity (OAI). OAC uses SigV4 signing and supports:
- S3 server-side encryption (SSE-S3 and SSE-KMS)
- Dynamic requests (PUT, DELETE) to S3 via CloudFront
- All S3 bucket types including directory buckets

Always use OAC for new deployments.

### Bucket Regional Domain Name

Use `bucketRegionalDomainName` (not `bucketDomainName`) for the origin to
avoid redirect issues across regions. The regional domain format is
`bucket-name.s3.region.amazonaws.com`.

### Price Classes

| Price Class | Regions | Cost |
|---|---|---|
| `PriceClass_100` | US, Canada, Europe | Cheapest |
| `PriceClass_200` | + Asia, Middle East, Africa | Mid-tier |
| `PriceClass_All` | All edge locations | Most expensive |

For most use cases, `PriceClass_100` is sufficient.

### Versioning

Enable bucket versioning for rollback capability:

```typescript
const bucket = new aws.s3.Bucket("reports", {
  versioning: { enabled: true },
  lifecycleRules: [{
    id: "expire-old-artifacts",
    enabled: true,
    noncurrentVersionExpiration: { days: 30 },
  }],
});
```

## Custom Domain with ACM

To use a custom domain, provision an ACM certificate in `us-east-1`:

```typescript
const cert = new aws.acm.Certificate("site-cert", {
  domainName: "example.com",
  subjectAlternativeNames: ["www.example.com"],
  validationMethod: "DNS",
}, { provider: usEast1Provider });

// In distribution:
viewerCertificate: {
  acmCertificateArn: cert.arn,
  sslSupportMethod: "sni-only",
  minimumProtocolVersion: "TLSv1.2_2021",
},
aliases: ["example.com", "www.example.com"],
```

**Important:** ACM certificates for CloudFront must be in `us-east-1`
regardless of the bucket region. Create a separate AWS provider for this.
