// Wrapper for Redis cache oprations.
// Also handle "statistic" for caching.

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

const cacheTTL = 30 * time.Second

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

func (cache *Cache) Ping(ctx context.Context) error {
	return cache.client.Ping(ctx).Err()
}

func (cache *Cache) Get(ctx context.Context, key string) ([]byte, error) {
	value, err := cache.client.Get(ctx, key).Bytes()
	if err != nil {
		return nil, err
	}
	return value, nil
}

func (cache *Cache) Set(ctx context.Context, key string, value []byte) error {
	if err := cache.client.Set(ctx, key, value, cacheTTL).Err(); err != nil {
		return err
	}
	return nil
}

func (cache *Cache) Close() error { return cache.client.Close() }
