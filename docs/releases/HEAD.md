# HEAD

- Added a self-contained Docker setup (`Dockerfile`, `docker-compose.yml`,
  `.dockerignore`) that runs the server with only Docker installed, borrowing
  the host Codex login via a `~/.codex` bind mount. See `docs/docker.md`.
