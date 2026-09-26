"use strict";

const { DEATH_LOG_FILE } = require("./config");
const { readNewLines } = require("../../../game-status-metrics/read-new-log-lines");

/** One name per death the log hooks appended since the last call. */
function readNewDeaths() {
  return readNewLines(DEATH_LOG_FILE);
}

module.exports = { readNewDeaths };
