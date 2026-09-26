# One image per game: this folder, the part every game shares, plus the game's own
# games/<game>/status-metrics, passed in as the "game" build context (games/metrics-image.mk).
FROM node:24-alpine
ARG GAME_DIR
WORKDIR /app
# The sqlite3 CLI, for `make read-player-db`.
RUN apk add --no-cache sqlite
COPY package.json package-lock.json ./
RUN npm ci --omit=dev --no-audit --no-fund
# Laid out as in the repo, so a game's relative requires of the core resolve the same.
COPY *.js ./game-status-metrics/
COPY metrics ./game-status-metrics/metrics/
COPY --from=game . ./${GAME_DIR}/
ENV GAME_DIR=/app/${GAME_DIR}
EXPOSE 9101
USER node
CMD ["node", "game-status-metrics/index.js"]
