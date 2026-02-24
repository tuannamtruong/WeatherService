# WeatherService

Idea from https://roadmap.sh/projects/weather-api-wrapper-service


## Getting Started

To run as docker image:
```
make devdock MODE=$MODE$
```

To run as go program in local env
```
make run MODE=$MODE$
```

$MODE$
CON: running as console app in Docker.
API: running as API Server in Docker.

## Mode
### Console Mode
Print Karlsruhe weather to console
### API Mode
Export API at `localhost:8080/api/weather`
Parameters: `location`

## Info
Go Structure: https://github.com/golang-standards/project-layout

Weather API: https://www.visualcrossing.com/weather-api/

QueryBuilder: https://www.visualcrossing.com/weather-query-builder/

Cache: Redis
