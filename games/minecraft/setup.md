# Minecraft setup

First set up the cluster once ([README](../../README.md#setup), `make setup`). Then run every
command below in `games/minecraft/` on the k3s host; `make help <command>` explains any of them.

## 1. Passwords and admins

```sh
make init-env        # creates .env from .env.example and shows which values are set
```

- `MINECRAFT_RCON_PASSWORD`: required; backups and `make console` use it. Players never see it.
- `MINECRAFT_OPERATORS`: comma-separated player names who get admin (op) rights.
- `MINECRAFT_WHITELIST`: comma-separated player names; empty lets anyone join.
- `MINECRAFT_DISCORD_WEBHOOK`, `MINECRAFT_CONNECT_HOST`: optional Discord alerts.

## 2. Server settings

`server` in `values.override.yaml`: `motd`, `difficulty`, `mode`, `maxPlayers`, `viewDistance`,
`version` (`LATEST` or a release), and `memory`, the Java heap. Every key maps to one of the
[image's env vars](https://docker-minecraft-server.readthedocs.io/en/latest/configuration/server-properties/).

## 3. Start and join

```sh
make push-metrics-image && make deploy
make status          # the first start downloads Paper and generates the world
```

Forward TCP 25565 on the router to the host. Players add `<public address>` as a server
in Minecraft Java Edition. If the node can't fit two games, `make scale-down-zero` in the
running one first.

## 4. Commands

`make console CMD="list"` runs any server command over RCON, e.g. `CMD="op Steve"` or
`CMD="whitelist add Alex"`.

## 5. Memory and CPU

Raise `server.memory` and `resources.limits.memory` together in `values.override.yaml`,
keeping the limit about 1Gi above the heap, then `make deploy`.
`kubectl -n games describe vpa minecraft` shows the measured recommendation.

## 6. Applying changes

`values.override.yaml` and `.env`: `make deploy`. Check `make players` first: a restart
disconnects everyone.

More: [README.md](README.md) (backups, restores).
