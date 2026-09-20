"use strict";

const { SERVER_ARGS } = require("./config");

// The world rules the server was started with, e.g. "resources more". Absent = default world.
function readWorldModifiers() {
  return [...SERVER_ARGS.matchAll(/-modifier\s+(\S+)\s+(\S+)/g)].map(([, name, value]) => ({ name, value }));
}

module.exports = { readWorldModifiers };
