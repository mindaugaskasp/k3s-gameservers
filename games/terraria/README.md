# Terraria

Runs [`ryshe/terraria`](https://github.com/ryansheehan/terraria), the
[TShock](https://github.com/Pryaxis/TShock) server, which vanilla clients join. Setup: [setup.md](setup.md).

## Image and data

- **Config:** an init container sets TShock's REST API, its tokens, the password, slots and
  backups in `config.json` before every start; TShock keeps every other setting in it.
- **Volume:** `worlds/` holds the world, TShock's config, database and backups; `logs/` and
  `plugins/` the rest; `database/sqlite/` the exporter's player history.
- **Stop:** the pod's preStop hook saves and stops the server through the REST API.
- **Alerts:** the image has no curl, so no Discord alerts; the start and stop status files still work.

## Backups

TShock copies the world file to `worlds/backups/` every `backups.intervalMinutes` and
deletes copies older than `backups.keepDays`.

- `make sync` copies the worlds folder and the backups to `data/` and `data-backups/`.
- `make restore-backup` swaps the world file for a backup, keeping the old one in `.replaced-<time>/`.

## Monitoring

The status-metrics sidecar queries TShock's REST status (gamedig `terrariatshock`), which names
online players and their groups; players in an admin group show as admins. The REST API
listens only inside the pod: the Service exposes the game port alone.
