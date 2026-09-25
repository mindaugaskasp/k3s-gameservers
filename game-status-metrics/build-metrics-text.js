"use strict";

const { buildGameServerMetricLines } = require("./metrics/build-game-server-metrics");
const { buildValheimMetricLines } = require("./metrics/build-valheim-metrics");
const { buildZomboidMetricLines } = require("./metrics/build-zomboid-metrics");
const { buildEnshroudedMetricLines } = require("./metrics/build-enshrouded-metrics");
const { buildBackupMetricLines } = require("./metrics/build-backup-metrics");

/** The whole exposition, in Prometheus text format. */
function buildMetricsText(status) {
  return [
    ...buildGameServerMetricLines(status),
    ...buildValheimMetricLines(),
    ...buildZomboidMetricLines(),
    ...buildEnshroudedMetricLines(),
    ...buildBackupMetricLines(),
    "",
  ].join("\n");
}

module.exports = { buildMetricsText };
