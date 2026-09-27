"use strict";

const fs = require("fs");
const { VRISING_VERSION_FILE } = require("./config");

// The Steam query reports "0.0.0.1" for every V Rising build; the install names the real one,
// e.g. "VRisingServer: v1.1.15.0-r101082-b2 (202609071358)".
function readVRisingVersion() {
  try {
    return /v(\d+(?:\.\d+)+)/.exec(fs.readFileSync(VRISING_VERSION_FILE, "utf8"))?.[1] ?? "";
  } catch {
    return "";
  }
}

module.exports = { readVRisingVersion };
