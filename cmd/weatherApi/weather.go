package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
)

type Config struct {
	ApiKey string `json:"ApiKey"`
}

// Reads and parses JSON
// or terminates the process if failed
func MustLoadConfig(path string) Config {
	data, err := os.ReadFile(path)
	if err != nil {
		log.Fatalf("CRITICAL: Failed to read config file at %s: %v", path, err)
	}
	var cfg Config
	if err = json.Unmarshal(data, &cfg); err != nil {
		log.Fatalf("CRITICAL: Failed to parse config JSON: %v", err)
	}
	return cfg
}

func main() {
	// data, err := os.ReadFile("config.json")
	// if err != nil {
	// 	fmt.Println("Error reading file:", err)
	// 	return
	// }

	// Call API
	if true {
		config := MustLoadConfig("config.json")

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
