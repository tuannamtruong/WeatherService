package main

import (
	"github.com/tuannamtruong/WeatherService/internal/config"
	weatherService "github.com/tuannamtruong/WeatherService/internal/service"
)

func main() {
	// data, err := os.ReadFile("config.json")
	// if err != nil {
	// 	fmt.Println("Error reading file:", err)
	// 	return
	// }

	// If city inside cache, return result inside cache
	// else call API and store result in cache

	// Call API
	if true {
		config := config.MustLoadConfig()

		weatherClient := weatherService.NewWeatherClient(config.WeatherServiceApiKey)
		weatherClient.GetWeather()
		//weatherService.GetWeather(config.WeatherServiceApiKey)
	}
}
