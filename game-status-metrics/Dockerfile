FROM node:24-alpine
WORKDIR /app
# The sqlite3 CLI, for `make read-player-db`.
RUN apk add --no-cache sqlite
COPY package.json ./
RUN npm install --omit=dev
COPY *.js ./
COPY metrics ./metrics/
COPY migrations ./migrations/
EXPOSE 9101
USER node
CMD ["node", "index.js"]
