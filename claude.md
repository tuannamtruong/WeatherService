# WeatherService — Codebase Reference

Go HTTP API that proxies the Visual Crossing Weather API with a Redis caching layer.
Inspired by [roadmap.sh/projects/weather-api-wrapper-service](https://roadmap.sh/projects/weather-api-wrapper-service).

---

## Architecture

```
cmd/weatherApi/weather.go       Entry point: flag parsing, wiring, graceful shutdown
        │
        ├── internal/config/    Reads config.json → Config struct (MustLoad pattern)
        ├── internal/service/   WeatherClient: calls Visual Crossing REST API
        ├── internal/cache/     Redis wrapper: Get / Set / Ping / Close
        ├── internal/api/       HTTP server, route registration, all handlers, middleware
        └── internal/console/   Console mode: prints formatted weather tables to stdout
```

**Two runtime modes** (set via `-mode` flag):
- `API` (default) — HTTP server with Redis caching
- `CON` — one-shot console output for Karlsruhe, then exits

**Request flow (API mode):**
```
HTTP request → ServeHTTP (logging middleware) → handler
  → Redis cache lookup
      HIT:  return cached JSON immediately
      MISS: call Visual Crossing API → cache result (30s TTL) → return JSON
```

---

## API Endpoints

All responses use the `APIResponse` envelope:
```json
{ "success": bool, "message": "...", "description": "...", "details": <payload> }
```

### `GET /api/weather`
Returns full weather data for a location.

| | |
|---|---|
| Query param | `location` (string, default `"Karlsruhe"`) |
| Cached | Yes — Redis, key = location string, TTL = 30s |

```json
{
  "success": true,
  "message": "Weather data for Karlsruhe",
  "details": {
    "days": [ ...DayCondition... ],
    "currentConditions": { ...CurrentConditions... }
  }
}
```

| Status | Condition |
|---|---|
| `405` | Non-GET request |
| `502` | Upstream API failure |

---

### `GET /api/weather/windspeed`
Returns wind-only data (current + daily breakdown) for a location.

| | |
|---|---|
| Query param | `location` (string, default `"Karlsruhe"`) |
| Cached | Yes — same Redis key space as `/api/weather` |

```json
{
  "success": true,
  "message": "Wind speed data for Karlsruhe",
  "details": {
    "location": "Karlsruhe",
    "currentWindspeed": 3.2,
    "currentWindgust": 11.2,
    "currentWinddir": 180.0,
    "dailyWindspeed": [
      { "date": "2026-02-19", "windspeed": 14.8, "windgust": 37.1, "winddir": 220.0 }
    ]
  }
}
```

| Status | Condition |
|---|---|
| `405` | Non-GET request |
| `502` | Upstream API failure |

---

### `GET /api/pingRedis`
TCP connectivity probe for Redis. Re-reads `REDIS_URL` env var on each call.

```json
{ "success": true, "message": "PONG", "details": "" }
```

| Status | Condition |
|---|---|
| `503` | `REDIS_URL` missing or unparseable |
| `503` | TCP dial to Redis address fails |

---

## Data Models

### `weatherService.WeatherCondition`
```go
type WeatherCondition struct {
    DayConditions     []DayCondition     `json:"days"`
    CurrentConditions *CurrentConditions `json:"currentConditions"`
}
```

### `weatherService.CurrentConditions`
```go
type CurrentConditions struct {
    Datetime   string  `json:"datetime"`
    Temp       float64 `json:"temp"`
    FeelsLike  float64 `json:"feelslike"`
    WindSpeed  float64 `json:"windspeed"`
    WindGust   float64 `json:"windgust"`
    WindDir    float64 `json:"winddir"`
    Conditions string  `json:"conditions"`
}
```

### `weatherService.DayCondition`
```go
type DayCondition struct {
    Datetime       string          `json:"datetime"`
    TempMax        float64         `json:"tempmax"`
    TempMin        float64         `json:"tempmin"`
    Temp           float64         `json:"temp"`
    FeelsLikeMax   float64         `json:"feelslikemax"`
    FeelsLikeMin   float64         `json:"feelslikemin"`
    FeelsLike      float64         `json:"feelslike"`
    WindSpeed      float64         `json:"windspeed"`
    WindGust       float64         `json:"windgust"`
    WindDir        float64         `json:"winddir"`
    Conditions     string          `json:"conditions"`
    Description    string          `json:"description"`
    HourConditions []HourCondition `json:"hours"`
}
```

### `weatherService.HourCondition`
```go
type HourCondition struct {
    Datetime   string  `json:"datetime"`
    Temp       float64 `json:"temp"`
    FeelsLike  float64 `json:"feelslike"`
    WindSpeed  float64 `json:"windspeed"`
    WindGust   float64 `json:"windgust"`
    WindDir    float64 `json:"winddir"`
    Conditions string  `json:"conditions"`
}
```

### `api.WindSpeedEntry` / `api.WindSpeedResponse`
```go
type WindSpeedEntry struct {
    Date      string  `json:"date"`
    WindSpeed float64 `json:"windspeed"`
    WindGust  float64 `json:"windgust"`
    WindDir   float64 `json:"winddir"`
}

type WindSpeedResponse struct {
    Location         string           `json:"location"`
    CurrentWindSpeed float64          `json:"currentWindspeed"`
    CurrentWindGust  float64          `json:"currentWindgust"`
    CurrentWindDir   float64          `json:"currentWinddir"`
    DailyWindSpeed   []WindSpeedEntry `json:"dailyWindspeed"`
}
```

**Fields present in the upstream API but not yet modeled (silently dropped):**
`humidity`, `precip`, `precipprob`, `precipcover`, `preciptype`, `dew`, `snow`, `snowdepth`

---

## Configuration

### `config.json` (required, in working directory)
```json
{ "ApiKey": "..." }
```
Loaded at startup via `MustLoadConfig()` — process exits if missing or malformed.

### Environment Variables
| Variable | Used by | Description |
|---|---|---|
| `REDIS_URL` | `weather.go`, `weather_api.go` | Full Redis URL (e.g. `redis://redis-cache:6379`). Missing = caching disabled (non-fatal). |

### CLI Flags
| Flag | Default | Description |
|---|---|---|
| `-mode` | `API` | Runtime mode: `API` or `CON` |
| `-port` | `8080` | HTTP server port (API mode only) |

### Timeouts
| Setting | Value |
|---|---|
| HTTP server `ReadTimeout` | 10s |
| HTTP server `WriteTimeout` | 30s |
| HTTP server `IdleTimeout` | 60s |
| Visual Crossing HTTP client | 15s |
| Graceful shutdown window | 10s |
| Redis startup ping | 3s |

---

## Cache

| Property | Value |
|---|---|
| Backend | Redis via `github.com/redis/go-redis/v9` |
| TTL | 30 seconds (hardcoded `cacheTTL` constant) |
| Key | Raw `location` query param string |
| Value | `json.Marshal`-ed `WeatherCondition` |
| Cache unavailable | `cache` field is `nil`; all usages nil-guarded; app runs without caching |
| Cross-handler sharing | `/api/weather` and `/api/weather/windspeed` share the same key space |

---

## Build & Run

```bash
make build       # go mod tidy + fmt + vet + build
make run         # go run (API mode, port 8080)
make run MODE=CON  # console mode

make dock        # docker build + docker run (port 8085 → 8080)
make buildup     # build + docker build + docker compose up -d
make down        # docker compose down

make redis       # start or create local redis-db container

make kapply      # kubectl apply all k8s manifests
make kpf         # minikube image load + port-forward 8080:80
make cleanup     # kubectl delete + docker rmi
```

Dev compose maps host port **12345 → 8080**. Prod compose exposes 8080 with no host binding.

---

## Docker

| File | Purpose |
|---|---|
| `dockerfile` | Dev — multi-stage with BuildKit cache mounts for fast rebuilds |
| `dockerfile.prod` | Prod — multi-stage, `CGO_ENABLED=0`, `-ldflags="-w -s"` stripped binary |

Both copy `config.json` into the image (contains the API key — see Known Issues).

---

## Kubernetes (`k8s/`)

Namespace: `weather-app`

| Manifest | Kind | Notes |
|---|---|---|
| `app-deployment.yaml` | Deployment | 1 replica, image `weather-go-app:dev`, port 8080. Readiness probe commented out. |
| `app-svc.yaml` | Service | ClusterIP, port 80 → 8080 |
| `app-config-map.yaml` | ConfigMap | `PORT=8080`, `REDIS_URL=redis://redis.weather.svc.cluster.local:6379` |
| `app-secret.yaml` | Secret | `VISUALCROSSING_API_KEY` (stringData, not base64) |
| `redis-deployment.yaml` | Deployment | `redis:8-alpine`, custom `redis.conf`, readiness probe |
| `redis-svc.yaml` | Service | ClusterIP, port 6379 |
| `redis-config-map.yaml` | ConfigMap | maxmemory 64mb, allkeys-lru, RDB persistence |
| `redis-pvc.yaml` | PVC | ReadWriteOnce, 1Gi |
| `ingress/ingress.yaml` | Ingress | Contour, routes `/` → `weather-api:80`. **Not applied by `make kapply`** — must apply manually. |

App resource limits: requests 50m CPU / 32Mi RAM, limits 500m CPU / 128Mi RAM.

---

## Known Issues & TODOs

| # | Issue |
|---|---|
| 1 | **No tests** — zero `*_test.go` files in the project |
| 2 | **API key committed in plaintext** — `config.json` is not in `.gitignore` (the entry is commented out); key is baked into Docker images |
| 3 | **`VISUALCROSSING_API_KEY` env var injected by K8s but never read** — app reads key from `config.json` only |
| 4 | **`PORT` env var injected by K8s ConfigMap but never read** — app uses `-port` CLI flag |
| 5 | **`Config.RedisUrl` field is dead** — struct field exists, `config.json` never sets it, app uses `REDIS_URL` env var |
| 6 | **No `/health` endpoint** — K8s readiness probe is commented out waiting for this |
| 7 | **Missing upstream fields** — `humidity`, `precip`, `precipprob`, `dew`, `snow`, etc. not modeled |
| 8 | **Console mode has no caching** — always hits the upstream API |
| 9 | **`ingress/` not applied by `make kapply`** — subdirectory not traversed by `kubectl apply -f k8s/.` |
| 10 | **`pingRedis` handler has no method guard** — accepts any HTTP method |
| 11 | **Terraform is a skeleton** — provisions a bare EC2 instance with no application deployment wired in |

---

## Code Conventions

- **Standard library HTTP only** — no Gin, Chi, Echo, or other routers; uses `net/http.ServeMux`
- **Provider pattern** for the weather client (`NewWeatherClient(apiKey)`)
- **`MustLoad*` constructor** for config — `log.Fatalf` on failure (appropriate for startup)
- **Nil-guarded optional dependency** — `cache *cache.Cache` is nil when Redis is unavailable; all usages guarded with `if s.cache != nil`
- **Logging middleware** — `ServeHTTP` wraps the mux, logs `METHOD /path duration` for every request
- **`writeJSON` helper** — sets `Content-Type`, status code, and encodes body in one call
- **Error wrapping** — `fmt.Errorf("context: %w", err)` used throughout `internal/service/`
- **`url.PathEscape`** — location is path-escaped before appending to the base URL
- **Import aliasing** — `weatherService "github.com/.../internal/service"` to avoid name collisions
- **`go build -buildvcs=false`** in makefile — suppresses VCS stamping errors in CI/Docker contexts
