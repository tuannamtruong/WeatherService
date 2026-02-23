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
	docker build -f dockerfile.dev -t weather-go-app-dev .
	docker run --rm weather-go-app-dev

dock:
	go mod tidy
	go build -buildvcs=false cmd/weatherApi/weather.go
	docker build -t weather-go-app .