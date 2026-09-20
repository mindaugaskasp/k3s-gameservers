# Adding a game

Broad checklist; the details live in each game's own doc and chart.

## 1. Pick the image

Prefer a maintained image that handles steamcmd, updates and backups itself.
Read its env vars, volumes, ports and hooks before writing the chart — those
decide how much the chart has to do.

## 2. Chart

1. Copy the closest `charts/<game>-server/` and rename everything in it.
2. Map the image's env vars to values: server settings, passwords, alerts,
   updates, backups, ports, persistence, resources.
3. Keep the shared pieces: live-replica `lookup`, status-metrics sidecar,
   NodePort service, Discord lifecycle hooks, optional VPA.
4. Add whatever the image can't do itself (update CronJob, ini patching,
   log tailing) only if it's actually missing.

## 3. Game directory

Add `games/<game>/` with `values.override.yaml` (site settings, sizing),
`.env.example` (secrets), `Makefile` (same target names as the other games),
`restore-helper-pod.yaml` and the systemd data-sync units.

## 4. Monitoring

1. Add a scrape job for the game's metrics Service in
   `monitoring/prometheus.yaml`, then `kubectl apply -k monitoring` and
   restart Prometheus — the jobs are static, one per game.
2. Copy another game's `grafana/dashboards/`, swap the game label, pod and
   PVC selectors, and drop panels that game can't feed.
3. `make dashboards`, then restart Grafana once: it only picks up a *new*
   dashboard folder at startup.

## 5. Networking

Pick ports the router forwards and the NodePort range covers, then add them
to [architecture.md](architecture.md#networking).

## 6. Deploy and verify

`make push-metrics-image && make deploy`, then check, in this order:
the first boot finishes, `make players` reports, Discord posts start/stop,
a backup appears, `make restore-backup` works, dashboards show data.

## 7. Website

Add the game to the servers-web watch list (`<gamedig type>:<port>`) and its
artwork, redeploy it, and confirm the site shows the server online.

## 8. Docs and sizing

Write `docs/<game>.md`, add the game to the README layout and docs lists,
and size requests so games stay one-at-a-time
([architecture.md](architecture.md#sizing)).
