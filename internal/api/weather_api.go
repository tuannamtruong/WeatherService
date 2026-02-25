// API Server handling incoming HTTP requests and returning weather data in JSON format
package api

import (
	"encoding/json"
	"log"
	"net"
	"net/http"
	"strconv"
	"time"

	"github.com/tuannamtruong/WeatherService/internal/cache"
	weatherService "github.com/tuannamtruong/WeatherService/internal/service"
)

type Server struct {
	weatherService *weatherService.WeatherClient
	httpHandler    *http.ServeMux
	cache          *cache.Cache
}

type APIResponse struct {
	Success     bool   `json:"success"`
	Message     string `json:"message"`
	Description string `json:"description"`
	Details     any    `json:"details"`
}

// ServeHTTP lets Server satisfy http.Handler
// Applies logging middleware.
func (s *Server) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	timeStamp := time.Now()
	s.httpHandler.ServeHTTP(w, r)
	log.Printf("%s %s %s", r.Method, r.URL.Path, time.Since(timeStamp))
}

func (s *Server) routes() {
	log.Println("Setting up routes")
	s.httpHandler.HandleFunc("/api/weather", s.handleWeather)
	s.httpHandler.HandleFunc("/api/pingRedis", s.ping)
}

// Get the query from the Url request.
func parseQuery(r *http.Request) (location string) {
	location = r.URL.Query().Get("location")
	if location == "" {
		return "Karlsruhe"
	}
	return location
}

func (s *Server) handleWeather(w http.ResponseWriter, r *http.Request) {
	// Parse request
	if r.Method != http.MethodGet {
		writeJSON(w, http.StatusMethodNotAllowed, APIResponse{Message: "method not allowed"})
		return
	}
	location := parseQuery(r)
	ctx := r.Context()
	var weatherCondition *weatherService.WeatherCondition

	// Cache lookup
	if s.cache != nil {
		rawCache, err := s.cache.Get(ctx, location)
		if err != nil {
			log.Printf("Cache miss for '%s'.", location)
		} else if jsonErr := json.Unmarshal(rawCache, &weatherCondition); jsonErr == nil {
			log.Printf("Cache hit for '%s'.", location)
			writeJSON(w, http.StatusOK, APIResponse{
				Success: true,
				Message: "Cached weather data for " + location,
				Details: weatherCondition})
			return
		}
	}

	// Get weather data from the weather service
	weatherCondition, err := s.weatherService.GetWeather(location)
	if err != nil {
		log.Printf("HTTP request failed: %v", err)
		writeJSON(w, http.StatusBadGateway, APIResponse{Success: false, Message: "Failed to get weather for" + location, Description: err.Error()})
		return
	}

	// Cache the result
	if s.cache != nil {
		if rawCache, jsonErr := json.Marshal(weatherCondition); jsonErr == nil {
			if err := s.cache.Set(ctx, location, rawCache); err != nil {
				log.Printf("Cache write error: %v", err)
			}
			log.Printf("Cache saved for '%s'", location)
		}
	}

	writeJSON(w, http.StatusOK, APIResponse{
		Success: true,
		Message: "Weather data for " + location,
		Details: weatherCondition})
}

func InitServer(weatherService *weatherService.WeatherClient, port int, cache *cache.Cache) *http.Server {
	s := &Server{
		weatherService: weatherService,
		httpHandler:    http.NewServeMux(),
		cache:          cache,
	}
	s.routes()

	srv := &http.Server{
		Addr:         ":" + strconv.Itoa(port),
		Handler:      s,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 30 * time.Second,
		IdleTimeout:  60 * time.Second,
	}
	return srv
}

// writeJSON sends a JSON-encoded body with the given status code.
func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(v)
}

// writeJSON sends a JSON-encoded body with the given status code.
func (s *Server) ping(w http.ResponseWriter, r *http.Request) {
	log.Printf("PING")
	var d net.Dialer
	// DialContext respects the timeout/cancellation from your ctx
	conn, err := d.DialContext(r.Context(), "tcp", "127.0.0.1:6379")
	if err != nil {
		writeJSON(w, http.StatusServiceUnavailable, APIResponse{
			Success:     false,
			Message:     "Redis ping failed",
			Description: err.Error(),
		})
		return
	}
	defer conn.Close()

	writeJSON(w, http.StatusOK, APIResponse{
		Success: true,
		Message: "PONG",
		Details: ""})
}
