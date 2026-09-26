"use strict";

const fs = require("fs");
const { MINECRAFT_OPS_FILE } = require("./config");

// ops.json names each operator: https://minecraft.wiki/w/Ops.json_format
function readOperatorNames() {
  try {
    return new Set(JSON.parse(fs.readFileSync(MINECRAFT_OPS_FILE, "utf8")).map((operator) => operator.name));
  } catch {
    return new Set();
  }
}

function filterMinecraftOperatorNames(onlinePlayerNames) {
  const operatorNames = readOperatorNames();

  return onlinePlayerNames.filter((name) => operatorNames.has(name));
}

module.exports = { filterMinecraftOperatorNames };
