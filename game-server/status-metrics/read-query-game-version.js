"use strict";

// The real game version rides in the A2S tags as "g=1.0.14"; gamedig's own
// `version` field is the query protocol version, always "1.0.0.0".
function readQueryGameVersion(state) {
  const versionTag = (state.raw?.tags || []).find((tag) => tag.startsWith("g="));
  return versionTag ? versionTag.slice(2) : state.version || "";
}

module.exports = { readQueryGameVersion };
