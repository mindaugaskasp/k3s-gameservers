"use strict";

const { GAME, BACKUP_DIR, BACKUP_MAX_AGE_DAYS, BACKUP_MAX_COUNT } = require("../config");
const { formatGaugeLines } = require("../format-metric-lines");
const { readBackups } = require("../read-backups");

/** What every game with backups reports. */
function buildBackupMetricLines() {
  const game = GAME;
  const backups = readBackups();
  const oldest = backups[0];
  const newest = backups[backups.length - 1];
  const sampleForGame = (value) => [{ labels: { game }, value }];
  const sampleForEachBackup = (readValue) => backups.map((backup) => ({
    labels: { game, file: `${BACKUP_DIR}/${backup.name}` },
    value: readValue(backup),
  }));
  return [
    ...formatGaugeLines("game_server_backup_count", "Number of backup archives currently on disk.", sampleForGame(backups.length)),
    ...formatGaugeLines(
      "game_server_backup_bytes",
      "Total disk space used by backup archives.",
      sampleForGame(backups.reduce((total, backup) => total + backup.bytes, 0))
    ),
    ...formatGaugeLines(
      "game_server_backup_retention_days",
      "Configured age at which a backup is deleted (0 = no age limit).",
      sampleForGame(BACKUP_MAX_AGE_DAYS)
    ),
    ...formatGaugeLines(
      "game_server_backup_retention_count",
      "Configured max number of backups kept (0 = no count limit).",
      sampleForGame(BACKUP_MAX_COUNT)
    ),
    ...formatGaugeLines(
      "game_server_backup_oldest_timestamp_seconds",
      "Modification time of the oldest backup.",
      oldest ? sampleForGame(oldest.mtime) : []
    ),
    ...formatGaugeLines(
      "game_server_backup_newest_timestamp_seconds",
      "Modification time of the newest backup.",
      oldest ? sampleForGame(newest.mtime) : []
    ),
    ...formatGaugeLines(
      "game_server_backup_oldest_expiry_timestamp_seconds",
      "When the oldest backup becomes eligible for deletion.",
      oldest && BACKUP_MAX_AGE_DAYS > 0 ? sampleForGame(oldest.mtime + BACKUP_MAX_AGE_DAYS * 86400) : []
    ),
    ...formatGaugeLines(
      "game_server_backup_file_timestamp_seconds",
      "Modification time of each backup archive.",
      sampleForEachBackup((backup) => backup.mtime)
    ),
    ...formatGaugeLines("game_server_backup_file_bytes", "Size of each backup archive.", sampleForEachBackup((backup) => backup.bytes)),
  ];
}

module.exports = { buildBackupMetricLines };
