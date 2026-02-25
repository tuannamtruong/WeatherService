.DEFAULT_GOAL := run

.PHONY: build run dock redis

REDIS_CONTAINER_NAME := redis_db
REDIS_IMG := redis:8-alpine
MODE ?= API

# Development 
## Logging
logapp:
	docker compose logs -f weather-api-server
logcache:
	docker compose logs -f redis-cache

## Dev Cycle
build:
	go fmt ./...
	go vet ./...
	go build -buildvcs=false cmd/weatherApi/weather.go

run: 
	go run -buildvcs=false cmd/weatherApi/weather.go -mode=$(MODE)

## Containerization
dock: 
	go mod tidy
	go build -buildvcs=false cmd/weatherApi/weather.go
	docker build -f dockerfile -t weather-go-app:dev .
	docker run --rm -p 8085:8080 --name weather-go-app-dev weather-go-app:dev ./weather-service -mode=$(MODE) -port=8080

# !!!ONLY POSSIBLE IN BASH!!!
redis: 
	@if [ $$(docker ps -aq -f name=$(REDIS_CONTAINER_NAME)) ]; then \
		docker start $(REDIS_CONTAINER_NAME); \
	else \
		docker run -d --name $(REDIS_CONTAINER_NAME) -p 6379:6379 $(REDIS_IMG); \
	fi


bup: build up

up:
	go mod tidy
	go build -buildvcs=false cmd/weatherApi/weather.go
	docker build -f dockerfile -t weather-go-app:dev .
	docker compose up -d

down:
	docker compose down

# Production
# produp: build 
# 	go mod tidy
# 	docker build -t weather-go-app:prod .
# 	docker run --rm -p 8085:8080 --name weather-go-app-prod weather-go-app:prod ./weather-service -mode=$(MODE) -port=8080

# proddown:
# 	docker compose -f docker-compose.prod.yml down

prodlogapp:
	docker compose -f docker-compose.prod.yml logs -f weather-api-server

prodlogcache:
	docker compose -f docker-compose.prod.yml logs -f redis-cache