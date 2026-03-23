# WeatherService

Idea from https://roadmap.sh/projects/weather-api-wrapper-service


## Getting Started

### Requirements

Clone the repository to local machine.

Docker, kubectl, minikube installed.

### To build the app

To build the go app

`make build` 

To build the go app -> dockerize the app

`make dock` 

To build the go app -> dockerize the app -> apply k8s infrastructure

`make install` 

### To run the app
>As go application in host system

`make run` 

>With Docker 

run the app as console application, which get weather information for Karlsruhe then stop

`make dock MODE=CON`

run the app as API server

`make dockrun` 

run the app as API server + cache (docker compose on port 8085)

`make buildup`

>With K8s

To apply infrastructure and port forward locally on port 8080

`make kpf`

### To clean up 

Remove docker image of the app
Remove all k8s applied

`make cleanup`

## While the app is running

Simple API Call in CLI for Karlsruhe.

`curl --location 'localhost:12345/api/weather?location=Karlsruhe'`

To see what happening in app

`make prodlogapp`

To see what happening in redis

`make prodlogcache`

## Running Modes
CON: running as console app.

API: running as API Server.

### Console Mode
Print Karlsruhe weather to console
### API Mode
Expose API at `localhost:8080/api/weather`

Parameters: `location`

## Info
Weather API: https://www.visualcrossing.com/weather-api/

Weather API Query Builder: https://www.visualcrossing.com/weather-query-builder/

Cache: Redis
