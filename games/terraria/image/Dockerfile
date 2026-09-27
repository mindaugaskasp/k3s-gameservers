# ryshe/terraria plus curl, which the shared Discord hook (post-discord-embed.sh) posts with.
FROM docker.io/ryshe/terraria:latest
RUN apt-get update \
  && apt-get install -y --no-install-recommends curl ca-certificates \
  && rm -rf /var/lib/apt/lists/*
