.DEFAULT_GOAL := run

.PHONY:fmt vet build run


fmt:
		go fmt ./...

vet: fmt
		go vet ./...

build: vet
		go build -buildvcs=false cmd/weatherApi/weather.go

run: 
		go run -buildvcs=false cmd/weatherApi/weather.go