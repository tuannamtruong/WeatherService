.DEFAULT_GOAL := run

.PHONY: build run dock redis

REDIS_CONTAINER_NAME := redis_db
REDIS_IMG := redis:8-alpine
MODE ?= API

# Development 
logApp:
	docker compose -f docker-compose.dev.yml logs -f weather-api-server
logCache:
	docker compose -f docker-compose.dev.yml logs -f redis-cache

build:
	go fmt ./...
	go vet ./...
	go build -buildvcs=false cmd/weatherApi/weather.go

run: 
	go run -buildvcs=false cmd/weatherApi/weather.go -mode=$(MODE)

ddock: 
	go mod tidy
	go build -buildvcs=false cmd/weatherApi/weather.go
	docker build -f dockerfile.dev -t weather-go-app:dev .
	docker run --rm -p 8085:8080 --name weather-go-app-dev weather-go-app:dev ./weather-service -mode=$(MODE) -port=8080

# !!!ONLY POSSIBLE IN BASH!!!
redis: 
	@if [ $$(docker ps -aq -f name=$(REDIS_CONTAINER_NAME)) ]; then \
		docker start $(REDIS_CONTAINER_NAME); \
	else \
		docker run -d --name $(REDIS_CONTAINER_NAME) -p 6379:6379 $(REDIS_IMG); \
	fi

up:
	docker compose -f docker-compose.dev.yml up -d

down:
	docker compose -f docker-compose.dev.yml down

# Production
pdock: build
	go mod tidy
	docker build -t weather-go-app:prod .
	docker run --rm -p 12345:8080 --name weather-go-app-prod weather-go-app:prod ./weather-service -mode=API -port=8080

produp: build 
	go mod tidy
	docker build -t weather-go-app:prod .
	docker compose -f docker-compose.yml up -d

proddown:
	docker compose -f docker-compose.yml down