"use strict";

const { gameServerMetricLines } = require("./metrics/game-server-metrics");
const { valheimMetricLines } = require("./metrics/valheim-metrics");
const { zomboidMetricLines } = require("./metrics/zomboid-metrics");
const { enshroudedMetricLines } = require("./metrics/enshrouded-metrics");
const { backupMetricLines } = require("./metrics/backup-metrics");

/** The whole exposition, in Prometheus text format. */
function metricsText(status) {
  return [
    ...gameServerMetricLines(status),
    ...valheimMetricLines(),
    ...zomboidMetricLines(),
    ...enshroudedMetricLines(),
    ...backupMetricLines(),
    "",
  ].join("\n");
}

module.exports = { metricsText };
