"use strict";

const fs = require("fs");
const path = require("path");
const { WORLD_SAVE_DIR } = require("./config");

// Valheim's world metadata, rewritten on every save as _main.<save number>.db2.
const WORLD_METADATA_FILE = /^_main\.(\d+)\.db2$/;

/** The newest save's metadata file; "" for a game without WORLD_SAVE_DIR or before the first save. */
function findNewestWorldMetadataFile() {
  let newest = { saveNumber: -1, filePath: "" };
  let fileNames = [];
  try {
    fileNames = fs.readdirSync(WORLD_SAVE_DIR);
  } catch {
    return "";
  }
  for (const fileName of fileNames) {
    const saveNumber = Number(WORLD_METADATA_FILE.exec(fileName)?.[1] ?? -1);
    if (saveNumber > newest.saveNumber) newest = { saveNumber, filePath: path.join(WORLD_SAVE_DIR, fileName) };
  }

  return newest.filePath;
}

module.exports = { findNewestWorldMetadataFile };
