# n8n

[n8n](https://docs.n8n.io/) workflow automation, one Deployment in the `n8n` namespace.
`make n8n` installs or updates it; `N8N_HOST` in `infrastructure/site.env` sets the hostname.

- **Access:** LAN-only, via this namespace's own `n8n-lan-only@kubernetescrd` middleware.
  Traefik resolves middleware names inside the router's namespace, so this is a
  second copy of monitoring's, not a reference to it.
- **Accounts:** the first visit to the editor creates the owner account. There is
  no provisioned password, and anyone on the LAN who reaches it first claims it.
- **Database:** SQLite on a `local-path` volume at `/home/node/.n8n`. One instance,
  no Postgres and no queue mode.
- **Credentials** are encrypted with the `n8n-encryption-key` Secret, created once
  by `install.sh`. Restoring the volume without that Secret leaves every stored
  credential unreadable, so back them up together.
- **Executions** prune themselves at n8n's defaults: 14 days or 10000 runs.

## Memory

Node sizes its heap from the host's total RAM, not the container limit, so
`NODE_OPTIONS=--max-old-space-size` is set; without it the pod grows past its
limit and the kernel kills it. It settles around 350 MiB, against a 768 MiB limit.
Boot runs database migrations and briefly uses more.

## Deprecation warnings

n8n warns at boot about defaults that will change in a later version. Each one is
set explicitly in `n8n.yaml` so an image bump can't move it, which also keeps the
boot log quiet enough that a new warning is visible. One is left standing:

- **`N8N_RUNNERS_MODE=internal`** runs workflow code in the main process. External
  mode isolates it, but needs a second container from `n8nio/runners` matching the
  n8n version, plus a shared `N8N_RUNNERS_AUTH_TOKEN`
  ([task runners](https://docs.n8n.io/hosting/configuration/task-runners/)).
  Internal mode is slated for removal, so this becomes required at some point.

## Known limits

- **No Python Code nodes.** The image carries no Python 3, so n8n logs
  `Failed to start Python task runner`. JavaScript Code nodes work.
- **Inbound webhooks from the internet don't reach it** while access is LAN-only.
  Going public means a DNS record, a certificate, `N8N_SECURE_COOKIE` back to
  `true`, and dropping the LAN-only middleware for real authentication.
