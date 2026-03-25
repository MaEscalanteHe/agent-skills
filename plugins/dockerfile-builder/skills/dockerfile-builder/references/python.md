# Python Dockerfile Patterns

## Table of Contents

- [Production Dockerfile](#production-dockerfile)
- [Virtual Environment Variant](#virtual-environment-variant)
- [Poetry Variant](#poetry-variant)
- [uv Variant](#uv-variant)
- [Environment Variables](#environment-variables)

---

## Production Dockerfile

Complete multi-stage Dockerfile for a Python web service (FastAPI/Flask) using `pip install --user`:

```dockerfile
# syntax=docker/dockerfile:1
FROM python:3.12-slim AS builder

WORKDIR /build
COPY requirements.txt .

RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --user --no-warn-script-location -r requirements.txt

FROM python:3.12-slim

WORKDIR /app

RUN groupadd -r python && useradd -r -g python -u 1001 python && \
    chown python:python /app

COPY --from=builder /root/.local /home/python/.local
COPY --chown=python:python . .

ENV PATH=/home/python/.local/bin:$PATH \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

USER python
EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')"

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

Key decisions:

- **pip install --user**: installs to `/root/.local` instead of system site-packages, making it easy to copy only user packages to the runtime stage
- **slim over alpine**: Python on Alpine uses musl libc, which causes compatibility issues with many C-extension packages (numpy, pandas, cryptography). Slim uses glibc and avoids painful rebuilds
- **Cache mount on pip cache**: downloaded wheels persist across builds, so only new/changed packages are downloaded
- **HEALTHCHECK without curl**: uses Python's stdlib `urllib` so there's no need to install curl in the runtime image

## Virtual Environment Variant

For applications that use virtual environments (better isolation, easier to reason about):

```dockerfile
# syntax=docker/dockerfile:1
FROM python:3.12-slim AS builder

WORKDIR /build
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY requirements.txt .
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r requirements.txt

FROM python:3.12-slim

RUN groupadd -r python && useradd -r -g python -u 1001 python

WORKDIR /app
COPY --from=builder /opt/venv /opt/venv
COPY --chown=python:python . .

ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

USER python
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

The venv approach copies the entire virtual environment directory. This is conceptually cleaner and avoids polluting system Python, though the result is functionally identical to `--user` for single-app containers.

## Poetry Variant

Poetry manages dependencies with `pyproject.toml` and `poetry.lock`. Export to `requirements.txt` for the Docker build to avoid installing Poetry in the runtime image:

```dockerfile
# syntax=docker/dockerfile:1
FROM python:3.12-slim AS export

RUN pip install poetry
WORKDIR /build
COPY pyproject.toml poetry.lock ./
RUN poetry export -f requirements.txt --without-hashes -o requirements.txt

FROM python:3.12-slim AS builder

WORKDIR /build
COPY --from=export /build/requirements.txt .
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --user --no-warn-script-location -r requirements.txt

FROM python:3.12-slim

WORKDIR /app
RUN groupadd -r python && useradd -r -g python -u 1001 python

COPY --from=builder /root/.local /home/python/.local
COPY --chown=python:python . .

ENV PATH=/home/python/.local/bin:$PATH \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

USER python
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

The export stage installs Poetry only to generate `requirements.txt` — Poetry itself never reaches the runtime image.

## uv Variant

uv is a fast Python package manager (written in Rust) that can replace pip. It's significantly faster for dependency resolution and installation:

```dockerfile
# syntax=docker/dockerfile:1
FROM python:3.12-slim AS builder

COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

WORKDIR /build
COPY pyproject.toml uv.lock ./

RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev --no-install-project

COPY . .
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev

FROM python:3.12-slim

WORKDIR /app
RUN groupadd -r python && useradd -r -g python -u 1001 python

COPY --from=builder /build/.venv /app/.venv
COPY --chown=python:python . .

ENV PATH="/app/.venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

USER python
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

Key difference: uv is copied from its official image (`COPY --from=ghcr.io/astral-sh/uv:latest`) so it's never installed via pip. The `--frozen` flag ensures the lockfile is respected exactly, similar to `npm ci`.

## Environment Variables

| Variable                    | Value                           | Why                                                                                                                              |
| --------------------------- | ------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| `PYTHONUNBUFFERED=1`        | Forces unbuffered stdout/stderr | Without this, Python buffers output and container logs appear delayed or not at all. Critical for observability                  |
| `PYTHONDONTWRITEBYTECODE=1` | Prevents `.pyc` file creation   | `.pyc` files are useless in containers (the code won't be modified at runtime) and add unnecessary size                          |
| `PIP_NO_CACHE_DIR=1`        | Disables pip's wheel cache      | Only useful when NOT using `--mount=type=cache`. With cache mounts, keep pip's cache enabled since it persists outside the image |

When using `--mount=type=cache,target=/root/.cache/pip`, do **not** set `PIP_NO_CACHE_DIR=1` — that would disable the cache you're trying to persist.
