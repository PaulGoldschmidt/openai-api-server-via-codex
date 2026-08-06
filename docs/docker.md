# Run with Docker

The repository ships a self-contained Docker setup. The only host requirements
are Docker (with Compose) and a working Codex login at `~/.codex/auth.json` —
no local Python, `uv`, or other tooling is needed.

## Quick start

Log in to Codex once on the host if you have not already:

```console
$ codex login
```

Then build and start the server:

```console
$ docker compose up --build -d
```

The server listens on `http://127.0.0.1:18080`. Verify it:

```console
$ curl http://127.0.0.1:18080/healthz
$ curl http://127.0.0.1:18080/v1/models
```

Use it with any OpenAI client:

```python
from openai import OpenAI

client = OpenAI(base_url="http://127.0.0.1:18080/v1", api_key="unused")
response = client.responses.create(model="gpt-5.5", input="Hello!")
print(response.output_text)
```

Follow logs and stop the server:

```console
$ docker compose logs -f
$ docker compose down
```

## How authentication works

The container does not store credentials. `docker-compose.yml` bind-mounts the
host's `~/.codex` directory (or `$CODEX_HOME` when set) into the container,
where the server reads `auth.json`. When the access token expires, the server
refreshes it and writes the new tokens back through the mount, so the mount
must remain read-write.

The `serve` command validates the Codex auth file before binding the port. If
the file is missing or invalid, the container exits with a redacted error —
check `docker compose logs` and run `codex login` on the host.

## Configuration

The image sets `OPENAI_VIA_CODEX_HOST=0.0.0.0` so the server is reachable
through Docker's port mapping; the Compose file publishes it on loopback only,
matching the non-Docker default. All other settings keep their defaults and can
be changed with `OPENAI_VIA_CODEX_*` environment variables in the `environment`
block of `docker-compose.yml`, for example:

- `OPENAI_VIA_CODEX_API_KEY` — require `Authorization: Bearer <key>` for
  `/v1/...` routes (`/healthz` stays open, so the container healthcheck keeps
  working).
- `OPENAI_VIA_CODEX_VERBOSE=1` — debug-level logs.
- `OPENAI_VIA_CODEX_DEFAULT_MODEL` — default model when a request omits one.
- `OPENAI_VIA_CODEX_TIMEOUT`, `OPENAI_VIA_CODEX_MAX_STORED_ITEMS`,
  `OPENAI_VIA_CODEX_MAX_CONCURRENT_REQUESTS` — backend timeout and bounds.

Alternatively, mount a `config.toml` and point the server at it:

```yaml
    volumes:
      - ${CODEX_HOME:-$HOME/.codex}:/home/app/.codex
      - ./config.toml:/home/app/.config/openai-api-server-via-codex/config.toml:ro
```

Setting precedence is unchanged: CLI flag, environment variable, config file,
default.

## Plain `docker` (without Compose)

```console
$ docker build -t openai-api-server-via-codex:local .
$ docker run --rm -p 127.0.0.1:18080:18080 \
    -v ~/.codex:/home/app/.codex \
    openai-api-server-via-codex:local
```

## Notes

- The container runs as a non-root user with UID/GID 1000. On Linux hosts
  where your user is not 1000:1000, set `user: "<uid>:<gid>"` in
  `docker-compose.yml` (or `--user` for `docker run`) so the container can
  read and update the mounted Codex login. Docker Desktop on macOS and Windows
  handles this automatically.
- The daemon subcommands (`start`, `stop`, `status`) are for host installs;
  in Docker the container itself is the daemon, so the image runs `serve` in
  the foreground and Compose manages restarts.
- The container healthcheck polls `/healthz`, so `docker ps` shows the
  service as `healthy` once the server is up.
