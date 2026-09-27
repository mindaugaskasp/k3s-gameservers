# V Rising setup

First set up the cluster once ([README](../../README.md#setup), `make setup`). Then run every
command below in `games/vrising/` on the k3s host; `make help <command>` explains any of them.

## 1. Password, admins and alerts

```sh
make init-env        # creates .env from .env.example and shows which values are set
```

Every value is optional:

- `VRISING_SERVER_PASSWORD`: the password players join with; empty lets anyone join.
- `VRISING_ADMIN_STEAM_IDS`: comma-separated SteamID64s; those players enable the console
  in the game's options, press `~` and type `adminauth`.
- `VRISING_DISCORD_WEBHOOK`, `VRISING_CONNECT_HOST`: optional Discord alerts.

## 2. Server settings

Set these in `.env`; an empty one keeps what `values.override.yaml` says:

- `VRISING_SERVER_NAME`, `VRISING_DESCRIPTION`, `VRISING_MAX_PLAYERS`.
- `VRISING_GAME_MODE`: `PvE` or `PvP`.
- `VRISING_DIFFICULTY`: `Difficulty_Easy`, `Difficulty_Normal` or `Difficulty_Brutal`.
- `VRISING_GAME_SETTINGS`: any `ServerGameSettings.json` key, `__` between nested keys, e.g.
  `"ClanSize=2,MaterialYieldModifier_Global=2,UnitStatModifiers_Global__MaxHealthModifier=1.5"`
  ([all settings](https://github.com/StunlockStudios/vrising-dedicated-server-instructions/blob/master/1.1.x-pc/INSTRUCTIONS.md)).
  A misspelled key is skipped, and the start log says so (`make logs`).

## 3. Start and join

```sh
make push-metrics-image && make deploy
make status          # the first start downloads the game; wait until the pod is ready
```

Forward UDP 9876 and 9877 on the router to the host. Players find the server by name in the
in-game browser, or use Direct Connect with `<public address>:9876`.
If the node can't fit two games, `make scale-down-zero` in the running one first.

## 4. Memory and CPU

Raise `resources.requests` (what the node reserves) and `resources.limits.memory` (the
hard cap) in `values.override.yaml`, then `make deploy`. CPU has no limit on purpose.
`kubectl -n games describe vpa vrising` shows the measured recommendation.

## 5. Applying changes

`values.override.yaml` and `.env`: `make deploy`, which restarts the pod when a setting changed;
if only the password changed, also `make restart`. Check `make players` first: a restart
disconnects everyone.

More: [README.md](README.md) (updates, backups, restores).
