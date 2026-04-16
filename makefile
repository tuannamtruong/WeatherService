.DEFAULT_GOAL := run

.PHONY: build run dock redis

REDIS_CONTAINER_NAME := redis-db
REDIS_IMG := redis:8-alpine
MODE ?= API

# Dev Cycle makes for go app
## Build/develop phase
build:
	go mod tidy
	go fmt ./...
	go vet ./...
	go build -o bin/weather-service -buildvcs=false cmd/weatherApi/weather.go 

dockbuild: build
	docker build --progress=plain -f dockerfile -t weather-go-app:dev .

kapply:
	kubectl apply -f k8s/app-namespace.yaml
	kubectl apply -f k8s/.

install: build dockbuild kapply

## Run phase
run: 
	go run -buildvcs=false cmd/weatherApi/weather.go -mode=$(MODE)

dockrun: 
	docker run --rm -p 8085:8080 --name weather-go-app-dev weather-go-app:dev ./weather-service -mode=$(MODE) -port=8080

dock: dockbuild dockrun

kpf: 
	minikube image load weather-go-app:dev
	kubectl wait --for=condition=Ready pod -l app=weather-api -n weather-app && \
	kubectl port-forward svc/weather-api -n weather-app 8080:80

# Redis
## Start redis container if it exists, otherwise create and start it
## !!!ONLY POSSIBLE IN BASH!!!
redis: 
	@if [ $$(docker ps -aq -f name=$(REDIS_CONTAINER_NAME)) ]; then \
		docker start $(REDIS_CONTAINER_NAME); \
	else \
		docker run -d --name $(REDIS_CONTAINER_NAME) -p 6379:6379 $(REDIS_IMG); \
	fi

# Docker compose

## Build go app before compose up
buildup:
	go mod tidy
	go build -o bin/weather-service -buildvcs=false cmd/weatherApi/weather.go
	docker build -f dockerfile -t weather-go-app:dev .
	docker compose up -d

down:
	docker compose down

# Logging

## Prod
prodlogapp:
	docker compose -f docker-compose.prod.yml logs -f weather-api-server

prodlogcache:
	docker compose -f docker-compose.prod.yml logs -f redis-cache

## Dev
logapp:
	docker compose logs -f weather-api-server

logcache:
	docker compose logs -f redis-cache

# Clean up
cleanup:
	kubectl delete -f k8s/.
	docker rmi weather-go-app:dev



