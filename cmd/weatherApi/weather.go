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
		printWeatherForcast(weatherCondition.DayConditions)
		printHourlyBreakdown(weatherCondition.DayConditions[0])
	}
}
