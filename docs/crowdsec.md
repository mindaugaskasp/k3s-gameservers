# CrowdSec

[CrowdSec](https://docs.crowdsec.net/) bans IPs that scan or attack anything
behind Traefik: the website, Grafana and every other Ingress.

| Piece | Where |
|---|---|
| Agent (DaemonSet): reads Traefik's access log, runs the [`crowdsecurity/traefik`](https://app.crowdsec.net/hub/author/crowdsecurity/collections/traefik) scenarios | `crowdsec/values.yaml` |
| LAPI (Deployment): stores bans, pulls the community blocklist | `crowdsec/values.yaml` |
| [Bouncer plugin](https://plugins.traefik.io/plugins/6335346ca4caa9ddeffda116/crowdsec-bouncer-traefik-plugin) on both entry points: returns 403 to banned IPs | `crowdsec/bouncer-middleware.yaml`, `install/k3s/traefik-config.yaml` |
| Dashboard, Grafana's Website folder | `crowdsec/grafana/dashboards/` |

Install with `make crowdsec`, **before** Traefik loads `traefik-config.yaml`:
every route fails while `crowdsec-bouncer@kubernetescrd` is missing.

- **Bouncer key:** the `bouncer-key` Secret, generated once by the install script.
- **Fails open:** if the LAPI is down, requests pass unchecked.
- **Plugin download:** Traefik fetches the plugin from plugins.traefik.io on every start.
- **LAN:** private ranges are never banned (`crowdsecurity/whitelists`).

## Commands

Run in the LAPI pod: `kubectl -n crowdsec exec deploy/crowdsec-lapi -- cscli ...`

- `decisions list`: current bans (`-a` includes the community blocklist).
- `decisions add --ip <ip> --duration 24h`: ban by hand, or `make ban-ip <ip> [hours]`.
- `decisions delete --ip <ip>`: unban, or `make unban-ip <ip>`.
- `alerts list`: what was detected, and from where.
- `metrics`: log lines read, scenarios triggered, bouncer calls.
