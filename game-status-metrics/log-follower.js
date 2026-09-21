"use strict";

const fs = require("fs");
const { LOG_READ_POSITIONS_FILE } = require("./config");

const NEWLINE = 0x0a;

// { firstReadAt, offsets: { [filePath]: bytesAlreadyRead } }, loaded once per process.
let loadedReadPositions = null;

function getReadPositions() {
  if (loadedReadPositions) return loadedReadPositions;
  try {
    loadedReadPositions = JSON.parse(fs.readFileSync(LOG_READ_POSITIONS_FILE, "utf8"));
  } catch {
    // Saved at once: a restart must keep this pod's firstReadAt, not start a later one.
    loadedReadPositions = { firstReadAt: Date.now(), offsets: {} };
    saveReadPositions();
  }
  return loadedReadPositions;
}

// Written to a temporary file and renamed, so a crash mid-write cannot leave half a file.
function saveReadPositions() {
  try {
    const temporaryFile = `${LOG_READ_POSITIONS_FILE}.tmp`;
    fs.writeFileSync(temporaryFile, JSON.stringify(loadedReadPositions));
    fs.renameSync(temporaryFile, LOG_READ_POSITIONS_FILE);
  } catch {
    // A read-only status dir only costs resuming after an exporter restart.
  }
}

// A file last written before this pod's first read is an earlier session's, so its
// lines are history rather than news and it is followed from its end.
function getStartingOffset(fileStats, positions) {
  return fileStats.mtimeMs < positions.firstReadAt ? fileStats.size : 0;
}

/** Complete lines appended to the file since the last call; a half-written last line waits. */
function readNewLines(filePath) {
  const positions = getReadPositions();
  let fileStats;
  try {
    fileStats = fs.statSync(filePath);
  } catch {
    return [];
  }

  const knownOffset = positions.offsets[filePath];
  let offset = knownOffset ?? getStartingOffset(fileStats, positions);
  if (fileStats.size < offset) offset = 0;

  let unreadBytes = Buffer.alloc(0);
  if (fileStats.size > offset) {
    try {
      const file = fs.openSync(filePath, "r");
      unreadBytes = Buffer.alloc(fileStats.size - offset);
      fs.readSync(file, unreadBytes, 0, unreadBytes.length, offset);
      fs.closeSync(file);
    } catch {
      return [];
    }
  }

  const completeLength = unreadBytes.lastIndexOf(NEWLINE) + 1;
  positions.offsets[filePath] = offset + completeLength;
  if (positions.offsets[filePath] !== knownOffset) saveReadPositions();

  return unreadBytes.subarray(0, completeLength).toString("utf8").split("\n").filter(Boolean);
}

module.exports = { readNewLines };
