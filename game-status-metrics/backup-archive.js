"use strict";

const fs = require("fs");
const { BACKUP_DIR, BACKUP_RECENT_DAYS, BACKUP_WINDOW_ENDS } = require("./config");
const { isArchived } = require("./backup-files");

const fileName = (backup) => backup.name.replace(/.*\//, "");

// Mirrors backup-prune.sh: same index checks, same windows, so the dashboard
// shows what the next prune will do and whether it will run at all.
function readPlayClock(backups) {
  const playSecondsByFile = new Map();
  let problem = "";
  try {
    for (const line of fs.readFileSync(`${BACKUP_DIR}/.play-clock`, "utf8").split("\n")) {
      if (!line) continue;
      const entry = /^([^ ]+) ([0-9]+)$/.exec(line);
      if (!entry) {
        problem = "unreadable line";
        break;
      }
      playSecondsByFile.set(entry[1], Number(entry[2]));
    }
  } catch {
    problem = "missing";
  }
  const archived = backups.filter(isArchived);
  const unindexed = archived.find((backup) => !playSecondsByFile.has(fileName(backup)));
  if (!problem && unindexed) problem = `no entry for ${fileName(unindexed)}`;
  if (problem && !archived.length) problem = ""; // prune rebuilds it while nothing is archived
  return { playSecondsByFile, problem };
}

function windowFor(ageDays) {
  let start = BACKUP_RECENT_DAYS;
  if (ageDays < start) return "recent";
  for (const end of BACKUP_WINDOW_ENDS) {
    if (ageDays < end) return `${start}-${end}`;
    start = end;
  }
  return "expired";
}

function windowEndDays(window) {
  if (window.includes("-")) return Number(window.split("-")[1]);
  return window === "recent" ? BACKUP_RECENT_DAYS : undefined;
}

/** Each backup's play-time age and retention window, plus how full each window is. */
function classifyBackups(backups) {
  const { playSecondsByFile, problem } = readPlayClock(backups);
  const newestPlaySeconds = backups.length ? playSecondsByFile.get(fileName(backups[backups.length - 1])) : undefined;
  const windowCounts = new Map(
    BACKUP_WINDOW_ENDS.map((end, index) => [`${index ? BACKUP_WINDOW_ENDS[index - 1] : BACKUP_RECENT_DAYS}-${end}`, 0])
  );
  const files = [];
  for (const backup of backups) {
    const playSeconds = playSecondsByFile.get(fileName(backup));
    const ageDays =
      newestPlaySeconds !== undefined && playSeconds !== undefined ? (newestPlaySeconds - playSeconds) / 86400 : undefined;
    const window = ageDays === undefined ? "unindexed" : windowFor(ageDays);
    const gameDay = /-game-day-([0-9]+)\.zip$/.exec(backup.name);
    if (isArchived(backup) && windowCounts.has(window)) windowCounts.set(window, windowCounts.get(window) + 1);
    files.push({
      backup,
      ageDays,
      window,
      endDays: windowEndDays(window),
      gameDay: gameDay ? Number(gameDay[1]) : undefined,
    });
  }
  return { problem, newestPlaySeconds, windowCounts, files };
}

module.exports = { classifyBackups };
