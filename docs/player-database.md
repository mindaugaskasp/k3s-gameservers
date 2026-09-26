# Player database

Each game's status-metrics sidecar keeps its own SQLite file,
`<DATABASE_DIR>/<game>.db` on the game's volume, named by gamedig id (`projectzomboid.db`).
Nothing is shared between games: each database has only the tables and columns its game uses.
A file still named `<game>-players.db` is moved to the new name on start.

## Modules

In `game-status-metrics/`:

- `open-sqlite-database.js`: opens the file and applies migrations. This process is its
  only writer: another user's [WAL](https://sqlite.org/wal.html) files would make it "readonly".
- `store-player-history.js`: what every game records per player: time online, deaths
  and when the last one was, last seen.
- `reset-player-stats.js`: run by `make reset-player-stats`; saves a copy of the
  database first, then clears the shared stats and the plugin's `playerStatResetValues`.

Each game's own stores are listed in [status-metrics-games.md](status-metrics-games.md).

## Migrations

`apply-database-migrations.js` applies `games/<game>/status-metrics/migrations/` in
filename order on connect and records each in the `migration` table.

- Each game has its own; a column two games need is added in both folders.
- Add a file, never edit one that has shipped.

## Reading it

- `make read-player-db` opens a read-only `sqlite3` shell; type SQL ending in `;`, `.quit` to leave.
- `make read-player-db SQL='select * from player'` runs one query instead.
