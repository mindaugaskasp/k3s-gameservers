# ryshe/terraria plus curl, which the shared Discord hook (post-discord-embed.sh) posts with.
FROM docker.io/ryshe/terraria:latest@sha256:8a4f775d02ad5d2c9eedc1d175a2ae8e17e79dee5b42aa16d1f265245155bdf6
RUN apt-get update \
  && apt-get install -y --no-install-recommends curl ca-certificates \
  && rm -rf /var/lib/apt/lists/*
