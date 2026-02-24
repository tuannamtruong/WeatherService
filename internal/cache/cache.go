// Wrapper for Redis cache oprations.
package cache

import (
	"context"
	"fmt"
	"log"
	"time"

	"github.com/redis/go-redis/v9"
)

type Cache struct {
	client *redis.Client
}

// Creating new cache with Redis connection.
// Returns error if Redis is not available or the URL is invalid.
func NewCache(redisUrl string) (*Cache, error) {
	if redisUrl == "" {
		return nil, fmt.Errorf("RedisURL in configuration is not set")
	}

	parsedUrl, err := redis.ParseURL(redisUrl)
	if err != nil {
		return nil, fmt.Errorf("RedisURL in configuration is not valid: %w", err)
	}

	client := redis.NewClient(parsedUrl)
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	if err := client.Ping(ctx).Err(); err != nil {
		return nil, fmt.Errorf("Ping to redis failed: %w", err)
	}

	log.Printf("Redis connected: %s", redisUrl)
	return &Cache{client: client}, nil
}

func (c *Cache) Close() error { return c.client.Close() }
