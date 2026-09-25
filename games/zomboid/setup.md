# Project Zomboid setup

First set up the cluster once ([README](../../README.md#setup), `make setup`). Then run every
command below in `games/zomboid/` on the k3s host; `make help <command>` explains any of them.

## 1. Passwords and alerts

```sh
make init-env        # creates .env from .env.example and shows which values are set
```

Edit `.env`: `ZOMBOID_ADMIN_PASSWORD` and `ZOMBOID_RCON_PASSWORD` (required; the admin logs in
as `server.adminUsername` with the admin password), `ZOMBOID_SERVER_PASSWORD` (join password,
empty = open), and optionally `ZOMBOID_DISCORD_WEBHOOK`, `ZOMBOID_CONNECT_HOST` for alerts.

## 2. Server settings

In `values.override.yaml`: `server.displayName`, `server.pvp`, `server.maxPlayers`,
`server.public`, and `server.saveWorldEveryMinutes` (default 10). `server.name` is the save
name: changing it starts a **new** world.

Sandbox rules (zombie count, day length, loot): [sandbox-settings.md](sandbox-settings.md).

## 3. Start and join

```sh
make push-metrics-image && make deploy
make logs            # wait for "SERVER STARTED"
```

Forward UDP 16261-16262 on the router to the host. Players join `<public address>:16261`.
If the node can't fit two games, `make scale-down-zero` in the running one first.

## 4. Mods (Steam Workshop)

```sh
make add-mod WORKSHOP_ID=2169435993   # the number at the end of the Workshop page URL
make mods                             # list, with on/off
make disable-mod WORKSHOP_ID=...      # or enable-mod / remove-mod
make deploy                           # applies the list; restarts the server
```

`add-mod` reads the Mod ID from the Workshop page; if it names none, add `MOD_ID=<id>`.

## 5. Memory and CPU

`server.memoryXmxGb` is the game's Java heap. The container uses about heap + 1-2 GB, so
keep `resources.requests.memory` and `resources.limits.memory` above that. More CPU:
raise `resources.requests.cpu` (there is no CPU limit). Then `make deploy`.

## 6. Applying changes

`values.override.yaml` and mods: `make deploy`. `.env`: `make deploy`, then `make restart`.
Check `make players` first: a restart disconnects everyone.

More: [docs/zomboid.md](../../docs/zomboid.md) (backups, updates, RCON).
