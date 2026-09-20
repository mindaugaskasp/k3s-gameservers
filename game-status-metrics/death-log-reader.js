"use strict";

const fs = require("fs");
const { DEATH_LOG_FILE } = require("./config");

// One line per death, appended by the game's log hook. Read by offset instead of
// truncated, so a death appended mid-read is never lost; the log lives in the
// emptyDir, so it starts over with every pod.
let readUpTo = 0;

/** The names that died since the last call, one entry per death. */
function readNewDeaths() {
  let size = 0;
  try {
    size = fs.statSync(DEATH_LOG_FILE).size;
  } catch {
    return [];
  }
  if (size < readUpTo) readUpTo = 0;
  if (size === readUpTo) return [];

  let text = "";
  try {
    const file = fs.openSync(DEATH_LOG_FILE, "r");
    const buffer = Buffer.alloc(size - readUpTo);
    fs.readSync(file, buffer, 0, buffer.length, readUpTo);
    fs.closeSync(file);
    text = buffer.toString("utf8");
  } catch {
    return [];
  }

  // A line the hook has not finished writing waits for the next read.
  const lastLineEnd = text.lastIndexOf("\n");
  if (lastLineEnd === -1) return [];
  readUpTo += lastLineEnd + 1;

  return text.slice(0, lastLineEnd).split("\n").filter(Boolean);
}

module.exports = { readNewDeaths };
