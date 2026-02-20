package main

import (
	"fmt"
	"io"
	"log"
	"net/http"

	"github.com/tuannamtruong/WeatherService/internal/config"
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

		// Reading weather data for city
		weatherEndpoint := fmt.Sprintf("https://weather.visualcrossing.com/VisualCrossingWebServices/rest/services/timeline/Karlsruhe?unitGroup=metric&key=%s&contentType=json", config.ApiKey)

		resp, err := http.Get(weatherEndpoint)
		if err != nil {
			log.Fatal(err)
		}
		defer resp.Body.Close()
		body, err := io.ReadAll(resp.Body)
		if err != nil {
			log.Fatal(err)
		}

		fmt.Println(string(body))

	}
}
