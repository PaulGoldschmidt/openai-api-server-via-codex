# syntax=docker/dockerfile:1

# Build stage: install locked dependencies and the project with uv.
FROM ghcr.io/astral-sh/uv:python3.10-bookworm-slim AS builder

ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PYTHON_DOWNLOADS=0

WORKDIR /app

# Install dependencies first so they cache independently of source changes.
COPY pyproject.toml uv.lock ./
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-install-project --no-dev

COPY README.md LICENSE ./
COPY openai_api_server_via_codex ./openai_api_server_via_codex
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev --no-editable

# Runtime stage: copy only the virtualenv onto a slim Python base.
FROM python:3.10-slim-bookworm

RUN groupadd --gid 1000 app \
    && useradd --uid 1000 --gid app --create-home app

COPY --from=builder --chown=app:app /app/.venv /app/.venv

# The Codex login is expected as a bind mount at /home/app/.codex; the server
# reads auth.json from there and writes refreshed tokens back to it.
ENV PATH="/app/.venv/bin:$PATH" \
    CODEX_HOME=/home/app/.codex \
    OPENAI_VIA_CODEX_HOST=0.0.0.0 \
    OPENAI_VIA_CODEX_PORT=18080

USER app
EXPOSE 18080

# /healthz stays unauthenticated even when an API key is configured.
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD python -c "import os, urllib.request; urllib.request.urlopen('http://127.0.0.1:' + os.environ.get('OPENAI_VIA_CODEX_PORT', '18080') + '/healthz', timeout=4)"

ENTRYPOINT ["openai-api-server-via-codex"]
CMD ["serve"]
