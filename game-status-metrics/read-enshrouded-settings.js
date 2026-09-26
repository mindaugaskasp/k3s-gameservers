"use strict";

const fs = require("fs");
const { ENSHROUDED_CONFIG_FILE } = require("./config");

const CUSTOM_PRESET = "Custom";

// Only a Custom preset applies gameSettings, so only then are they compared with the
// Default preset's values, as a new server's enshrouded_server.json writes them.
const DEFAULT_GAME_SETTINGS = {
  playerHealthFactor: 1,
  playerManaFactor: 1,
  playerStaminaFactor: 1,
  playerBodyHeatFactor: 1,
  playerDivingTimeFactor: 1,
  enableDurability: true,
  enableStarvingDebuff: false,
  foodBuffDurationFactor: 1,
  fromHungerToStarving: 600000000000,
  shroudTimeFactor: 1,
  tombstoneMode: "AddBackpackMaterials",
  enableGliderTurbulences: true,
  weatherFrequency: "Normal",
  fishingDifficulty: "Normal",
  miningDamageFactor: 1,
  plantGrowthSpeedFactor: 1,
  resourceDropStackAmountFactor: 1,
  factoryProductionSpeedFactor: 1,
  perkUpgradeRecyclingFactor: 0.5,
  perkCostFactor: 1,
  experienceCombatFactor: 1,
  experienceMiningFactor: 1,
  experienceExplorationQuestsFactor: 1,
  randomSpawnerAmount: "Normal",
  aggroPoolAmount: "Normal",
  enemyDamageFactor: 1,
  enemyHealthFactor: 1,
  enemyStaminaFactor: 1,
  enemyPerceptionRangeFactor: 1,
  bossDamageFactor: 1,
  bossHealthFactor: 1,
  threatBonus: 1,
  pacifyAllEnemies: false,
  tamingStartleRepercussion: "LoseSomeProgress",
  dayTimeDuration: 1800000000000,
  nightTimeDuration: 720000000000,
  curseModifier: "Normal",
};
// Durations in the config are nanoseconds.
const NANOSECONDS_PER_MINUTE = 60e9;
const DURATION_SETTINGS = new Set(["fromHungerToStarving", "dayTimeDuration", "nightTimeDuration"]);

// Config keys whose own wording misleads: the page turns names from camelCase into words.
const PLAIN_SETTING_NAMES = {
  miningDamageFactor: "miningSpeed",
  resourceDropStackAmountFactor: "resourceDrops",
};

function convertSettingValueToText(name, value) {
  if (DURATION_SETTINGS.has(name)) return `${Math.round(value / NANOSECONDS_PER_MINUTE)} min`;
  // The game's settings menu shows every factor as a percentage.
  if (name.endsWith("Factor")) return `${Math.round(value * 100)}%`;

  return String(value);
}

function readChangedGameSettings(gameSettings) {
  return Object.entries(gameSettings)
    .filter(([name, value]) => name in DEFAULT_GAME_SETTINGS && value !== DEFAULT_GAME_SETTINGS[name])
    .map(([name, value]) => ({
      name: PLAIN_SETTING_NAMES[name] ?? name,
      value: convertSettingValueToText(name, value),
    }));
}

/** The difficulty preset, then with a Custom preset every setting changed from Default. */
function readEnshroudedWorldSettings() {
  let config;
  try {
    config = JSON.parse(fs.readFileSync(ENSHROUDED_CONFIG_FILE, "utf8"));
  } catch {
    return [];
  }
  const preset = config.gameSettingsPreset;
  if (!preset) return [];
  const presetSetting = { name: "preset", value: preset };

  return preset === CUSTOM_PRESET
    ? [presetSetting, ...readChangedGameSettings(config.gameSettings ?? {})]
    : [presetSetting];
}

module.exports = { readEnshroudedWorldSettings };
