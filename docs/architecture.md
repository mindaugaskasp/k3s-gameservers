# Architecture

A single-node k3s cluster runs three namespaces:

- `games`: one StatefulSet per game (`valheim`, `zomboid`, `enshrouded`, `minecraft`, `terraria`, `vrising`, `dragonwilds`, `palworld`)
- `monitoring`, `registry`, `crowdsec`: the platform, see [platform.md](platform.md)
- on the host: ufw lets only SSH, the LAN and pods in, routed game ports aside
  ([platform.md](platform.md)); timers copy worlds off-host nightly and verify they
  restore twice a month ([offsite-backups.md](offsite-backups.md))
- other namespaces: apps like servers-web, which only report to the platform

## Workloads

- **StatefulSets:** each game is one world, one volume, one pod.
  `helm uninstall` keeps the PVC.
- **Replicas** come from the live object (`lookup`), so `helm upgrade`
  doesn't undo a scale to 0.
- **Deploying:** `make deploy` in `games/<game>/`. Not `helm upgrade --reuse-values`: it ignores
  chart defaults added since the last deploy.
- **Secrets** (passwords, Discord webhooks) are set from env vars at deploy
  time and never committed.
- **Backups** are the image's own, or a `backup` sidecar where it has none (Minecraft, V Rising, Dragonwilds).
- **Save on stop:** V Rising's preStop saves over RCON (`save-and-stop.py`); it exits unsaved on SIGTERM.
- **Stop signal:** Dragonwilds' preStop stops the server process itself; the image's own stop never reaches it.
- **Game image:** Terraria runs `games/terraria/image`, ryshe/terraria plus curl for the shared Discord hooks.
- **World seed:** Valheim's server has no seed option; `create-seeded-world.py` writes a new world's metadata first.
- **Admin-only query:** Palworld answers no public query; its exporter asks the server's REST API with the admin password.

## Shared game pieces

`game-server/` holds what every game uses, so a new game is one `games/<game>/` folder:

- **`chart/`:** a Helm [library chart](https://helm.sh/docs/topics/library_charts/) each game's chart
  depends on: helpers, labels, VPA, the Discord secret, the status-metrics sidecar and its Service,
  generic start/stop hooks and an init container for images that run as root. Every game's hooks carry
  its `post-discord-embed.sh` and `record-uptime.sh`, so alerts and lifetime uptime work one way.
- **`make/game.mk`:** every game's shared make targets; the game Makefile sets its paths and includes it.
  `world-data.mk` holds its sync, download and restore targets; `helm-values-from-env.sh` turns `.env` into Helm flags.
- **`status-metrics/`:** the exporter's shared core ([status-metrics.md](status-metrics.md)).
- **`systemd/`, `restore-helper-pod.yaml`:** the hourly sync timer and the restore pod, one per game instance.
- **`grafana/`:** dashboards a game ships as its own unless its Makefile clears `SHARED_DASHBOARDS`.

## Networking

Game ports are NodePorts on the same numbers the router forwards ([table](../README.md#router-ports)),
which is why the NodePort range is widened ([platform.md](platform.md#k3s)).
HTTP goes through Traefik, where CrowdSec bans scanners ([crowdsec.md](crowdsec.md)).

## Monitoring

How each game reports players, stats and dashboards: [game-monitoring.md](game-monitoring.md).

## Sizing

- **No CPU limits**, to avoid
  [CFS throttling](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/#how-pods-with-resource-limits-are-run).
- **One game at a time:** if the node can't fit two games, keep their summed
  requests above allocatable so the second stays `Pending`, not OOM-killing the first.
