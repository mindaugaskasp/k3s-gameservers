# Adding a new game

The one checklist for adding a game. The game is fully supported once every box is ticked.
Each item says what it achieves first; the file names after it are for whoever does the work.
Rules for names, comments and docs: [CLAUDE.md](CLAUDE.md).

## 1. Get started

- [ ] Pick a ready-made server image that is still updated and installs, updates and backs up the game itself.
      Read which settings, folders and ports it uses
- [ ] Find the game's id in the [gamedig list](https://github.com/gamedig/node-gamedig/blob/master/GAMES_LIST.md): it's how we ask the server who is online
- [ ] Copy the most similar game in `games/` and rename everything in it. Build extras (update jobs,
      settings-file edits, log reading) only if the image can't do them itself

## 2. Server setup files (`games/<game>/`)

- [ ] **How the server runs:** `chart/` uses the shared `game-server/chart` and has the usual templates:
      `statefulset.yaml`, `service.yaml`, `metrics-service.yaml`, `vpa.yaml`, `secret.yaml`, `alerts-secret.yaml`,
      `hooks-configmap.yaml`, `NOTES.txt`
- [ ] **Stats helper (sidecar) settings:** `_status-metrics.tpl` gives the helper the game id, query port and folders
- [ ] **Backups:** the image's own, or a `_backup.tpl` backup container. If the game doesn't save when told to
      stop, save it first in `preStop`
- [ ] **Commands:** the `Makefile` names the game, its data and backup folders, and has `make deploy`, which
      reads passwords and names from `.env`
- [ ] **Discord alerts:** `deploy` calls `set_discord_alerts` with the game's webhook; `.env.example` lists it
- [ ] **Settings and secrets:** `values.override.yaml` (settings, memory), `.env.example` (passwords), `restore-backup.sh`
- [ ] **Checked:** `make lint` and `make template` pass, and no real password shows in the output

## 3. Stats helper (sidecar, `games/<game>/status-metrics/`)

A small program running beside the game that counts players and collects stats for Grafana and the website.

- [ ] `game-plugin.js` fills in every part `load-game-plugin.js` lists (empty where the game has nothing)
- [ ] `config.js` holds this game's own settings; `migrations/` (the player database) is copied from another game
- [ ] Stats only this game has start with `<game>_`; stats every game has start with `game_server_` ([rules](CLAUDE.md#metrics))
- [ ] `README.md` says what it reads and lists every stat it adds
- [ ] **Checked:** `make push-metrics-image`, then `make port-forward-metrics` shows `game_server_up 1` and the players

## 4. Grafana and alerts

- [ ] **Own folder, own dashboards:** every dashboard lives in `games/<game>/grafana/dashboards/` and shows only
      this game. No dashboard is shared with or copied from another game at deploy time: set `SHARED_DASHBOARDS :=`
      (empty) in the `Makefile`, like Valheim. Copying another game's JSON as a starting point is fine
- [ ] `make dashboards` ships them to the game's own Grafana folder. Restart Grafana once so it sees the new folder
- [ ] Every dashboard shows data, and the server's log shows up in Loki (Grafana's log search)
- [ ] The "Game server not answering" alert covers the game (it does once `game_server_up` reports)

## 5. Network

- [ ] Pick ports inside the cluster's allowed range ([platform.md](docs/platform.md#k3s)) and forward them on the router

## 6. Test the running server

- [ ] `make deploy`: the first start finishes and nothing keeps restarting
- [ ] Join from a game client over the internet; `make players` shows you
- [ ] Discord posts when the server starts and stops; `make scale-down-zero` then `make scale-up` keep the world
- [ ] A backup appears (`make backups`), `make sync` copies it off, `make restore-backup` brings it back
- [ ] **Off-host copy, like Valheim:** while the game runs, `make offsite-backup` (repo root; also every 6 hours)
      uploads its `data` and `data-backups`; check both show under `<game>/` on the remote ([offsite-backups.md](docs/offsite-backups.md))
- [ ] Its memory reservation stops two games running at once ([sizing](docs/architecture.md#sizing))

## 7. Website (`k3s-gameservers-web`)

- [ ] **Show the server:** add `<gamedig id>:<port>[:<query port>]` to `GAME_SERVER_WATCH_LIST` in `site.env` and `site.env.example`
- [ ] **Show its stats:** add `<gamedig id>=http://<game>-metrics.games.svc.cluster.local:9101/metrics` to `GAME_STATS_SOURCES`
- [ ] **No Steam join button** if Steam links don't open the game: add it to `GAMES_WITHOUT_STEAM_JOIN`
- [ ] **Which stats to show:** `read-game-stats.js` lists them, `<game>_world_setting` goes in `WORLD_SETTING_METRICS`; update its tests
- [ ] **Artwork and wording:** `public/images/<gamedig id>.jpg`, `GameStatsTest.php`; tooltips say what a stat is in plain words
- [ ] **Checked:** after redeploying, the game's card shows it online with players and stats

## 8. Docs

- [ ] `games/<game>/README.md` (how it runs) and `setup.md` (passwords, joining, memory)
- [ ] Root `README.md`: the game list, the setup link and the router ports table
- [ ] `docs/architecture.md`: add the game to the games list, plus a line for anything only it has
- [ ] Each Markdown file aims for 60 lines and never passes 100

## Where each game stands (2026-09-27)

| Game | Server + stats | Discord | Grafana | Off-host backup | Game docs | Restore script | Root docs | Website |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Valheim | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Project Zomboid | ✅ | ✅ | ⚠️ still uses shared `process-health` | ⚠️ backups only, no world copy | ✅ | ✅ | ✅ | ✅ |
| Enshrouded | ✅ | ✅ | ⚠️ shared only | ❌ never uploaded | ✅ | ✅ | ✅ | ✅ |
| Minecraft | ✅ | ✅ | ✅ | ❌ never uploaded | ✅ | ✅ | ✅ | ✅ |
| V Rising | ✅ | ✅ | ⚠️ shared only | ✅ | ✅ | ✅ | ✅ | ✅ |
| Terraria | ✅ | ❌ not set up | ✅ | ❌ never uploaded | ✅ | ✅ | ✅ | ✅ |
| Dragonwilds | ✅ in testing | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

Grafana ⚠️ means it still uses the shared `game-server/grafana/` dashboards.
