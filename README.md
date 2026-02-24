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

Go Miscs.:
- Accept interfaces, return structs. Implicit interfaces.  https://medium.com/@cep21/preemptive-interface-anti-pattern-in-go-54c18ac0668a
- Learning Go (2nd Ed) - Jon Bodner
- Syntax https://gobyexample.com/
- Go Env, module, ver: https://go.dev/doc/
- STD: https://pkg.go.dev/fmt@go1.26.0
- TBD
    - Diagnose: https://100go.co/
    - Let's Go Further! - Alex Edwards

Weather API: https://www.visualcrossing.com/weather-api/

Weather API Query Builder: https://www.visualcrossing.com/weather-query-builder/

Cache: Redis
