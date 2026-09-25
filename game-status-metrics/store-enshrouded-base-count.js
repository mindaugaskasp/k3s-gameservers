"use strict";

const fs = require("fs");
const { ENSHROUDED_BASE_COUNT_FILE } = require("./config");

function recordEnshroudedBaseCount(count) {
  try {
    fs.writeFileSync(ENSHROUDED_BASE_COUNT_FILE, String(count));
  } catch {
    // No status dir to write in: the count is shown again after the next save.
  }
}

// Null until the server has loaded or saved its world since this pod started.
function readEnshroudedBaseCount() {
  try {
    const count = parseInt(fs.readFileSync(ENSHROUDED_BASE_COUNT_FILE, "utf8"), 10);
    return Number.isInteger(count) ? count : null;
  } catch {
    return null;
  }
}

module.exports = { recordEnshroudedBaseCount, readEnshroudedBaseCount };
