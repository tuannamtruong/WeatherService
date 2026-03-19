# WeatherService

Idea from https://roadmap.sh/projects/weather-api-wrapper-service


## Getting Started

Clone the repository to local machine.

To build the go app -> dockerize the app -> run the app as API endpoint

`make dock` 

To build the go app -> dockerize the app -> run the app as console application, which get weather information for Karlsruhe then stop

`make dock MODE=CON`

To build the go app -> dockerize the app -> run the app + redis

`make buildup`

Simple API Call in CLI for Karlsruhe.

`curl --location 'localhost:12345/api/weather?location=Karlsruhe'`

To see what happening in app

`make prodlogapp`

To see what happening in redis

`make prodlogcache`


## Mode
CON: running as console app.
API: running as API Server.

### Console Mode
Print Karlsruhe weather to console
### API Mode
Export API at `localhost:8080/api/weather`

Parameters: `location`

## Info
Weather API: https://www.visualcrossing.com/weather-api/

Weather API Query Builder: https://www.visualcrossing.com/weather-query-builder/

Cache: Redis
