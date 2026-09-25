"use strict";

// Run by `make reset-player-stats`, inside the status-metrics container.
const { resetPlayerStats } = require("./store-player-history");

try {
  const { resetPlayerCount, backupFile } = resetPlayerStats();
  const players = resetPlayerCount === 1 ? "player" : "players";
  console.log(`Reset time played, deaths and zombie kills for ${resetPlayerCount} ${players}.`);
  console.log(`The database as it was before the reset is saved as ${backupFile}`);
} catch (error) {
  // The backup is taken before anything is zeroed, so a failure leaves every count as it was.
  console.error(`Reset failed, nothing was changed: ${error.message}`);
  process.exitCode = 1;
}
