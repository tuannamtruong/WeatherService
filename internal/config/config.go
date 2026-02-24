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

// Reads and parses config file "config.json"
// or terminates the process if failed
func MustLoadConfig() Config {
	configFile := "config.json"
	data, err := os.ReadFile(configFile)
	if err != nil {
		log.Fatalf("CRITICAL: Failed to read config file at %s: %v", configFile, err)
	}
	var cfg Config
	if err = json.Unmarshal(data, &cfg); err != nil {
		log.Fatalf("CRITICAL: Failed to parse config JSON: %v", err)
	}
	return cfg
}
