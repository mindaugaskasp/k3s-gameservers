# Overview

How the game servers run and how their stats reach Grafana and the website, in one picture.
Details: [architecture.md](architecture.md), one game's full path: [metrics-flow.md](metrics-flow.md).

```mermaid
flowchart LR
    players(["Players"])
    router["Router<br/>forwards game ports"]
    players --> router

    subgraph cluster["k3s cluster (one node)"]
        subgraph games["games namespace: one pod per game"]
            subgraph pod["a game pod, e.g. valheim-0"]
                server["Game server"]
                sidecar["Stats helper (sidecar)<br/>counts players, reads saves"]
                volume[("World, backups,<br/>player history")]
                server --- volume
                volume --> sidecar
                sidecar -- "who is online? (gamedig)" --> server
            end
        end

        subgraph monitoring["monitoring namespace"]
            prometheus["Prometheus<br/>collects the numbers"]
            loki["Loki<br/>collects the logs"]
            grafana["Grafana<br/>one folder per game"]
            prometheus --> grafana
            loki --> grafana
        end

        subgraph webserver["webserver namespace"]
            gamestatus["game-status service<br/>polls every source on a timer"]
            website["Website (nginx + Laravel)<br/>server cards and stats"]
            gamestatus -- "/servers snapshot" --> website
        end
    end

    router --> server
    sidecar -- "/metrics" --> prometheus
    sidecar -- "/metrics" --> gamestatus
    gamestatus -. "who is online? (gamedig)" .-> server
    prometheus -- "7-day player history" --> gamestatus
    server -- "logs" --> loki
    grafana -- "alerts" --> discord(["Discord"])
    server -- "started / stopped" --> discord
    volume -. "copies off the host" .-> offsite(["Off-host backup"])
```

- **Game server:** a ready-made image, one per game; the world lives on the pod's volume.
- **Stats helper:** the same core for every game plus a small per-game plugin
  ([status-metrics.md](status-metrics.md)); it serves everything it knows at `/metrics`.
- **Grafana and alerts:** reads Prometheus and Loki; alerts post to Discord
  ([game-monitoring.md](game-monitoring.md)).
- **Website:** a separate game-status service collects everything: each helper's `/metrics`, a gamedig
  query to each server and a week of player history from Prometheus. The site reads only its `/servers` snapshot.
