---
name: dockerfile-builder
description: "Generate optimized, secure multi-stage Dockerfiles using modern BuildKit features. TRIGGER when: writing, creating, reviewing, or refactoring Dockerfiles, container images, Docker builds, docker-compose build configurations, CI/CD container pipelines, or .dockerignore files. Also trigger when discussing image size reduction, build caching, container security hardening, or multi-stage builds. DO NOT TRIGGER when: working with Kubernetes manifests, Helm charts, Docker Compose runtime configuration (not build), Terraform, or container orchestration that doesn't involve building images."
---

# Multi-Stage Dockerfile Guide

Generate efficient, secure multi-stage Dockerfiles that minimize image size, maximize build cache utilization, and follow container security best practices.

## BuildKit Syntax Directive

Start every Dockerfile with the BuildKit syntax directive. This enables modern features like cache mounts, secret mounts, heredocs, and `COPY --link` that are central to this guide:

```dockerfile
# syntax=docker/dockerfile:1
FROM python:3.12-slim AS builder
# ...
```

BuildKit has been the default builder since Docker 23.0 (February 2023). The syntax directive ensures consistent behavior regardless of the Docker version, and automatically pulls the latest stable frontend.

## Multi-Stage Structure

Multi-stage builds separate build-time dependencies from runtime, dramatically reducing image size:

| Language | Before (single-stage) | After (multi-stage) | Reduction |
| -------- | --------------------- | ------------------- | --------- |
| Go       | ~1.1 GB               | ~9 MB               | 99%       |
| Node.js  | ~1.1 GB               | ~130 MB             | 88%       |
| Python   | ~1.3 GB               | ~250 MB             | 81%       |
| Java     | ~1.4 GB               | ~300 MB             | 78%       |

Name every stage with `AS` for readability and to avoid fragile numeric references:

```dockerfile
# Bad — numeric reference breaks if stages are reordered
FROM golang:1.22 AS 0
FROM scratch
COPY --from=0 /build/app /app

# Good — named stage survives reordering
FROM golang:1.22-alpine AS builder
WORKDIR /build
COPY . .
RUN go build -o app .

FROM scratch
COPY --from=builder /build/app /app
ENTRYPOINT ["/app"]
```

Order stages by purpose: **dependencies → build → test (optional) → runtime**. This reads top-to-bottom like a pipeline and BuildKit can parallelize independent stages automatically.

### Single-Stage vs Multi-Stage

```dockerfile
# Bad — single stage includes everything (build tools, source, dev deps)
FROM node:20
WORKDIR /app
COPY . .
RUN npm install
RUN npm run build
CMD ["node", "dist/index.js"]
# Result: ~1.1 GB image with npm, build tools, devDependencies, source code

# Good — multi-stage copies only what's needed to run
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:20-alpine
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
USER node
CMD ["node", "dist/index.js"]
# Result: ~130 MB image with only runtime dependencies
```

## Base Image Selection

Choose the smallest base that supports your runtime requirements:

| Base         | Size     | Best For                                      | Tradeoff                                                             |
| ------------ | -------- | --------------------------------------------- | -------------------------------------------------------------------- |
| `scratch`    | 0 MB     | Static Go/Rust binaries                       | Nothing included — no shell, no certs, no debugging                  |
| `distroless` | ~2-20 MB | Compiled apps needing CA certs, timezone data | No shell or package manager, harder to debug                         |
| `alpine`     | ~5-6 MB  | Apps needing a package manager or shell       | Uses musl libc — some C extensions may not work (e.g., Python numpy) |
| `*-slim`     | ~80 MB   | Apps with glibc dependencies                  | Debian-based without docs/man pages, good compatibility              |

Pin images to specific versions for reproducible builds. Tags like `latest` or `node:20` can change without notice:

```dockerfile
# Acceptable — pinned to minor version
FROM python:3.12-slim

# Best — pinned to digest (immutable)
FROM python:3.12-slim@sha256:abc123...
```

Use `docker inspect <image>` to find the current digest.

## Layer Optimization

