"use strict";

const fs = require("fs");
const { ZOMBOID_SANDBOX_FILE } = require("./config");

// SandboxVars.lua documents each setting in the comments above it: "-- 4 = Normal" per
// choice, then "Default = Normal" for choices or "Default: 0.65" for numbers.
const CHOICE_LABEL = /^\s*--\s*(-?\d+) = (.+?)\s*$/;
const CHOICE_DEFAULT = /Default = (.+?)\s*$/;
const NUMBER_DEFAULT = /Default: (-?[\d.]+)/;
const SETTING = /^\s*(\w+) = ([^{]+?),\s*$/;
const TABLE_START = /^\s*(\w+) = \{\s*$/;
const TABLE_END = /^\s*\},?\s*$/;

function convertToChangedSetting(name, value, comment) {
  const choiceDefault = comment.choiceDefault;
  if (choiceDefault !== null && comment.choiceLabels.has(value)) {
    const label = comment.choiceLabels.get(value);
    return label === choiceDefault ? null : { name, value: label };
  }
  if (comment.numberDefault !== null && Number(value) !== Number(comment.numberDefault)) {
    return { name, value };
  }

  return null;
}

function createEmptyComment() {
  return { choiceLabels: new Map(), choiceDefault: null, numberDefault: null };
}

function recordCommentLine(line, comment) {
  const choice = CHOICE_LABEL.exec(line);
  if (choice) comment.choiceLabels.set(choice[1], choice[2]);
  comment.choiceDefault = CHOICE_DEFAULT.exec(line)?.[1] ?? comment.choiceDefault;
  comment.numberDefault = NUMBER_DEFAULT.exec(line)?.[1] ?? comment.numberDefault;
}

/** Settings changed from the game's default, e.g. { name: "DayLength", value: "2 Hours" }. */
function readChangedSandboxSettings() {
  let lines = [];
  try {
    lines = fs.readFileSync(ZOMBOID_SANDBOX_FILE, "utf8").split("\n");
  } catch {
    return [];
  }

  const changedSettings = [];
  const tableNames = [];
  let comment = createEmptyComment();
  for (const line of lines.slice(1)) {
    if (line.trim().startsWith("--")) {
      recordCommentLine(line, comment);
      continue;
    }
    const tableStart = TABLE_START.exec(line);
    if (tableStart) tableNames.push(tableStart[1]);
    else if (TABLE_END.test(line)) tableNames.pop();
    const setting = SETTING.exec(line);
    const changed = setting && convertToChangedSetting(tableNames.concat(setting[1]).join(""), setting[2], comment);
    if (changed) changedSettings.push(changed);
    comment = createEmptyComment();
  }

  return changedSettings;
}

module.exports = { readChangedSandboxSettings };
