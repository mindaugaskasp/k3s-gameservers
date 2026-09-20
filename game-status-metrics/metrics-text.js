"use strict";

const { gameServerMetricLines } = require("./metrics/game-server-metrics");
const { valheimMetricLines } = require("./metrics/valheim-metrics");
const { backupMetricLines } = require("./metrics/backup-metrics");

/** The whole exposition, in Prometheus text format. */
function metricsText(status) {
  return [...gameServerMetricLines(status), ...valheimMetricLines(), ...backupMetricLines(), ""].join("\n");
}

module.exports = { metricsText };
