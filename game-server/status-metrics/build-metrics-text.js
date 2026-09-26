"use strict";

const { buildGameServerMetricLines } = require("./metrics/build-game-server-metrics");
const { buildBackupMetricLines } = require("./metrics/build-backup-metrics");

/** The whole exposition, in Prometheus text format: every game's metrics, then this game's own. */
function buildMetricsText(status, gamePlugin) {
  return [
    ...buildGameServerMetricLines(status, gamePlugin),
    ...buildBackupMetricLines(),
    ...gamePlugin.buildMetricLines(),
    "",
  ].join("\n");
}

module.exports = { buildMetricsText };
