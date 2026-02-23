package main

import (
	"fmt"
	"log"

	"github.com/tuannamtruong/WeatherService/internal/config"
	weatherService "github.com/tuannamtruong/WeatherService/internal/service"
)

func printCurrentConditions(loc string, cc *weatherService.CurrentConditions) {
	fmt.Printf("%-25s %s, Time: %s\n", "Location:", loc, cc.Datetime)
	fmt.Printf("%-25s %.1f °C (feels like %.1f °C)\n", "Temp: ", cc.Temp, cc.FeelsLike)
	fmt.Printf("%-25s %.1f km/h %-3s (gust %.1f km/h)\n", "Wind:", cc.WindSpeed, windDirectionLabel(cc.WindDir), cc.WindGust)
	fmt.Printf("%-25s %s", "Conditions:", cc.Conditions)
}

func windDirectionLabel(degrees float64) string {
	dirs := []string{"N", "NE", "E", "SE", "S", "SW", "W", "NW"}
	idx := int((degrees+22.5)/45) % 8
	return dirs[idx]
}

func main() {
	// If city inside cache, return result inside cache
	// else call API and store result in cache

	// Call API
	if true {
		config := config.MustLoadConfig()
		location := "Karlsruhe"
		weatherClient := weatherService.NewWeatherClient(config.WeatherServiceApiKey)
		weatherCondition, err := weatherClient.GetWeather(location)
		if err != nil {
			log.Fatalf("Failed to get weather: %v", err)
		}
		printCurrentConditions(location, weatherCondition.CurrentConditions)
	}
}
