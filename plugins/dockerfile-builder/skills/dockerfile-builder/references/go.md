# Go Dockerfile Patterns

## Table of Contents

- [Production Dockerfile](#production-dockerfile)
- [CGO Considerations](#cgo-considerations)
- [Scratch vs Distroless](#scratch-vs-distroless)
- [Build Flags](#build-flags)

---

## Production Dockerfile

Complete multi-stage Dockerfile for a Go HTTP service. Go compiles to a single static binary, enabling the smallest possible production images via `scratch`:

```dockerfile
# syntax=docker/dockerfile:1
FROM golang:1.22-alpine AS builder

RUN apk add --no-cache git ca-certificates

WORKDIR /build
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download

COPY . .
RUN --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -ldflags="-s -w" -o app .

FROM scratch

# TLS certificates for HTTPS calls
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# Non-root user (nobody:nobody = 65534:65534)
COPY --from=builder /etc/passwd /etc/passwd
USER 65534:65534

COPY --from=builder /build/app /app
ENTRYPOINT ["/app"]
```

Key decisions:

- **go mod download first**: dependency manifests change less often than source code, so this layer stays cached across most rebuilds
- **Two cache mounts**: `/go/pkg/mod` caches downloaded modules, `/root/.cache/go-build` caches compiled packages — both survive across builds
- **scratch base**: zero OS overhead, zero CVEs from OS packages. The binary is the entire image
- **ca-certificates**: without them, any outbound HTTPS call fails. Copy from the builder since scratch has nothing

## CGO Considerations

`CGO_ENABLED=0` produces a fully static binary with no C library dependency. This is what allows using `scratch` as the runtime base.

When you need CGO (for SQLite, certain crypto libraries, or other C bindings):

```dockerfile
# Builder still uses alpine (has musl libc)
FROM golang:1.22-alpine AS builder
RUN apk add --no-cache gcc musl-dev
WORKDIR /build
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN go build -o app .

# Runtime needs a libc — use alpine instead of scratch
FROM alpine:3.20
RUN apk add --no-cache ca-certificates
COPY --from=builder /build/app /app
USER 65534:65534
ENTRYPOINT ["/app"]
```

The tradeoff: alpine runtime adds ~5MB but provides musl libc for dynamically linked binaries. Still dramatically smaller than the golang builder image (~800MB).

## Scratch vs Distroless

| Base                                | Size   | Includes                               | Use When                                                    |
| ----------------------------------- | ------ | -------------------------------------- | ----------------------------------------------------------- |
| `scratch`                           | 0 MB   | Nothing                                | Static binary, you copy CA certs and timezone data yourself |
| `gcr.io/distroless/static-debian12` | ~2 MB  | CA certs, timezone data, `/etc/passwd` | Static binary, don't want to manage cert/tz copies          |
| `gcr.io/distroless/base-debian12`   | ~20 MB | Above + glibc                          | CGO-enabled binary needing glibc                            |

Distroless images have no shell and no package manager, which reduces attack surface but makes debugging harder. For debugging, build a separate debug variant:

```dockerfile
FROM gcr.io/distroless/static-debian12:debug
```

This adds a busybox shell for troubleshooting.

## Build Flags

```bash
go build -ldflags="-s -w" -o app .
```

- `-s` strips the symbol table — removes function names, reducing binary size
- `-w` omits DWARF debugging information — further size reduction

Together these typically reduce binary size by 20-30%. The tradeoff is that stack traces in production will show addresses instead of function names, which makes debugging harder. For services with good structured logging, this is usually acceptable.

To embed version info at build time:

```dockerfile
ARG VERSION=dev
RUN go build -ldflags="-s -w -X main.version=${VERSION}" -o app .
```
