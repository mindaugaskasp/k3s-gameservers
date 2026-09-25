"use strict";

const fs = require("fs");
const path = require("path");
const zlib = require("zlib");
const { WORLD_SAVE_DIR } = require("./config");

// Valheim's world metadata, rewritten on every save as _main.<save number>.db2. It opens
// with int32 version, double netTime and int32 length, then that many bytes of gzip.
const WORLD_METADATA_FILE = /^_main\.(\d+)\.db2$/;
const COMPRESSED_LENGTH_OFFSET = 12;
const COMPRESSED_START = COMPRESSED_LENGTH_OFFSET + 4;
const DEFEATED_BOSS_KEY_PREFIX = Buffer.from("defeated_");
const GLOBAL_KEY = /^[a-z0-9_]+$/;

let lastRead = { filePath: "", modifiedAtMs: 0, defeatedBossIds: [] };

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

// Global keys are .NET strings: one length byte, then the text. Keys never reach 128 bytes.
function readDefeatedBossIds(metadata) {
  const bossIds = new Set();
  for (let start = metadata.indexOf(DEFEATED_BOSS_KEY_PREFIX); start > 0; start = metadata.indexOf(DEFEATED_BOSS_KEY_PREFIX, start + 1)) {
    const key = metadata.toString("latin1", start, start + metadata[start - 1]);
    if (key.startsWith(DEFEATED_BOSS_KEY_PREFIX.toString()) && GLOBAL_KEY.test(key)) {
      bossIds.add(key.slice(DEFEATED_BOSS_KEY_PREFIX.length));
    }
  }

  return [...bossIds].sort();
}

function decompressWorldMetadata(filePath) {
  const saveFile = fs.readFileSync(filePath);
  const compressedLength = saveFile.readInt32LE(COMPRESSED_LENGTH_OFFSET);

  return zlib.gunzipSync(saveFile.subarray(COMPRESSED_START, COMPRESSED_START + compressedLength));
}

/** Boss IDs as the game names them, e.g. "gdking"; re-read only when a new save lands. */
function readDefeatedBosses() {
  const filePath = findNewestWorldMetadataFile();
  if (!filePath) return [];
  try {
    const modifiedAtMs = fs.statSync(filePath).mtimeMs;
    if (filePath !== lastRead.filePath || modifiedAtMs !== lastRead.modifiedAtMs) {
      lastRead = { filePath, modifiedAtMs, defeatedBossIds: readDefeatedBossIds(decompressWorldMetadata(filePath)) };
    }
  } catch {
    // A save being written right now is read on the next scrape.
  }

  return lastRead.defeatedBossIds;
}

module.exports = { readDefeatedBosses };
