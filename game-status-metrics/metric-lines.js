"use strict";

// A raw newline in a label value corrupts the whole exposition, so a server
// name or failure reason containing one would break every metric.
function escapeLabel(value) {
  return String(value).replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/\n/g, "\\n");
}

function formatLabels(labels) {
  return Object.entries(labels)
    .map(([name, value]) => `${name}="${escapeLabel(value)}"`)
    .join(",");
}

/** One gauge's HELP, TYPE and samples; nothing at all when there is no sample to report. */
function gaugeLines(metricName, helpText, samples) {
  if (!samples.length) return [];
  return [
    `# HELP ${metricName} ${helpText}`,
    `# TYPE ${metricName} gauge`,
    ...samples.map(({ labels, value }) => `${metricName}{${formatLabels(labels)}} ${value}`),
  ];
}

module.exports = { escapeLabel, gaugeLines };
