#!/usr/bin/env bash
# Host firewall (ufw): SSH from anywhere; everything from the LAN and k3s pods/services; no other
# inbound. Routed traffic (game NodePorts, Traefik 80/443) is left open. Safe to re-run.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

lan_cidr=$(sed -n 's/^LAN_CIDR=//p' monitoring/.env 2>/dev/null)
[ -n "$lan_cidr" ] || { echo "Missing LAN_CIDR in monitoring/.env" >&2; exit 1; }

sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw default allow routed
sudo ufw allow 22/tcp comment 'ssh'
sudo ufw allow from "$lan_cidr" comment 'LAN'
sudo ufw allow from 10.42.0.0/16 comment 'k3s pods'
sudo ufw allow from 10.43.0.0/16 comment 'k3s services'
sudo ufw --force enable
sudo ufw status verbose
