.DEFAULT_GOAL := run

.PHONY:fmt vet build run dock


fmt:
	go fmt ./...

vet: fmt
	go vet ./...

build: vet
	go build -buildvcs=false cmd/weatherApi/weather.go

run: 
	go run -buildvcs=false cmd/weatherApi/weather.go -mode=$(MODE)

ddock: 
	go mod tidy
	go build -buildvcs=false cmd/weatherApi/weather.go
	docker build -f dockerfile.dev -t weather-go-app:dev .
	docker run --rm -p 8085:8080 --name weather-go-app-dev weather-go-app:dev ./weather-service -mode=$(MODE) -port=8080

pdock: build
	go mod tidy
	docker build -t weather-go-app:prod .
	docker run --rm -p 12345:8080 --name weather-go-app-prod weather-go-app:prod ./weather-service -mode=API -port=8080

dock: build
	go mod tidy
	docker build -t weather-go-app:prod .