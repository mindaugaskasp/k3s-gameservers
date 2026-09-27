"use strict";

// What only V Rising's exporter is told; the settings every game shares are in game-server/status-metrics/config.js.
// The server's settings as the image wrote them on this start, and the defaults the game ships with.
const VRISING_HOST_SETTINGS_FILE = process.env.VRISING_HOST_SETTINGS_FILE || "";
const VRISING_GAME_SETTINGS_FILE = process.env.VRISING_GAME_SETTINGS_FILE || "";
const VRISING_DEFAULT_GAME_SETTINGS_FILE = process.env.VRISING_DEFAULT_GAME_SETTINGS_FILE || "";
// The installed build, which steamcmd rewrites on every update.
const VRISING_VERSION_FILE = process.env.VRISING_VERSION_FILE || "";

module.exports = { VRISING_HOST_SETTINGS_FILE, VRISING_GAME_SETTINGS_FILE, VRISING_DEFAULT_GAME_SETTINGS_FILE, VRISING_VERSION_FILE };