Docker caches each layer. If any instruction changes, that layer **and all subsequent layers** rebuild. This cascading invalidation is why instruction order matters:

```dockerfile
# Bad — source code change invalidates dependency installation
COPY . .
RUN npm ci
RUN npm run build

# Good — dependencies cached independently of source changes
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build
```

### COPY --link

`COPY --link` creates layers independent of previous layers, so base image updates don't invalidate file copies:

```dockerfile
COPY --link package.json package-lock.json ./
```

This means a security patch to the base image won't force re-copying your dependency files. Useful for large artifacts that rarely change.

### Combining RUN Commands

Each `RUN` creates a layer. Combine related operations to reduce layers and ensure cleanup happens in the same layer as installation:

```dockerfile
# Bad — cleanup in separate layer doesn't reduce image size
RUN apt-get update
RUN apt-get install -y curl
RUN rm -rf /var/lib/apt/lists/*

# Good — single layer, cleanup in same step
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*
```

### Heredocs

For complex multi-line scripts, heredoc syntax (requires BuildKit) is more readable than backslash continuation:

```dockerfile
RUN <<EOF
  apt-get update
  apt-get install -y --no-install-recommends curl wget
  rm -rf /var/lib/apt/lists/*
EOF
```

## Build Cache Mounts

`--mount=type=cache` persists package manager caches across builds. Downloaded packages survive even when the layer rebuilds, reducing CI/CD pipeline times by 70-85%:

```dockerfile
# Python — pip cache
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r requirements.txt

# Node.js — npm cache
RUN --mount=type=cache,target=/root/.npm \
    npm ci

# Go — module and build caches
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    go build -o app .

# Java (Maven) — local repository (sharing=locked prevents corruption)
RUN --mount=type=cache,target=/root/.m2/repository,sharing=locked \
    mvn package -B
```

Use `sharing=locked` for tools that can't handle concurrent cache access (Maven, Gradle). Use the default `sharing=shared` for tools that can (pip, npm, go).

Cache mounts are never included in the final image — they exist only on the build host.

### Bind Mounts

`--mount=type=bind` mounts files from the build context temporarily without copying them into a layer:

```dockerfile
RUN --mount=type=bind,source=requirements.txt,target=/tmp/requirements.txt \
    pip install -r /tmp/requirements.txt
```

Useful when you need a file during a RUN command but don't want it persisted in the image.

## Secrets Handling

Secrets passed via `ARG` or `ENV` persist in image layers and are visible in `docker history`. Use `--mount=type=secret` instead — secrets are mounted as temporary files during the build and never written to any layer:

```dockerfile
# Bad — token persists in image history
ARG NPM_TOKEN
RUN echo "//registry.npmjs.org/:_authToken=${NPM_TOKEN}" > .npmrc && \
    npm ci && \
    rm .npmrc
# The rm doesn't help — the token is in the layer where it was created

# Good — secret is ephemeral, never in any layer
RUN --mount=type=secret,id=npmrc,target=/root/.npmrc \
    npm ci

# Build command:
# docker build --secret id=npmrc,src=$HOME/.npmrc .
```

For private Git repositories, use `--mount=type=ssh`:

```dockerfile
RUN --mount=type=ssh \
    git clone git@github.com:org/private-repo.git

# Build command:
# docker build --ssh default=$SSH_AUTH_SOCK .
```

## Security Practices

### Non-Root User

Running as root inside a container means an attacker who escapes the container has root on the host. Create and switch to a non-root user in the final stage:

```dockerfile
# Alpine
RUN addgroup -g 1001 -S appuser && \
    adduser -S appuser -u 1001 -G appuser
USER appuser

# Debian/slim
RUN groupadd -r appuser && useradd -r -g appuser -u 1001 appuser
USER appuser

# scratch (no useradd available — use numeric UID)
USER 65534:65534
```

### Absolute WORKDIR

Always use absolute paths for `WORKDIR`. Relative paths are ambiguous and can create unexpected directory structures depending on what previous instructions did:

```dockerfile
# Bad
WORKDIR app

# Good
WORKDIR /app
```

### Image Scanning and Linting

