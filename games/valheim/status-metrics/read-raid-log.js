"use strict";

const { RAID_LOG_FILE } = require("./config");
const { readNewLines } = require("../../../game-status-metrics/read-new-log-lines");

/** Raids the log hooks appended since the last call, each line "<unix time> <event ID>". */
function readNewRaids() {
  return readNewLines(RAID_LOG_FILE)
    .map((line) => line.split(" "))
    .filter(([startedAt, eventId]) => Number(startedAt) > 0 && eventId)
    .map(([startedAt, eventId]) => ({ eventId, startedAt: Number(startedAt) }));
}

module.exports = { readNewRaids };
