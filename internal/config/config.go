package config

import (
	"encoding/json"
	"log"
	"os"
)

type Config struct {
	ApiKey string `json:"ApiKey"`
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
