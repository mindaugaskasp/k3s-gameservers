"use strict";

const fs = require("fs");
const { MINECRAFT_SERVER_PROPERTIES_FILE } = require("./config");

// The rules a player notices first: https://minecraft.wiki/w/Server.properties
const REPORTED_PROPERTIES = ["difficulty", "gamemode", "hardcore", "pvp"];

/** e.g. { name: "difficulty", value: "normal" }; empty before the first start writes the file. */
function readMinecraftWorldSettings() {
  let lines = [];
  try {
    lines = fs.readFileSync(MINECRAFT_SERVER_PROPERTIES_FILE, "utf8").split("\n");
  } catch {
    return [];
  }
  const properties = new Map(
    lines.filter((line) => line.includes("=") && !line.startsWith("#")).map((line) => {
      const separator = line.indexOf("=");
      return [line.slice(0, separator).trim(), line.slice(separator + 1).trim()];
    })
  );

  return REPORTED_PROPERTIES.filter((name) => properties.has(name)).map((name) => ({ name, value: properties.get(name) }));
}

module.exports = { readMinecraftWorldSettings };
