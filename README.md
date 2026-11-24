# Production packaging training demo

A small FastAPI service and walkthrough for the training topics: Docker and secrets, CI and versioning, staging vs production, and API access control.

> **Training scope:** the bearer tokens in this sample are a teaching aid. They are not an identity provider. For production, validate OIDC/JWT credentials using your approved identity provider, enforce tenant/resource permissions from trusted claims and data, use a managed secret store, and configure TLS, rate limits, logging, monitoring, and deployment approvals in your platform.

## What is included

- `app.py` — health/version routes, caller-derived scopes, tenant isolation, and a guarded action endpoint.
- `Dockerfile` — small runtime image pattern, non-root process, and no secrets baked into the image.
- `.env.example` — local-only placeholder configuration. It is safe to commit because it contains no real credentials.
- `.github/workflows/ci.yml` — pull request and main-branch validation plus a container build.
- This guide — local demo steps, manual security checks, promotion and rollback narration.

## Prerequisites

- Python 3.12+
- Docker Engine with the `docker compose` plugin
- `curl`

## 1. Start the API locally

From this directory, copy the example and replace both token placeholders with different, random local demo strings. Do not reuse real credentials.

```bash
cp .env.example .env.local
```

Build the image once:

```bash
docker build --tag production-packaging-demo:training .
docker image inspect production-packaging-demo:training --format '{{.Id}}'
```

Run the container with runtime configuration. The secret values are supplied at container start; they are not part of the image build.

```bash
docker run --rm --name training-api \
  --env-file .env.local \
  -p 8000:8000 \
  production-packaging-demo:training
```

In another terminal, check health and release identity:

```bash
curl -sS http://localhost:8000/health
curl -sS http://localhost:8000/version
```

For a real deployment, replace `--env-file` with the platform's approved secret injection mechanism. Never commit `.env.local` or paste its values into a recording.

## 2. Demonstrate authentication and authorization

Set shell variables to the same fake local values used in `.env.local` (or read them without displaying them). These examples assume the local demo strings are `reader-demo-value` and `admin-demo-value`; replace them with your own.

Missing credential: should return `401`.

```bash
curl -i http://localhost:8000/v1/tenants/tenant-a/records/record-101
```

Reader can access its own tenant's record: should return `200`.

```bash
curl -i -H 'Authorization: Bearer reader-demo-value' \
  http://localhost:8000/v1/tenants/tenant-a/records/record-101
```

Reader cannot access another tenant: should return `403`.

```bash
curl -i -H 'Authorization: Bearer reader-demo-value' \
  http://localhost:8000/v1/tenants/tenant-b/records/record-202
```

Reader cannot run an action: should return `403` before any tool would run.

```bash
curl -i -X POST http://localhost:8000/v1/actions \
  -H 'Authorization: Bearer reader-demo-value' \
  -H 'Content-Type: application/json' \
  -d '{"action":"refresh_record","record_id":"record-101"}'
```

Admin can run the permitted action: should return `202`.

```bash
curl -i -X POST http://localhost:8000/v1/actions \
  -H 'Authorization: Bearer admin-demo-value' \
  -H 'Content-Type: application/json' \
  -d '{"action":"refresh_record","record_id":"record-101"}'
```

The app derives tenant and scopes from the server-side credential mapping. It does not trust a caller-provided role or tenant header. In production, derive these from a validated identity token and check resource ownership against the authoritative data store.

## 3. Explain the CI pipeline

The included GitHub Actions workflow runs on pull requests and pushes to `main`. It installs locked application dependencies, compiles the Python module, and builds a Docker image tagged with the source commit.

For your organization, extend the pipeline with:

1. Unit, integration, and agent regression checks.
2. Dependency and container image scanning.
3. Registry publication with commit metadata and an immutable digest.
4. Deployment of that exact digest to staging.
5. Staging smoke, authorization, and critical-path checks.
6. A recorded approval gate.
7. Promotion of the same digest to production, followed by readiness and telemetry checks.

The workflow intentionally leaves registry and deployment steps as platform-specific additions. Do not rebuild a different image for production: promote the already verified digest.

## 4. Staging, production, and rollback walkthrough

Use a separate identity, credentials, and data for each environment. Keep the deployment path and runtime behavior as similar as practical. Keep environment-specific endpoints and secret references in deployment configuration, not in the image.

For the training narration, show these release records side by side:

- Source commit and CI run.
- Image digest and scan/test evidence.
- Prompt, model, tool-contract, and workflow versions.
- Staging configuration version and checks performed.
- Approver, target environment, and deployment time.
- Last known-good digest plus its compatible configuration.

Before production promotion, confirm the staging checks pass and the approved digest matches the candidate. After promotion, verify readiness, critical API paths, dependency access, deployed digest, error rate, and latency. Pause on unclear signals; revert on a critical failure.

## 5. Secrets management and rotation narration

- Build-time credentials are needed only for a build step, such as retrieving a private package. Use the CI platform's temporary secret mount; do not use Docker `ARG` or `ENV` for secrets.
- Runtime credentials are injected by the deployment platform's secret manager and differ by environment.
- Rotate by issuing a replacement, deploying it, confirming use by credential identifier in access logs, then revoking the old credential.
- Never print a secret to prove it is being used. Keep values out of source, image layers, CI output, application logs, and model context.

## Cleanup

Stop the local container with `Ctrl+C`, then remove local artifacts when finished:

```bash
docker image rm production-packaging-demo:training
rm -f .env.local
```