- **hadolint** — lints Dockerfiles for best practice violations (unpinned versions, missing cleanup, root user)
- **trivy** / **docker scout** — scan built images for known vulnerabilities in OS packages and application dependencies
- **Docker Content Trust** — sign and verify images to prevent tampering

```bash
hadolint Dockerfile
trivy image myapp:latest
docker scout cves myapp:latest
```

### Reproducibility

Pin base image versions to prevent silent changes. For critical builds, pin to the digest:

```dockerfile
FROM node:20.11-alpine@sha256:abc123def456...
```

Pin system package versions when installing with apt-get or apk to avoid non-deterministic builds.

## HEALTHCHECK

Docker and orchestrators use HEALTHCHECK to detect unhealthy containers and restart them automatically — beyond just checking if the process is running:

```dockerfile
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1
```

| Option           | Default | Purpose                                                           |
| ---------------- | ------- | ----------------------------------------------------------------- |
| `--interval`     | 30s     | Time between health checks                                        |
| `--timeout`      | 30s     | Max time for a check to complete before it's considered failed    |
| `--start-period` | 0s      | Grace period during startup — failures don't count toward retries |
| `--retries`      | 3       | Consecutive failures needed to mark container as unhealthy        |

**`--start-period` is critical** for applications with slow startup (Java/Spring Boot can take 10-30s, databases need initialization). Without it, the container gets marked unhealthy before it's ready.

Exit codes: `0` = healthy, `1` = unhealthy.

For services without curl installed:

```dockerfile
# Python — use stdlib
HEALTHCHECK CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')"

# Node.js — use node
HEALTHCHECK CMD node -e "require('http').get('http://localhost:3000/health', (r) => { if (r.statusCode !== 200) throw new Error(); })"

# Shell-less images (scratch/distroless) — build a tiny health binary
COPY --from=builder /build/healthcheck /healthcheck
HEALTHCHECK CMD ["/healthcheck"]
```

## .dockerignore

`.dockerignore` reduces the build context sent to the Docker daemon. A smaller context means faster builds, fewer cache invalidations, and no accidental inclusion of secrets or large files:

```
# Version control
.git
.gitignore

# Dependencies (rebuilt in container)
node_modules
__pycache__
*.pyc
.venv
vendor

# Environment and secrets
.env
.env.*

# Build artifacts
dist
build
target
*.jar
*.o

# IDE and editor files
.vscode
.idea
*.swp
.DS_Store

# CI/CD and Docker (prevent recursive context)
.github
.gitlab-ci.yml
docker-compose*.yml
Dockerfile*
.dockerignore

# Documentation and tests
*.md
!README.md
tests
coverage
```

Pattern syntax: `*` matches any sequence, `**` matches recursively, `!` negates (include despite previous exclude), `#` comments.

## Language-Specific References

For complete, production-ready Dockerfile templates with language-specific optimizations, read the relevant reference file:

- [references/go.md](references/go.md) — static binary builds with scratch/distroless, CGO handling, build flags
- [references/node.md](references/node.md) — npm ci, prod-deps stage, private registry auth, Next.js standalone
- [references/python.md](references/python.md) — pip --user, venv, Poetry/uv variants, environment variables
- [references/java.md](references/java.md) — Maven/Gradle caching, JRE-only runtime, jlink custom JRE, layered jars

## Code Review Checklist

- [ ] Uses `# syntax=docker/dockerfile:1` directive
- [ ] Multi-stage build separates build and runtime
- [ ] Base images pinned to specific versions
- [ ] Runtime image is minimal (alpine, slim, distroless, or scratch)
- [ ] Layer ordering maximizes cache hits (dependency manifests before source)
- [ ] Package manager caches use `--mount=type=cache`
- [ ] No secrets in ARG, ENV, or COPY (use `--mount=type=secret`)
- [ ] Runs as non-root USER in the final stage
- [ ] WORKDIR uses absolute paths
- [ ] `.dockerignore` excludes .git, .env, node_modules, build artifacts
- [ ] HEALTHCHECK configured for the application type
- [ ] Scanned with hadolint / trivy / docker scout
