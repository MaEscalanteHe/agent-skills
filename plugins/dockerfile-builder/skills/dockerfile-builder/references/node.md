# Node.js Dockerfile Patterns

## Table of Contents

- [Production Dockerfile](#production-dockerfile)
- [Why npm ci Over npm install](#why-npm-ci-over-npm-install)
- [Private Registry Authentication](#private-registry-authentication)
- [Next.js Standalone Output](#nextjs-standalone-output)
- [Dev vs Production NODE_ENV](#dev-vs-production-node_env)

---

## Production Dockerfile

Complete multi-stage Dockerfile for a Node.js service with TypeScript build step. Uses four stages to separate concerns and minimize the final image:

```dockerfile
# syntax=docker/dockerfile:1
FROM node:20-alpine AS deps

WORKDIR /app
COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm \
    npm ci

FROM deps AS build

COPY . .
RUN npm run build

FROM deps AS prod-deps

RUN --mount=type=cache,target=/root/.npm \
    npm ci --omit=dev

FROM node:20-alpine AS runtime

WORKDIR /app
ENV NODE_ENV=production

# Alpine node images include a 'node' user (uid 1000)
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

COPY --from=prod-deps /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY --from=build /app/package.json ./

USER nodejs
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3000/health', (r) => { if (r.statusCode !== 200) throw new Error(); })"

CMD ["node", "dist/index.js"]
```

Key decisions:

- **Four stages** (deps → build → prod-deps → runtime): separates dev dependencies (needed for build) from production dependencies (needed at runtime). The build stage has everything; the runtime stage has only production deps + compiled output
- **Cache mount on /root/.npm**: npm's global cache persists across builds, so repeated `npm ci` only downloads changed packages
- **Separate prod-deps stage**: runs `npm ci --omit=dev` from the original lockfile, ensuring production gets exactly the right dependency tree without devDependencies
- **Custom user**: creates a non-root `nodejs` user instead of using the built-in `node` user, for explicit UID control

## Why npm ci Over npm install

|                  | `npm ci`                                   | `npm install`                   |
| ---------------- | ------------------------------------------ | ------------------------------- |
| **Lockfile**     | Requires exact match, fails if out of sync | Updates lockfile if out of sync |
| **node_modules** | Deletes existing, installs fresh           | Merges with existing            |
| **Speed**        | Faster (skips dependency resolution)       | Slower (resolves every time)    |
| **Determinism**  | Exact versions from lockfile               | May install different versions  |

In Docker builds, `npm ci` is always the right choice because you want deterministic, reproducible installs. The lockfile is your source of truth.

For pnpm, the equivalent is:

```dockerfile
RUN --mount=type=cache,target=/root/.local/share/pnpm/store \
    pnpm install --frozen-lockfile
```

For yarn:

```dockerfile
RUN --mount=type=cache,target=/usr/local/share/.cache/yarn \
    yarn install --frozen-lockfile
```

## Private Registry Authentication

Use `--mount=type=secret` to authenticate with private npm registries without leaking tokens into image layers:

```dockerfile
# syntax=docker/dockerfile:1
FROM node:20-alpine AS deps

WORKDIR /app
COPY package.json package-lock.json ./

# .npmrc with auth token is mounted only during this RUN — never persisted
RUN --mount=type=secret,id=npmrc,target=/root/.npmrc \
    --mount=type=cache,target=/root/.npm \
    npm ci

# Build command:
# docker build --secret id=npmrc,src=$HOME/.npmrc .
```

The `.npmrc` file is available only during the `npm ci` command and never becomes part of any image layer. This is critical — an `ARG NPM_TOKEN` or `COPY .npmrc` approach would embed the token in the image history even if you delete the file later.

## Next.js Standalone Output

Next.js `standalone` output mode bundles only the required node_modules, reducing image size significantly:

```dockerfile
# syntax=docker/dockerfile:1
FROM node:20-alpine AS deps

WORKDIR /app
COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm \
    npm ci

FROM deps AS build

COPY . .
RUN npm run build

FROM node:20-alpine AS runtime

WORKDIR /app
ENV NODE_ENV=production

RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Next.js standalone includes a minimal server and only required node_modules
COPY --from=build /app/.next/standalone ./
COPY --from=build /app/.next/static ./.next/static
COPY --from=build /app/public ./public

USER nodejs
EXPOSE 3000

CMD ["node", "server.js"]
```

Requires `output: 'standalone'` in `next.config.js`. The standalone output is typically 80-90% smaller than copying the full `node_modules`.

## Dev vs Production NODE_ENV

Setting `NODE_ENV=production` in the runtime stage has concrete effects:

- **Express**: disables verbose error pages, enables view template caching
- **npm ci --omit=dev**: skips devDependencies (test frameworks, linters, build tools)
- **Many libraries**: enable optimizations, disable debug logging

Do not set `NODE_ENV=production` in the build stage — you need devDependencies (TypeScript, bundlers, etc.) available during compilation.
