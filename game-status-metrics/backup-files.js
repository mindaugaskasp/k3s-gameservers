"use strict";

const fs = require("fs");
const { BACKUP_DIR } = require("./config");

// Oldest first, so [0] is the next one the server's retention will delete.
// Per-file guard: retention may delete a backup between readdir and stat.
// Includes archive/, where tiered retention keeps older backups.
function readBackups() {
  const names = [];
  for (const sub of ["", "archive/"]) {
    try {
      names.push(...fs.readdirSync(`${BACKUP_DIR}/${sub}`).map((name) => sub + name));
    } catch {
      continue;
    }
  }
  const backups = [];
  for (const name of names) {
    if (name.startsWith(".") || name.includes("/.")) continue; // e.g. .play-clock
    try {
      const stat = fs.statSync(`${BACKUP_DIR}/${name}`);
      if (stat.isFile()) backups.push({ name, bytes: stat.size, mtime: Math.floor(stat.mtimeMs / 1000) });
    } catch {
      continue;
    }
  }
  return backups.sort((first, second) => first.mtime - second.mtime);
}

function isArchived(backup) {
  return backup.name.startsWith("archive/");
}

module.exports = { readBackups, isArchived };
