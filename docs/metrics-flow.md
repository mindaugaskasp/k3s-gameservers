# How Valheim's stats reach Grafana and the website

The game server's log becomes files, the sidecar turns those files into `/metrics`, and two
readers consume that endpoint. Every game works the same way; only its plugin differs
([status-metrics.md](status-metrics.md)).

```mermaid
flowchart LR
    subgraph pod["valheim-0 pod"]
        server["gameserver container<br/>Valheim server"]
        hooks["log-filter hooks<br/>joins, deaths, raids"]
        share["status-share volume<br/>online players, deaths, raids, timestamps"]
        save["world save and backups<br/>on the game volume"]
        sidecar["status-metrics sidecar<br/>game-server core + Valheim plugin"]
        db[("valheim.db<br/>player history, raids")]
        server -- "log lines" --> hooks --> share --> sidecar
        save --> sidecar
        sidecar <--> db
    end

    metrics["valheim-metrics Service<br/>:9101/metrics"]
    sidecar --> metrics

    subgraph monitoring["monitoring namespace"]
        prometheus["Prometheus<br/>scrapes every 30s, keeps 7 days"]
        alloy["Alloy"] --> loki["Loki<br/>pod logs, 31 days"]
        grafana["Grafana dashboards<br/>process health, game stats and logs"]
        prometheus --> grafana
        loki --> grafana
    end
    metrics --> prometheus
    server -- "stdout" --> alloy

    subgraph web["webserver namespace"]
        status["game-status service<br/>read-game-stats.js"]
        site["Website<br/>stat facts per game"]
        status -- "GET /servers" --> site
    end
    metrics -- "current stats" --> status
    prometheus -- "7-day player history" --> status
    server -. "gamedig query" .-> status
```

- **Into the pod's files:** the [log-filter hooks](https://github.com/community-valheim-tools/valheim-server-docker#log-filters)
  in the chart's `lifecycle-hooks.yaml` write the status share; nothing else writes the database.
- **`/metrics`:** built fresh on each request from the files, the save and `valheim.db`
  ([player-database.md](player-database.md)). Metric names follow CLAUDE.md.
- **Grafana:** `game_server_*` and `valheim_*` from Prometheus, plus the server's own log from Loki.
- **Website:** `game-status` reads the sidecar's `/metrics` directly (`GAME_STATS_SOURCES`),
  so its stats don't wait for a scrape; each stat becomes one `StatFact`, e.g. "Day" / "77".
