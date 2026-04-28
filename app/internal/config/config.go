package config

import (
	"encoding/json"
	"log"
	"os"
)

// Configuration for the applciation.
type Config struct {
	WeatherServiceApiKey string `json:"ApiKey"`
	RedisUrl             string `json:"RedisURL"`
}

// MustLoadConfig loads config from environment first, then falls back to config.json.
func MustLoadConfig() Config {
	if apiKey := os.Getenv("VISUALCROSSING_API_KEY"); apiKey != "" {
		return Config{WeatherServiceApiKey: apiKey}
	}

	configFiles := []string{"config.json", "../config.json"}
	for _, configFile := range configFiles {
		data, err := os.ReadFile(configFile)
		if err != nil {
			continue
		}

		var cfg Config
		if err = json.Unmarshal(data, &cfg); err != nil {
			log.Fatalf("CRITICAL: Failed to parse config JSON: %v", err)
		}
		return cfg
	}

	log.Fatalf("CRITICAL: Missing VISUALCROSSING_API_KEY and no readable config.json found")
	return Config{}
}
