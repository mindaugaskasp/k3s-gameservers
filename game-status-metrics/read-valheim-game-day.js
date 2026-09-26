"use strict";

const fs = require("fs");
const { findNewestWorldMetadataFile } = require("./find-newest-world-metadata-file");

// netTime is the double after the metadata file's int32 version.
const NET_TIME_OFFSET = 4;
// Same day rule as backup-rename.sh: 1800 s days, each starting at morning, 0.15 in.
const DAY_LENGTH_SECONDS = 1800;
const MORNING_SECONDS = 270;

// The world saves right after a night is slept through, and between saves its clock
// runs at real time, so the save's netTime plus the seconds since it was written is now.
function readCurrentGameDay() {
  const filePath = findNewestWorldMetadataFile();
  if (!filePath) return null;
  try {
    const savedAtSeconds = fs.statSync(filePath).mtimeMs / 1000;
    const netTimeAtSave = fs.readFileSync(filePath).readDoubleLE(NET_TIME_OFFSET);
    const netTimeNow = netTimeAtSave + (Date.now() / 1000 - savedAtSeconds);

    return Math.max(0, Math.floor((netTimeNow - MORNING_SECONDS) / DAY_LENGTH_SECONDS));
  } catch {
    return null; // A save being written right now: the death is kept, without its day.
  }
}

module.exports = { readCurrentGameDay };
