# Player database

Each game's status-metrics sidecar keeps its own SQLite file,
`<DATABASE_DIR>/<game>-players.db` on the game's volume. Nothing is shared between
games: each database has only the tables and columns its game uses.

## Modules

In `game-status-metrics/`:

- `open-sqlite-database.js`: opens the file and applies migrations. This process is its
  only writer: another user's [WAL](https://sqlite.org/wal.html) files would make it "readonly".
- `store-player-history.js`: what every game records per player: time online, deaths
  and when the last one was, last seen.
- `store-valheim-death-days.js`: the in-game day of a Valheim player's last death.
- `store-zomboid-player-history.js`: zombie kills, and the character a Zomboid player
  last died as.
- `store-raids.js`: every Valheim raid and when it started; the latest ones feed the website's raid list.
- `read-table-column-names.js`: a table's columns, which differ from game to game.
- `reset-player-stats.js`: run by `make reset-player-stats`; saves a copy of the
  database first, then clears whichever stat columns this game has.

## Migrations

`apply-database-migrations.js` applies `migrations/<game>/` in filename order on
connect and records each in the `migration` table.

- One folder per game, named after its gamedig id (`valheim`, `projectzomboid`,
  `enshrouded`). A column two games need is added in both folders.
- Add a file, never edit one that has shipped.

## Reading it

- `make read-player-db` opens a read-only `sqlite3` shell; type SQL ending in `;`, `.quit` to leave.
- `make read-player-db SQL='select * from player'` runs one query instead.
