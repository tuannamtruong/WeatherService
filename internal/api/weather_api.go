// API Server handling incoming HTTP requests and returning weather data in JSON format
package api

import (
	"encoding/json"
	"log"
	"net/http"
	"time"

	weatherService "github.com/tuannamtruong/WeatherService/internal/service"
)

type Server struct {
	client *weatherService.WeatherClient
	mux    *http.ServeMux
}

type APIResponse struct {
	Success     bool   `json:"success"`
	Message     string `json:"message"`
	Description string `json:"description"`
	Details     any    `json:"details"`
}

// ServeHTTP lets Server satisfy http.Handler; applies logging middleware.
func (s *Server) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	timeStamp := time.Now()
	s.mux.ServeHTTP(w, r)
	log.Printf("%s %s %s", r.Method, r.URL.Path, time.Since(timeStamp))
}

// writeJSON sends a JSON-encoded body with the given status code.
func writeJSON(w http.ResponseWriter, status int, v interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(v)
}

func (s *Server) routes() {
	s.mux.HandleFunc("/api/weather", s.handleWeather)
}

func parseQuery(r *http.Request) (location string) {
	location = r.URL.Query().Get("location")
	if location == "" {
		return "Karlsruhe"
	}
	return location
}

func (s *Server) handleWeather(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeJSON(w, http.StatusMethodNotAllowed, APIResponse{Message: "method not allowed"})
		return
	}
	location := parseQuery(r)
	weatherCondition, err := s.client.GetWeather(location)
	if err != nil {
		log.Printf("HTTP request failed: %w", err)
		writeJSON(w, http.StatusBadGateway, APIResponse{Success: false, Message: "Failed to get weather for" + location, Description: err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, APIResponse{
		Success: true,
		Message: "Weather data for " + location,
		Details: weatherCondition})
}

func InitServer(client *weatherService.WeatherClient) *http.Server {
	s := &Server{client: client, mux: http.NewServeMux()}
	s.routes()

	srv := &http.Server{
		Addr:         ":8080",
		Handler:      s,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 30 * time.Second,
		IdleTimeout:  60 * time.Second,
	}
	return srv
}
