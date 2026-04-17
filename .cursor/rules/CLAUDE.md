# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Go HTTP API that proxies the [Visual Crossing Weather API](https://www.visualcrossing.com/) with Redis caching. Two runtime modes: `API` (HTTP server) and `CON` (one-shot console output for Karlsruhe).

## Build & Run

```bash
make build          # go mod tidy + fmt + vet + build
make run            # go run API mode on port 8080
make run MODE=CON   # console mode

make redis          # start local Redis container (required for caching)
make dock           # docker build + run (host port 8085 → 8080)
make buildup        # build + docker build + docker compose up -d
make down           # docker compose down

make kapply         # kubectl apply all k8s manifests (does NOT apply ingress/ subdir)
make kpf            # minikube image load + port-forward 8080:80
make cleanup        # kubectl delete + docker rmi
```

There are no tests (`*_test.go` files do not exist yet).

## Architecture

```
cmd/weatherApi/weather.go       Entry point: flag parsing, wiring, graceful shutdown
        │
        ├── internal/config/    Reads config.json → Config struct (MustLoad pattern, fatal on failure)
        ├── internal/service/   WeatherClient: calls Visual Crossing REST API
        ├── internal/cache/     Redis wrapper: Get / Set / Ping / Close
        ├── internal/api/       HTTP server, ServeMux, all handlers, logging middleware
        └── internal/console/   Console mode: prints formatted weather tables to stdout
```

**Request flow (API mode):**
```
HTTP request → ServeHTTP (logging middleware) → handler
  → Redis cache lookup (key = location string, TTL = 30s)
      HIT:  return cached JSON
      MISS: call Visual Crossing → cache result → return JSON
```

All responses use `APIResponse`: `{ "success": bool, "message": "...", "description": "...", "details": <payload> }`.

Endpoints: `GET /api/weather`, `GET /api/weather/windspeed`, `GET /api/pingRedis`. Both weather endpoints accept a `location` query param (default `"Karlsruhe"`) and share the same Redis key space.

## Configuration

**`config.json`** (required in CWD — loaded via `MustLoadConfig()`, process exits if missing):
```json
{ "ApiKey": "..." }
```

**Environment variables:**
| Variable | Description |
|---|---|
| `REDIS_URL` | Full Redis URL (e.g. `redis://redis-cache:6379`). Missing = caching disabled (non-fatal). |

**CLI flags:** `-mode` (default `API`), `-port` (default `8080`).

## Key Gotchas

- **`cache` is nil when Redis is unavailable** — all usages in `weather_api.go` are nil-guarded; the app runs without caching.
- **`Config.RedisUrl` struct field is dead** — it's never populated; the app reads `REDIS_URL` from env, not `config.json`.
- **K8s injects `VISUALCROSSING_API_KEY` and `PORT` env vars, but the app never reads them** — it reads the key from `config.json` and the port from the `-port` flag.
- **`ingress/` is not applied by `make kapply`** — `kubectl apply -f k8s/.` doesn't recurse into subdirectories; apply the ingress manually.
- **No `/health` endpoint** — the K8s readiness probe is commented out waiting for one. The Terraform ALB health check also targets `/health`.

## Code Conventions

- **Standard library HTTP only** — `net/http.ServeMux`; no Gin, Chi, Echo, etc.
- **Provider pattern** — `NewWeatherClient(apiKey)` for the weather client.
- **Nil-guarded optional dependency** — `cache *cache.Cache` on `Server`; checked before every use.
- **`writeJSON` helper** — sets `Content-Type`, status code, and encodes body in one call.
- **Import aliasing** — `weatherService "github.com/.../internal/service"` to avoid collision with the `service` package name.
- **`go build -buildvcs=false`** — used in makefile to suppress VCS stamping in Docker/CI contexts.

## Docker

| File | Purpose |
|---|---|
| `dockerfile` | Dev — multi-stage with BuildKit cache mounts |
| `dockerfile.prod` | Prod — multi-stage, `CGO_ENABLED=0`, `-ldflags="-w -s"` stripped binary |

Dev compose: host port **12345 → 8080**. Prod compose: port 8080, no host binding.

## Kubernetes (`k8s/`, namespace `weather-app`)

App deployment: 1 replica, `weather-go-app:dev`, limits 500m CPU / 128Mi RAM. Redis uses a custom `redis.conf` (maxmemory 64mb, allkeys-lru) from a ConfigMap with a 1Gi PVC.

## Terraform (`terraform/main.tf`)

Provisions AWS VPC, ALB, Auto Scaling Group (t3.micro), and ElastiCache Redis (cache.t3.micro). Currently a skeleton — the EC2 user data references `weather-go-app:latest` but no image registry is wired up.
