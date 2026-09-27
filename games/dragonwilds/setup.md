# RuneScape: Dragonwilds setup

First set up the cluster once ([README](../../README.md#setup), `make setup`). Then run every
command below in `games/dragonwilds/` on the k3s host; `make help <command>` explains any of them.

## 1. Owner, world and passwords

```sh
make init-env        # creates .env from .env.example and shows which values are set
```

Required:

- `DRAGONWILDS_OWNER_ID`: the owner's player ID, shown on the game's Settings screen
  ([wiki](https://dragonwilds.runescape.wiki/w/Dedicated_Servers)).
- `DRAGONWILDS_WORLD_NAME`: the world players search for; a new name starts a new world.
- `DRAGONWILDS_ADMIN_PASSWORD`: opens the in-game server management screen.

Optional:

- `DRAGONWILDS_SERVER_PASSWORD`: the password players join with; empty lets anyone join.
- `DRAGONWILDS_SERVER_NAME`: the server browser's "Created By" column.
- `DRAGONWILDS_ADMINS`: comma-separated player IDs with admin rights.
- `DRAGONWILDS_DISCORD_WEBHOOK`, `DRAGONWILDS_CONNECT_HOST`: optional Discord alerts.

## 2. Start and join

```sh
make push-metrics-image && make deploy
make status          # the first start downloads the game; wait until the pod is ready
```

Forward UDP 7778 and 8889 on the router to the host. Players find the world by name in the
Worlds list, or use Direct connect with `<public address>:7778` (the host's LAN address on the same network).
If the node can't fit two games, `make scale-down-zero` in the running one first.

## 3. Memory and CPU

Raise `resources.requests` (what the node reserves) and `resources.limits.memory` (the
hard cap) in `values.override.yaml`, then `make deploy`. CPU has no limit on purpose.
`kubectl -n games describe vpa dragonwilds` shows the measured recommendation.

## 4. Applying changes

`values.override.yaml` and `.env`: `make deploy`, which restarts the pod when a setting changed;
if only a password changed, also `make restart`. Check `make players` first: a restart
disconnects everyone, and the server does not save on stop.

More: [README.md](README.md) (updates, backups, restores).
