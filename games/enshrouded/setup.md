# Enshrouded setup

First set up the cluster once ([README](../../README.md#setup), `make setup`). Then run every
command below in `games/enshrouded/` on the k3s host; `make help <command>` explains any of them.

## 1. Passwords and alerts

```sh
make init-env        # creates .env from .env.example and shows which values are set
```

Enshrouded has no single server password: the password a player joins with picks their role.

- `ENSHROUDED_ADMIN_PASSWORD`: required; joining with it grants the Admins role (kick, ban).
- `ENSHROUDED_FRIEND_PASSWORD`: the password to hand out to players (Friends role).
- `ENSHROUDED_DISCORD_WEBHOOK`, `ENSHROUDED_CONNECT_HOST`: optional Discord alerts.

Each role's permissions: `roles` in `values.override.yaml` ([options](https://github.com/mornedhels/enshrouded-server/blob/main/docs/SERVER_ROLES.md)).

## 2. Server settings

Set these in `.env`; an empty one keeps what `values.override.yaml` says:

- `ENSHROUDED_SERVER_NAME`, `ENSHROUDED_SLOT_COUNT` (1-16), `ENSHROUDED_TEXT_CHAT`, `ENSHROUDED_VOICE_CHAT`.
- `ENSHROUDED_DIFFICULTY`: `Default`, `Relaxed`, `Hard`, `Survival` or `Custom`.
- `ENSHROUDED_GAME_SETTINGS`: only with `Custom`, e.g. `"ENEMY_HEALTH_FACTOR=2,CURSE_MODIFIER=Off"`
  ([all settings](https://github.com/mornedhels/enshrouded-server/blob/main/docs/SERVER_DIFFICULTY.md)).

## 3. Start and join

```sh
make push-metrics-image && make deploy
make status          # the first start downloads the game; wait until the pod is ready
```

Forward UDP 15637 on the router to the host. Players find the server by name in the
browser, or join `<public address>:15637`, then enter the Friends or Admin password.
If the node can't fit two games, `make scale-down-zero` in the running one first.

## 4. Mods

Enshrouded has no server mod support, so there is nothing to install on the server.

## 5. Memory and CPU

Raise `resources.requests` (what the node reserves) and `resources.limits.memory` (the
hard cap) in `values.override.yaml`, then `make deploy`. CPU has no limit on purpose.
`kubectl -n games describe vpa enshrouded` shows the measured recommendation.

## 6. Applying changes

`values.override.yaml` and `.env`: `make deploy`; if only `.env` passwords changed, also
`make restart`. Check `make players` first: a restart disconnects everyone.

More: [README.md](README.md) (updates, backups, roles).
