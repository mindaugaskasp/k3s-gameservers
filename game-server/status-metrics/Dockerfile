# One image per game: this folder, the part every game shares, plus the game's own
# games/<game>/status-metrics, passed in as the "game" build context (game-server/make/metrics-image.mk).
FROM docker.io/library/node:26-alpine@sha256:8996bb5821d62a8fd9bb27c1cb07462f3fdce6e47d640c6a881ead0b064ce216
ARG GAME_DIR
WORKDIR /app
# The sqlite3 CLI, for `make read-player-db`.
RUN apk add --no-cache sqlite
COPY package.json package-lock.json ./
RUN npm ci --omit=dev --no-audit --no-fund
# Laid out as in the repo, so a game's relative requires of the core resolve the same.
COPY *.js ./game-server/status-metrics/
COPY metrics ./game-server/status-metrics/metrics/
COPY migrations ./game-server/status-metrics/migrations/
COPY --from=game . ./${GAME_DIR}/
ENV GAME_DIR=/app/${GAME_DIR}
EXPOSE 9101
USER node
CMD ["node", "game-server/status-metrics/index.js"]
