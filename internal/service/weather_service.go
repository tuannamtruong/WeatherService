package weatherService

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"time"
)

// API client
// Provider Pattern
type WeatherClient struct {
	APIKey     string
	BaseURL    string
	HTTPClient *http.Client
}

// WeatherCondition
type WeatherCondition struct {
	DayConditions     []DayCondition     `json:"days"`
	CurrentConditions *CurrentConditions `json:"currentConditions"`
}

// Real-time weather info
type CurrentConditions struct {
	Datetime   string  `json:"datetime"`
	Temp       float64 `json:"temp"`
	FeelsLike  float64 `json:"feelslike"`
	WindSpeed  float64 `json:"windspeed"`
	WindGust   float64 `json:"windgust"`
	WindDir    float64 `json:"winddir"`
	Conditions string  `json:"conditions"`
}

// Weather data of a day
type DayCondition struct {
	Datetime       string          `json:"datetime"`
	TempMax        float64         `json:"tempmax"`
	TempMin        float64         `json:"tempmin"`
	Temp           float64         `json:"temp"`
	FeelsLikeMax   float64         `json:"feelslikemax"`
	FeelsLikeMin   float64         `json:"feelslikemin"`
	FeelsLike      float64         `json:"feelslike"`
	WindSpeed      float64         `json:"windspeed"`
	WindGust       float64         `json:"windgust"`
	WindDir        float64         `json:"winddir"`
	Conditions     string          `json:"conditions"`
	Description    string          `json:"description"`
	HourConditions []HourCondition `json:"hours"`
}

// Weather data of an hour
type HourCondition struct {
	Datetime   string  `json:"datetime"`
	Temp       float64 `json:"temp"`
	FeelsLike  float64 `json:"feelslike"`
	WindSpeed  float64 `json:"windspeed"`
	WindGust   float64 `json:"windgust"`
	WindDir    float64 `json:"winddir"`
	Conditions string  `json:"conditions"`
}

// Constructor for WeatherClient API client
func NewWeatherClient(weatherServiceApiKey string) *WeatherClient {
	return &WeatherClient{
		APIKey:  weatherServiceApiKey,
		BaseURL: "https://weather.visualcrossing.com/VisualCrossingWebServices/rest/services/timeline",
		HTTPClient: &http.Client{
			Timeout: 15 * time.Second,
		},
	}
}

// HTTP GET request to weather API
// Parameters:
// - location: city name (e.g. "Berlin,Germany", "Karlsruhe")
func (c *WeatherClient) GetWeather(location string) (*WeatherCondition, error) {
	// Build GET request
	weatherEndpoint := fmt.Sprintf("%s/%s", c.BaseURL, url.PathEscape(location))

	req, err := http.NewRequest(http.MethodGet, weatherEndpoint, nil)
	if err != nil {
		return nil, fmt.Errorf("creating request: %w", err)
	}

	query := req.URL.Query()
	query.Set("unitGroup", "metric") // use "us" for Fahrenheit / mph
	query.Set("key", c.APIKey)
	query.Set("contentType", "json")
	query.Set("include", "days,hours,current")
	req.URL.RawQuery = query.Encode()

	resp, err := c.HTTPClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("HTTP request failed: %w", err)
	}
	defer resp.Body.Close()

	// Handle response
	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("HTTP response error %d: %s", resp.StatusCode, string(body))
	}

	var weatherCondition WeatherCondition
	if err := json.NewDecoder(resp.Body).Decode(&weatherCondition); err != nil {
		return nil, fmt.Errorf("decoding response: %w", err)
	}
	return &weatherCondition, nil
}
