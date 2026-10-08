"use strict";

// gamedig's satisfactory protocol carries the HTTPS API's QueryServerState answer
// in state.raw.http; the latest one feeds the satisfactory_* metric lines.
let lastGameState = null;

function storeSatisfactoryQueryAnswer(state) {
  lastGameState = state.raw?.http?.serverGameState ?? lastGameState;
}

function readSatisfactoryGameStateAnswer() {
  return lastGameState;
}

module.exports = { storeSatisfactoryQueryAnswer, readSatisfactoryGameStateAnswer };
