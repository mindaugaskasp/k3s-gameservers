# Terraria setup

First set up the cluster once ([README](../../README.md#setup), `make setup`). Then run every
command below in `games/terraria/` on the k3s host; `make help <command>` explains any of them.

## 1. Password

```sh
make init-env        # creates .env from .env.example and shows which values are set
```

- `TERRARIA_SERVER_PASSWORD`: the password players join with; empty lets anyone join.
- `TERRARIA_CONNECT_HOST`: optional, the public host name.

The REST tokens the exporter and the pod's shutdown use are made by the chart on first install.

## 2. World and server settings

`server` in `values.override.yaml`: `worldName`, `worldSize` (1 small, 2 medium, 3 large) and
`maxSlots`. A world named `worldName` that doesn't exist yet is generated at the next start;
changing the name later starts a new world and keeps the old file.

## 3. Start and join

```sh
make push-metrics-image && make deploy
make status          # the first start generates the world, which takes minutes
```

Forward TCP 7777 on the router to the host. Players choose Multiplayer, Join via IP,
and enter `<public address>` and port 7777.

## 4. Admins

TShock prints a one-time setup code in `make logs` on first start. Join, type `/setup <code>`
in chat, then create your account with `/user add <name> <password> owner` and log in with
`/login`. Players in an admin group show as admins on the website.

## 5. Applying changes

`values.override.yaml` and `.env`: `make deploy`, then `make restart`, since TShock reads
its config only at start. Check `make players` first: a restart disconnects everyone.

More: [README.md](README.md) (backups, restores).
