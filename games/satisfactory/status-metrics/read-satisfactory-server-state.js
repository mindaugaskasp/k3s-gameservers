"use strict";

const { GameDig } = require("gamedig");
const { GAME, HOST, PORT } = require("../../../game-server/status-metrics/config");
const { SATISFACTORY_API_TOKEN } = require("./config");

/** Queries the server like the core would, then fills in what gamedig's satisfactory protocol leaves out. */
async function readSatisfactoryServerState() {
  const state = await GameDig.query({
    type: GAME,
    host: HOST,
    port: PORT,
    maxRetries: 1,
    ...(SATISFACTORY_API_TOKEN ? { token: SATISFACTORY_API_TOKEN } : {}),
  });
  // The HTTPS API reports the player count without names, and gamedig leaves the
  // players list empty, so the count becomes that many nameless players.
  state.players = Array.from({ length: state.numplayers || 0 }, () => ({ name: "" }));
  return state;
}

module.exports = { readSatisfactoryServerState };
