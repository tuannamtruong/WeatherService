FROM golang:1.25-alpine AS builder

WORKDIR /app

COPY go.mod ./
RUN go mod download

COPY . .

RUN CGO_ENABLED=0 \
    go build -ldflags="-w -s" -o weather-service ./cmd/weatherApi/weather.go


FROM alpine:latest

WORKDIR /app

COPY --from=builder /app/weather-service /app/weather-service
COPY --from=builder /app/config.json /app/config.json

CMD ["./weather-service"]