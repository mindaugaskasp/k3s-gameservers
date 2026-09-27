"use strict";

const fs = require("fs");
const { VRISING_HOST_SETTINGS_FILE, VRISING_GAME_SETTINGS_FILE, VRISING_DEFAULT_GAME_SETTINGS_FILE } = require("./config");

// The game writes its settings with a byte order mark, which JSON.parse rejects.
function readJsonFile(filePath) {
  try {
    return JSON.parse(fs.readFileSync(filePath, "utf8").replace(/^\uFEFF/, ""));
  } catch {
    return null;
  }
}

/** [name, value] per setting; a nested one is named by its whole path, lists are left out. */
function flattenSettingsToPairs(settings, parentName = "") {
  return Object.entries(settings).flatMap(([key, value]) => {
    const name = parentName + key.replaceAll("_", "");
    if (Array.isArray(value)) return [];
    if (value !== null && typeof value === "object") return flattenSettingsToPairs(value, name);
    return [[name, value]];
  });
}

// A host difficulty preset (Difficulty_Brutal) is loaded over the game settings' own difficulty.
function readDifficulty(hostSettings, gameSettings) {
  const preset = hostSettings.GameDifficultyPreset ?? "";
  return preset ? preset.replace(/^Difficulty_/, "") : gameSettings.GameDifficulty;
}

// What a player picks a server by, reported whatever it is set to.
function readHeadlineSettings(hostSettings, gameSettings) {
  return [
    ["GameModeType", gameSettings.GameModeType],
    ["GameDifficulty", readDifficulty(hostSettings, gameSettings)],
    ["ClanSize", gameSettings.ClanSize],
  ];
}

/** The headline settings, then every other one changed from the game's default; empty before the first start. */
function readVRisingWorldSettings() {
  const gameSettings = readJsonFile(VRISING_GAME_SETTINGS_FILE);
  if (!gameSettings) return [];
  const headlineSettings = readHeadlineSettings(readJsonFile(VRISING_HOST_SETTINGS_FILE) ?? {}, gameSettings);
  const headlineNames = new Set(headlineSettings.map(([name]) => name));
  const defaultSettings = new Map(flattenSettingsToPairs(readJsonFile(VRISING_DEFAULT_GAME_SETTINGS_FILE) ?? {}));
  const changedFromDefault = flattenSettingsToPairs(gameSettings).filter(
    ([name, value]) => !headlineNames.has(name) && defaultSettings.has(name) && defaultSettings.get(name) !== value
  );

  return [...headlineSettings, ...changedFromDefault]
    .filter(([, value]) => value !== undefined && value !== "")
    .map(([name, value]) => ({ name, value: String(value) }));
}

module.exports = { readVRisingWorldSettings };
