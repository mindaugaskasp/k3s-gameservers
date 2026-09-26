"use strict";

const { GAME, BACKUP_DIR } = require("../../../../game-server/status-metrics/config");
const { formatGaugeLines } = require("../../../../game-server/status-metrics/format-metric-lines");
const { isArchived } = require("../../../../game-server/status-metrics/read-backups");
const { classifyBackups } = require("../classify-backups");
const { readLastPlayerActivityTimestamp } = require("../read-valheim-status-files");

/** How backup-prune.sh's play-time retention sees each backup. */
function buildBackupArchiveMetricLines(backups) {
  const game = GAME;
  const { problem, newestPlaySeconds, windowCounts, files } = classifyBackups(backups);
  const lastActivityAt = readLastPlayerActivityTimestamp();
  const sampleForEachBackup = (matches, readValue) =>
    files.filter(matches).map((file) => ({
      labels: { game, file: `${BACKUP_DIR}/${file.backup.name}` },
      value: readValue(file),
    }));
  return [
    ...formatGaugeLines(
      "valheim_backup_play_clock_ok",
      "1 if backup-prune.sh's play-time index is usable; 0 means pruning is stopped.",
      [{ labels: { game, problem }, value: problem ? 0 : 1 }]
    ),
    ...formatGaugeLines(
      "valheim_backup_play_clock_seconds",
      "Play time recorded up to the newest backup (idle gaps count at most a day).",
      newestPlaySeconds === undefined ? [] : [{ labels: { game }, value: newestPlaySeconds }]
    ),
    ...formatGaugeLines(
      "valheim_backup_archive_window_files",
      "Archived backups per play-time window (days).",
      [...windowCounts].map(([window, count]) => ({ labels: { game, window }, value: count }))
    ),
    ...formatGaugeLines(
      "valheim_backup_file_info",
      "Where each backup sits: recent/archive, and its play-time window.",
      files.map((file) => ({
        labels: {
          game,
          file: `${BACKUP_DIR}/${file.backup.name}`,
          location: isArchived(file.backup) ? "archive" : "recent",
          window: file.window,
        },
        value: 1,
      }))
    ),
    ...formatGaugeLines(
      "valheim_backup_file_game_day",
      "In-game day of the world in each backup (from its name).",
      sampleForEachBackup((file) => file.gameDay !== undefined, (file) => file.gameDay)
    ),
    ...formatGaugeLines(
      "valheim_backup_file_play_age_seconds",
      "Play time between each backup and the newest one.",
      sampleForEachBackup((file) => file.ageDays !== undefined, (file) => Math.round(file.ageDays * 86400))
    ),
    ...formatGaugeLines(
      "valheim_backup_file_window_left_seconds",
      "Play time until each backup leaves its window (then archived, moved on or deleted).",
      sampleForEachBackup((file) => file.endDays !== undefined, (file) => Math.round((file.endDays - file.ageDays) * 86400))
    ),
    ...formatGaugeLines(
      "valheim_last_player_activity_timestamp_seconds",
      "Last join/leave/online-check that saw a player.",
      lastActivityAt ? [{ labels: { game }, value: lastActivityAt }] : []
    ),
  ];
}

module.exports = { buildBackupArchiveMetricLines };
