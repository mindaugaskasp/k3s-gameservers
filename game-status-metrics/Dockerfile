FROM node:24-alpine
WORKDIR /app
COPY package.json ./
RUN npm install --omit=dev
COPY *.js ./
COPY metrics ./metrics/
COPY migrations ./migrations/
EXPOSE 9101
USER node
CMD ["node", "index.js"]
