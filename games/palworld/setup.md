# Palworld setup

First set up the cluster once ([README](../../README.md#setup), `make setup`). Then run every
command below in `games/palworld/` on the k3s host; `make help <command>` explains any of them.

## 1. Passwords and alerts

```sh
make init-env        # creates .env from .env.example and shows which values are set
```

- `PALWORLD_ADMIN_PASSWORD`: required; admin commands in game, and the REST API the
  exporter queries.
- `PALWORLD_SERVER_PASSWORD`: the password players join with; empty lets anyone join.
- `PALWORLD_DISCORD_WEBHOOK`, `PALWORLD_CONNECT_HOST`: optional Discord alerts.

## 2. Server settings

Set these in `.env`; an empty one keeps what `values.override.yaml` says:

- `PALWORLD_SERVER_NAME`, `PALWORLD_SLOT_COUNT` (1-32).
- `PALWORLD_GAME_SETTINGS`: comma-separated world rules, each one of the image's
  `PalWorldSettings.ini` env vars, e.g. `"DIFFICULTY=Difficult,EXP_RATE=2,DEATH_PENALTY=Item"`
  ([all settings](https://github.com/thijsvanloef/palworld-server-docker#environment-variables)).

## 3. Start and join

```sh
make push-metrics-image && make deploy
make status          # the first start downloads the game; wait until the pod is ready
```

Forward UDP 8211 on the router to the host. Players join `<public address>:8211` from
the in-game community server screen, then enter the password.
If the node can't fit two games, `make scale-down-zero` in the running one first.

## 4. Mods

The chart runs the vanilla server; mod loaders are not set up.

## 5. Memory and CPU

Palworld is memory-hungry and upstream asks for far more than a small world needs.
Raise `resources.requests` (what the node reserves) and `resources.limits.memory` (the
hard cap) in `values.override.yaml`, then `make deploy`. CPU has no limit on purpose.
`kubectl -n games describe vpa palworld` shows the measured recommendation.

## 6. Applying changes

`values.override.yaml` and `.env`: `make deploy`; if only `.env` passwords changed, also
`make restart`. Check `make players` first: a restart disconnects everyone.

More: [README.md](README.md) (updates, backups, ports).
