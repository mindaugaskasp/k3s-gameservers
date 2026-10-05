"use strict";

// gamedig's palworld protocol carries the REST API's /settings and /metrics
// answers in state.raw; the latest ones feed the palworld_* metric lines.
let lastWorldSettings = null;
let lastServerMetrics = null;

function storePalworldQueryAnswer(state) {
  lastWorldSettings = state.raw?.settings ?? lastWorldSettings;
  lastServerMetrics = state.raw?.metrics ?? lastServerMetrics;
}

function readPalworldSettingsAnswer() {
  return lastWorldSettings;
}

function readPalworldServerMetricsAnswer() {
  return lastServerMetrics;
}

module.exports = { storePalworldQueryAnswer, readPalworldSettingsAnswer, readPalworldServerMetricsAnswer };
