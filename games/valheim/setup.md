# Valheim setup

First set up the cluster once ([README](../../README.md#setup), `make setup`). Then run every
command below in `games/valheim/` on the k3s host; `make help <command>` explains any of them.

## 1. Passwords and alerts

```sh
make init-env        # creates .env from .env.example and shows which values are set
```

Edit `.env`: `VALHEIM_SERVER_PASSWORD` (required, at least 5 characters), and optionally
`VALHEIM_DISCORD_WEBHOOK` and `VALHEIM_CONNECT_HOST` for Discord alerts.

## 2. Server settings

`values.override.yaml` holds everything that is not secret:

- `server.displayName`: the name in the server browser.
- `server.worldName`: the save name. Changing it starts a **new** world.
- `server.public`, `server.crossplay`: server browser listing, and Xbox/Game Pass players.
- `server.extraArgs`: world modifiers, e.g. `-modifier raids more -modifier portals casual`
  (`combat`, `deathPenalty`, `resources`, `raids`, `portals`), or a whole `-preset hard`.

## 3. Start and join

```sh
make push-metrics-image && make deploy
make logs            # wait for "Game server connected"
```

Forward UDP 2456-2458 on the router to the host. Players join `<public address>:2456`.
If the node can't fit two games, `make scale-down-zero` in the running one first.

## 4. Mods (BepInEx)

1. Set `mods.enabled: true` in `values.override.yaml` and `make deploy`.
2. Copy plugin DLLs into the world volume, then restart:
   `kubectl -n games cp MyMod.dll valheim-0:/config/bepinex/plugins/ -c gameserver && make restart`
3. `make mods-status` shows what loaded. After a game update mods stay off until
   `make approve-mods && make restart`.

To remove a mod, delete its DLL (`make shell`, then `rm /config/bepinex/plugins/MyMod.dll`) and
`make restart`. To turn all mods off, set `mods.enabled: false` and `make deploy`.
Admins also need the mod on their own PC for devcommands: `client/client-mods.ps1`.

## 5. Memory and CPU

Raise `resources.requests` (what the node reserves) and `resources.limits.memory` (the
hard cap) in `values.override.yaml`, then `make deploy`. CPU has no limit on purpose.
`kubectl -n games describe vpa valheim` shows the measured recommendation.

## 6. Applying changes

- `values.override.yaml`: `make deploy`, which restarts the server when the pod changes.
- `.env`: `make deploy`, then `make restart` (a new password is read only at start).
- Check `make players` first: a restart disconnects everyone.

More: [README.md](README.md) (backups, restores, alerts).
