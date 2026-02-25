package main

import (
	"context"
	"flag"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/tuannamtruong/WeatherService/internal/api"
	"github.com/tuannamtruong/WeatherService/internal/cache"
	"github.com/tuannamtruong/WeatherService/internal/config"
	"github.com/tuannamtruong/WeatherService/internal/console"
	weatherService "github.com/tuannamtruong/WeatherService/internal/service"
)

func main() {
	log.Printf("Loading Settings")
	config := config.MustLoadConfig()

	mode := flag.String("mode", "API", "Running mode: CON or API")
	port := flag.Int("port", 8080, "Port for the API server")
	flag.Parse()
	if mode == nil {
		log.Fatalln("Required flag 'mode' is not provided")
		os.Exit(1)
	}
	if *mode == "API" && port == nil {
		log.Fatalln("Required flag 'port' is not provided for API mode")
		os.Exit(1)
	}

	// Setting up services
	weatherClient := weatherService.NewWeatherClient(config.WeatherServiceApiKey)

	// Redis
	cache, err := cache.NewCache(config.RedisUrl)
	if err != nil {
		log.Printf("Caching unavailable (%v).", err)
	} else {
		defer cache.Close()
	}

	// Run the application based on the selected mode
	switch *mode {
	case "CON":
		runAsConsoleApplication(weatherClient)
	case "API":
		runAsApiServer(weatherClient, port, cache)
	}
}

// Run the application as an API server
func runAsApiServer(weatherClient *weatherService.WeatherClient, port *int, cache *cache.Cache) {
	log.Printf("Initializing API Server")
	srv := api.InitServer(weatherClient, *port, cache)
	go func() {
		log.Printf("Weather API is running")
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Server error: %v", err)
		}
	}()

	// Graceful Shutdown
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	log.Println("Shutting down")

	// Safe Exit
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		log.Fatalf("Forced shutdown: %v", err)
	}
	log.Println("Server stopped")
}

// Run the application as a console application
func runAsConsoleApplication(weatherClient *weatherService.WeatherClient) {
	log.Printf("Running in Console Mode")
	console.GetKarlsruheWeather(weatherClient)
}
