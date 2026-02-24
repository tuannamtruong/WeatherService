package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/tuannamtruong/WeatherService/internal/api"
	"github.com/tuannamtruong/WeatherService/internal/config"
	weatherService "github.com/tuannamtruong/WeatherService/internal/service"
)

func printCurrentConditions(loc string, cc *weatherService.CurrentConditions) {
	fmt.Printf("%-25s %s, Time: %s\n", "Location:", loc, cc.Datetime)
	fmt.Printf("%-25s %.1f °C (feels like %.1f °C)\n", "Temp: ", cc.Temp, cc.FeelsLike)
	fmt.Printf("%-25s %.1f km/h %-3s (gust %.1f km/h)\n", "Wind:", cc.WindSpeed, windDirectionLabel(cc.WindDir), cc.WindGust)
	fmt.Printf("%-25s %s\n", "Conditions:", cc.Conditions)
	fmt.Println()
}

func printWeatherForcast(days []weatherService.DayCondition) {
	fmt.Println("Forecast for the next 7 days:")
	fmt.Printf("%-12s %-8s %-8s %-8s %-10s %-10s %-6s  %s\n",
		"Date", "Min°C", "Max°C", "Avg°C", "Wind km/h", "Gust km/h", "Dir", "Conditions")
	for _, d := range days {
		fmt.Printf("%-12s %-8.1f %-8.1f %-8.1f %-10.1f %-10.1f %-6s  %s\n",
			d.Datetime,
			d.TempMin, d.TempMax, d.Temp,
			d.WindSpeed, d.WindGust,
			windDirectionLabel(d.WindDir),
			d.Conditions,
		)
	}
	fmt.Println()
}

func printHourlyBreakdown(day weatherService.DayCondition) {
	fmt.Printf("Hourly breakdown for %s\n", day.Datetime)
	fmt.Printf("%-8s %-8s %-10s %-10s %-10s %-6s  %s\n",
		"Hour", "Temp°C", "Feels°C", "Wind km/h", "Gust km/h", "Dir", "Conditions")
	for _, h := range day.HourConditions {
		fmt.Printf("%-8s %-8.1f %-10.1f %-10.1f %-10.1f %-6s  %s\n",
			h.Datetime, h.Temp, h.FeelsLike,
			h.WindSpeed, h.WindGust,
			windDirectionLabel(h.WindDir),
			h.Conditions,
		)
	}
	fmt.Println()
}

func windDirectionLabel(degrees float64) string {
	dirs := []string{"N", "NE", "E", "SE", "S", "SW", "W", "NW"}
	idx := int((degrees+22.5)/45) % 8
	return dirs[idx]
}

func main() {
	log.Printf("Loading Config")
	config := config.MustLoadConfig()
	weatherClient := weatherService.NewWeatherClient(config.WeatherServiceApiKey)

	// location := "Karlsruhe"
	// weatherCondition, err := weatherClient.GetWeather(location)
	// if err != nil {
	// 	log.Fatalf("Failed to get weather: %v", err)
	// }
	// printCurrentConditions(location, weatherCondition.CurrentConditions)
	// printWeatherForcast(weatherCondition.DayConditions)
	// printHourlyBreakdown(weatherCondition.DayConditions[0])

	log.Printf("Initializing Server")
	srv := api.InitServer(weatherClient)
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
