# AGENTS.md

This file provides guidance for agents working within this repository.

## Build & Run Commands

*   `make build`: Go mod tidy, fmt, vet, and build.
*   `make run`: Run API mode on port 8080.
*   `make run MODE=CON`: Run in console mode.
*   `make redis`: Start local Redis container.
*   `make dock`: Build and run Docker image.
*   `make buildup`: Build, Docker build, and start Docker Compose.
*   `make down`: Stop Docker Compose services.
*   `make kapply`: Apply Kubernetes manifests.
*   `make kpf`: Minikube image load and port-forward.
*   `make cleanup`: Kubernetes delete and Docker image remove.

## Key Gotchas

*   The `cache` can be `nil` if Redis is unavailable; the app runs without caching.
*   `Config.RedisUrl` is unused; the app reads `REDIS_URL` from env vars.
*   K8s injects `VISUALCROSSING_API_KEY` and `PORT` env vars, but the app reads the key from `config.json` and port from `-port` flag.
*   `make kapply` does not apply `ingress/`; apply manually.
*   No `/health` endpoint; K8s readiness probe and ALB health check are commented out/awaiting one.

## Architecture Notes

*   Standard library HTTP only (`net/http.ServeMux`).
*   Provider pattern for `WeatherClient`.
*   `cache *cache.Cache` is nil-guarded.
*   `writeJSON` helper for HTTP responses.
*   Import aliasing (`weatherService "..."`) used to avoid name collisions.
*   `go build -buildvcs=false` used in Makefile.

## Configuration

*   `config.json` (required in CWD) for `ApiKey`.
*   `REDIS_URL` env var for Redis connection.

## Docker

*   `dockerfile`: Dev multi-stage build.
*   `dockerfile.prod`: Prod multi-stage, stripped binary.

## Kubernetes (`k8s/`)

*   App deployment: 1 replica.
*   Redis: custom config, maxmemory 64mb, 1Gi PVC.

## Terraform (`terraform/main.tf`)

*   Provisions AWS VPC, ALB, ASG, ElastiCache Redis.
*   EC2 user data references `weather-go-app:latest`; registry not wired.

## Development Workflow

*   No tests (`*_test.go` files do not exist). Verification relies on build and manual checks.
*   Use `make` for all build, run, and Docker operations.
*   `config.json` must be present in the CWD for the API to run.
