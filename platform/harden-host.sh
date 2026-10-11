#!/usr/bin/env bash
# Host hardening: restrict cluster/admin ports to the LAN. Run: sudo bash harden-host.sh
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "run with sudo"; exit 1; }
LAN=$(grep '^LAN_CIDR=' "$(dirname "$0")/site.env" | cut -d= -f2)
[ -n "$LAN" ] || { echo "LAN_CIDR missing from site.env"; exit 1; }

echo "== ufw before =="
ufw status numbered

ufw insert 1 allow from "$LAN" to any port 22 proto tcp
ufw insert 2 allow from "$LAN" to any port 6443 proto tcp
ufw insert 3 allow from "$LAN" to any port 10250 proto tcp
ufw deny in to any port 8472 proto udp
ufw deny in to any port 10250 proto tcp
ufw deny in to any port 6443 proto tcp
ufw delete allow 22/tcp 2>/dev/null || true
ufw delete allow OpenSSH 2>/dev/null || true

echo "== ufw after =="
ufw status verbose

echo "== account/ssh status (review, no changes made) =="
passwd -S nas root
sshd -T | grep -Ei 'permitrootlogin|passwordauthentication|kbdinteractiveauthentication'
cat /etc/ssh/sshd_config.d/50-cloud-init.conf
