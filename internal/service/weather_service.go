package weatherService

import (
	"fmt"
	"io"
	"log"
	"net/http"
	"time"
)

type WeatherClient struct {
	APIKey     string
	BaseURL    string
	HTTPClient *http.Client
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
func (c *WeatherClient) GetWeather() {
	// Reading weather data for city
	weatherEndpoint := fmt.Sprintf("%s", c.BaseURL)

	resp, err := http.Get(weatherEndpoint)
	if err != nil {
		log.Fatal(err)
	}
	defer resp.Body.Close()
	_, err = io.ReadAll(resp.Body)
	if err != nil {
		log.Fatal(err)
	}
	fmt.Println("Success")
	// fmt.Println(string(body))

}
