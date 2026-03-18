# Lambda@Edge Authentication

Pattern for adding authentication to CloudFront distributions using
Lambda@Edge viewer-request functions. Commonly used for internal tools,
staging environments, and admin dashboards.

## Architecture

```
User → CloudFront → Lambda@Edge (viewer-request) → S3
                         ↓
                   OAuth Provider (Google, etc.)
```

The Lambda@Edge function intercepts every viewer request. It checks for
an authentication cookie, redirects unauthenticated users to an OAuth
provider, and validates tokens on return.

## Cross-Region Deployment

Lambda@Edge functions MUST be deployed in `us-east-1`, regardless of the
CloudFront distribution's region. Use a separate AWS provider:

```typescript
const edgeProvider = new aws.Provider("usEast1", {
  region: "us-east-1",
  allowedAccountIds: [accountId],
  assumeRole: {
    roleArn: pulumi.interpolate
      `arn:aws:iam::${accountId}:role/deployment-cross-account-role`,
  },
});
```

## IAM Role for Lambda@Edge

Lambda@Edge requires both `lambda.amazonaws.com` and
`edgelambda.amazonaws.com` as trusted principals:

```typescript
const edgeRole = new aws.iam.Role("edge-role", {
  assumeRolePolicy: aws.iam.getPolicyDocumentOutput({
    statements: [{
      actions: ["sts:AssumeRole"],
      principals: [{
        type: "Service",
        identifiers: [
          "lambda.amazonaws.com",
          "edgelambda.amazonaws.com",
        ],
      }],
    }],
  }).json,
});

new aws.iam.RolePolicyAttachment("edge-basic-exec", {
  role: edgeRole.name,
  policyArn: aws.iam.ManagedPolicies.AWSLambdaBasicExecutionRole,
});
```

## Lambda@Edge Function (Python)

Google OAuth example that verifies `id_token` cookies:

```python
import json, re, urllib.request
from urllib.parse import urlencode

GOOGLE_CLIENT_ID = "your-client-id.apps.googleusercontent.com"
CALLBACK_PATH = "oauth2/callback.html"
ALLOWED_EMAILS = [
    "user@example.com",
]

def _get_id_token(headers):
    cookie_headers = headers.get("cookie", [])
    for header in cookie_headers:
        match = re.search(r"id_token=([^;]+)", header["value"])
        if match:
            return match.group(1)
    return None

def _authorized(payload):
    email = payload.get("email", "").lower()
    return email in ALLOWED_EMAILS

def _verify(id_token):
    try:
        url = f"https://oauth2.googleapis.com/tokeninfo?id_token={id_token}"
        with urllib.request.urlopen(url) as resp:
            payload = json.load(resp)
            return payload.get("aud") == GOOGLE_CLIENT_ID, payload
    except Exception:
        return False, None

def handler(event, context):
    request = event["Records"][0]["cf"]["request"]
    headers = request["headers"]
    host = headers["host"][0]["value"]
    uri = request["uri"]

    # Serve static assets without auth
    if uri.endswith(('.css', '.ico', '.js', '.otf')):
        return request

    # Allow callback page through
    if uri.startswith(f"/{CALLBACK_PATH}"):
        return request

    id_token = _get_id_token(headers)
    if not id_token:
        return _redirect(host)

    verified, payload = _verify(id_token)
    if not verified:
        return _redirect(host)
    if not _authorized(payload):
        return _deny()

    return request

def _redirect(host):
    params = {
        "client_id": GOOGLE_CLIENT_ID,
        "response_type": "id_token",
        "scope": "openid email",
        "redirect_uri": f"https://{host}/{CALLBACK_PATH}",
        "nonce": "random",
    }
    url = f"https://accounts.google.com/o/oauth2/v2/auth?{urlencode(params)}"
    return {
        "status": "302",
        "headers": {"location": [{"key": "Location", "value": url}]},
    }

def _deny():
    return {"status": "403", "body": "Forbidden"}
```

## Deploying the Function

```typescript
const edgeFunc = new aws.lambda.Function("google-oauth-edge", {
  code: new pulumi.asset.AssetArchive({
    ".": new pulumi.asset.FileArchive("./edge-auth"),
  }),
  handler: "edge.handler",
  runtime: "python3.10",
  role: edgeRole.arn,
  publish: true, // Required for Lambda@Edge — creates a versioned ARN
}, { provider: edgeProvider, dependsOn: [edgeProvider] });
```

## Attaching to Distribution

Use `lambdaFunctionAssociations` with `qualifiedArn` (includes version):

```typescript
defaultCacheBehavior: {
  // ... other settings ...
  lambdaFunctionAssociations: [{
    eventType: "viewer-request",
    lambdaArn: edgeFunc.qualifiedArn,
    includeBody: false,
  }],
},
```

## Lambda@Edge Constraints

- **No environment variables.** Config must be baked into the code.
- **Max 1 MB** deployment package for viewer-request/response.
- **Max 5 seconds** timeout for viewer-request/response.
- **Max 30 seconds** timeout for origin-request/response.
- **us-east-1 only** for function deployment.
- **Versioned ARN required** — set `publish: true` on the Lambda.
- Standard Python/Node.js libraries only — no custom layers for viewer events.

## CloudFront Functions vs Lambda@Edge

| Feature | CloudFront Functions | Lambda@Edge |
|---|---|---|
| Event types | viewer-request, viewer-response | All four |
| Runtime | cloudfront-js-1.0 (JS only) | Node.js, Python |
| Max duration | <1 ms | 5s (viewer), 30s (origin) |
| Max memory | 2 MB | 128–10240 MB |
| Network access | No | Yes |
| Request body access | No | Yes |
| Environment vars | No | No (viewer), Yes (origin) |
| Cost | ~1/6 of Lambda@Edge | Higher |

**Use CloudFront Functions for:** URL rewrites, header manipulation, redirects,
simple authorization (JWT validation without network calls).

**Use Lambda@Edge for:** OAuth flows requiring network calls, complex
authentication, request/response transformation with external data, A/B testing
with backend calls.
