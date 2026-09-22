FROM node:24-alpine
WORKDIR /app
# The sqlite3 CLI, for `make read-player-db`.
RUN apk add --no-cache sqlite
COPY package.json package-lock.json ./
RUN npm ci --omit=dev --no-audit --no-fund
COPY *.js ./
COPY metrics ./metrics/
COPY migrations ./migrations/
EXPOSE 9101
USER node
CMD ["node", "index.js"]
