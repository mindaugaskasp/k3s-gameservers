# One image per game: this folder, the part every game shares, plus the game's own
# games/<game>/status-metrics, passed in as the "game" build context (game-server/make/metrics-image.mk).
FROM docker.io/library/node:26-alpine@sha256:c6ad9e9c1d80f6eb607c26b4b0a132ff7a2344fad1c78ea3baa2a7d4c8de6d94
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
