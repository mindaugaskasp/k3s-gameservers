"use strict";

const { RAID_LOG_FILE } = require("./config");
const { readNewLines } = require("./log-follower");

/** Raids the log hooks appended since the last call, each line "<unix time> <event name>". */
function readNewRaids() {
  return readNewLines(RAID_LOG_FILE)
    .map((line) => line.split(" "))
    .filter(([startedAt, name]) => Number(startedAt) > 0 && name)
    .map(([startedAt, name]) => ({ name, startedAt: Number(startedAt) }));
}

module.exports = { readNewRaids };
