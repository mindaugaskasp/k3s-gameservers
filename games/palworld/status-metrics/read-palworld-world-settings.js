"use strict";

const { readPalworldSettingsAnswer } = require("./store-palworld-query-answer");

// What a player picks a server by, reported whatever it is set to.
const HEADLINE_SETTING_NAMES = ["Difficulty", "DeathPenalty", "bHardcore", "bPalLost", "bEnablePlayerToPlayerDamage"];

// The API keeps the settings file's boolean prefix: "bHardcore" reads as "Hardcore".
function stripBooleanPrefix(name) {
  return /^b[A-Z]/.test(name) ? name.slice(1) : name;
}

/** The headline settings, then every rate changed from the game's default of 1; empty before the first answer. */
function readPalworldWorldSettings() {
  const settings = readPalworldSettingsAnswer();
  if (!settings) return [];
  const headlineSettings = HEADLINE_SETTING_NAMES.filter(
    (name) => settings[name] !== undefined && settings[name] !== ""
  ).map((name) => [name, settings[name]]);
  const changedRates = Object.entries(settings).filter(([name, value]) => name.endsWith("Rate") && value !== 1);

  return [...headlineSettings, ...changedRates].map(([name, value]) => ({
    name: stripBooleanPrefix(name),
    value: String(value),
  }));
}

module.exports = { readPalworldWorldSettings };
