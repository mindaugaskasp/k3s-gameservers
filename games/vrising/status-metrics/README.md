# V Rising status metrics

What only V Rising's exporter records and reports, beyond `game-plugin.js` and
`config.js`. The shared part: [status-metrics.md](../../../docs/status-metrics.md).

- `read-vrising-world-settings.js`: game mode, difficulty and clan size, then every
  `ServerGameSettings.json` setting that differs from the defaults the install ships with.
- `read-vrising-version.js`: the game version from the install's `VERSION` file; the Steam
  query reports `0.0.0.1` for every build.
- `metrics/build-vrising-metrics.js`: `vrising_world_setting`.

Player names and counts come from the Steam query, so there is no log to follow.
