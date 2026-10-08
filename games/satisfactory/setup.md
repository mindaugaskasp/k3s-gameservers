# Satisfactory setup

First set up the cluster once ([README](../../README.md#setup), `make setup`). Then run every
command below in `games/satisfactory/` on the k3s host; `make help <command>` explains any of them.

## 1. Alerts and settings

```sh
make init-env        # creates .env from .env.example and shows which values are set
```

- No password is needed to deploy: the first player to connect claims the server
  and sets its name and admin password in game.
- `SATISFACTORY_DISCORD_WEBHOOK`, `SATISFACTORY_CONNECT_HOST`: optional Discord alerts.
- `SATISFACTORY_SLOT_COUNT`, `SATISFACTORY_GAME_SETTINGS`: comma-separated tuning, each
  one of the image's env vars, e.g. `"AUTOSAVENUM=10,MAXTICKRATE=30"`
  ([all settings](https://github.com/wolveix/satisfactory-server#environment-variables)).

## 2. Start and claim

```sh
make push-metrics-image && make deploy
make status          # the first start downloads the game; wait until the pod is ready
```

Forward UDP 7779, TCP 7779 and TCP 8890 on the router to the host. In the game's
Server Manager, add `<public address>:7779`, claim the server, set its name and
admin password, then start a session. Turn on Auto-Save on Player Disconnect in
its settings: upstream documents no save on stop, only autosaves.
If the node can't fit two games, `make scale-down-zero` in the running one first.

## 3. Query with a password

If you set a client-protection password, the exporter's passwordless query stops
working: run `server.GenerateAPIToken` in the in-game server console, put it in
`.env` as `SATISFACTORY_API_TOKEN`, then `make deploy` and `make restart`.

## 4. Memory and CPU

Upstream recommends more RAM than a fresh save needs; a grown factory climbs.
Raise `resources.requests` (what the node reserves) and `resources.limits.memory` (the
hard cap) in `values.override.yaml`, then `make deploy`. CPU has no limit on purpose.
`kubectl -n games describe vpa satisfactory` shows the measured recommendation.

## 5. Applying changes

`values.override.yaml` and `.env`: `make deploy`; the server only reads them on a
pod start, so follow with `make restart` if the release did not roll by itself.
Check `make players` first: a restart disconnects everyone.

More: [README.md](README.md) (updates, backups, ports).
