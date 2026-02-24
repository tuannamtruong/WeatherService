.DEFAULT_GOAL := run

.PHONY:fmt vet build run dock


fmt:
	go fmt ./...

vet: fmt
	go vet ./...

build: vet
	go build -buildvcs=false cmd/weatherApi/weather.go

run: 
	go run -buildvcs=false cmd/weatherApi/weather.go

devdock: 
	go mod tidy
	go build -buildvcs=false cmd/weatherApi/weather.go
	docker build -f dockerfile.dev -t weather-go-app:dev .
	docker run --rm -p 8085:8080 --name weather-go-app-dev weather-go-app:dev ./weather-service -mode=dev


dock: build
	go mod tidy
	docker build -t weather-go-app .