# Migrating the running `vhserver` Valheim instance into k3s

This is a manual, checked procedure rather than a script, because it moves
live world save data — a mistake here risks the world save, not just
uptime. Do not automate/run this end-to-end unattended.

## Before you start

- Confirm the target `gameservermanagers/gameserver:vh` image's expected
  data layout matches what's below (check its Docker Hub page/readme) —
  it's built from LGSM's install scripts, so it should mirror
  `~/lgsm` and `~/serverfiles` on this host, but verify before trusting it
  with the only copy of the world.
- Make a backup first regardless: LGSM already has one —
  `~/lgsm/backup/` — confirm a recent one exists (`vhserver backup` if
  not) before touching anything.
- Pick a maintenance window; players will be disconnected.

## Steps

1. **Stop the bare-metal server** so the save files are quiescent:
   ```
   ./vhserver stop
   ```
2. **Deploy the pod without starting real traffic yet** — install k3s and
   monitoring first (`scripts/install-k3s.sh`, `scripts/install-monitoring.sh`),
   then deploy Valheim with its PVC:
   ```
   ./scripts/deploy-game.sh valheim \
     --set-string secrets.serverpassword="$VALHEIM_SERVER_PASSWORD" \
     --set-string secrets.discordwebhook="$VALHEIM_DISCORD_WEBHOOK"
   kubectl -n games scale statefulset/valheim --replicas=0
   ```
3. **Copy world data into the PVC.** With the StatefulSet scaled to 0, the
   PVC exists but nothing is mounting it read-write from a running game
   process. Start a throwaway pod that mounts the same PVC:
   ```
   kubectl -n games run copy-shell --rm -it --restart=Never \
     --image=alpine --overrides='{"spec":{"containers":[{"name":"copy-shell","image":"alpine","command":["sleep","3600"],"volumeMounts":[{"name":"data","mountPath":"/data"}]}],"volumes":[{"name":"data","persistentVolumeClaim":{"claimName":"data-valheim-0"}}]}}' -- sh
   ```
   Then, from the host, in another shell:
   ```
   kubectl -n games cp ~/lgsm/config-lgsm/vhserver games/copy-shell:/data/lgsm/config-lgsm/vhserver
   kubectl -n games cp ~/serverfiles/Saved games/copy-shell:/data/serverfiles/Saved
   ```
   (Adjust source/destination paths once you've confirmed the actual
   layout the `gameservermanagers/gameserver:vh` image expects — see the
   verification step above.)
4. **Scale back up and watch logs:**
   ```
   kubectl -n games scale statefulset/valheim --replicas=1
   kubectl -n games logs -f valheim-0 -c gameserver
   ```
5. **Verify** the world loads with the expected name/save (check logs and,
   once up, query it — `curl` the Grafana dashboard or
   `kubectl -n games port-forward svc/valheim-metrics 9101:9101 && curl
   localhost:9101/metrics`) before decommissioning the bare-metal instance.
6. Only after a successful verified run should the bare-metal `vhserver`
   LGSM instance and its systemd/cron jobs (if any) be retired.
