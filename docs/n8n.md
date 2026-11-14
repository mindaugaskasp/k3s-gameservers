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

## Workflows

`infrastructure/n8n/workflows/*.json` is the source of truth; `make n8n-workflows`
loads them, updating in place by their stable ids. They arrive inactive, so activate
one in the editor after reading it. Editor changes live only in n8n's database until
they are exported back into the repo.

| Workflow | Runs | Sends |
|---|---|---|
| `cluster-daily-digest` | every day 07:00 | one summary of cluster checks |
| `weekly-calendar-overview` | Mondays 07:00 | the next 7 days of calendar commitments |

Both email over Gmail SMTP. The digest's thresholds sit beside each check in its
`Build checks` node; Grafana's alert rules stay the event-driven half, so the digest
is the heartbeat and reports on a quiet day too.

**Host values are substituted at import, not read at run time.** n8n blocks `$env`
in nodes and expressions (`N8N_BLOCK_ENV_ACCESS_IN_NODE`), and unblocking it would
expose `N8N_ENCRYPTION_KEY` to every workflow. So `make n8n-workflows` reads
`infrastructure/site.env`, writes `GRAFANA_HOST`, `GMAIL_ADDRESS` and `N8N_TIMEZONE`
into the workflows, and imports the secrets as encrypted n8n credentials. The repo's
copies hold none of them.

## Connecting Gmail and Google Calendar

1. **App password** for SMTP: Google account, 2-step verification on, then an app
   password. Put it in `infrastructure/site.env` as `GMAIL_APP_PASSWORD` and re-run
   `make n8n-workflows`.
2. **OAuth client** for Calendar: a Google Cloud project, OAuth client of type Web
   application, its id and secret in `site.env`
   (`GOOGLE_OAUTH_CLIENT_ID`/`GOOGLE_OAUTH_CLIENT_SECRET`).
3. **Grant the token.** Google refuses a redirect URI that is neither HTTPS nor
   localhost, and this n8n is plain HTTP on the LAN. `localhost` is exempt
   ([Google](https://developers.google.com/identity/protocols/oauth2/web-server)), so
   grant it through a port-forward: set `N8N_EDITOR_BASE_URL` to
   `http://localhost:5678/`, `kubectl -n n8n port-forward deploy/n8n 5678:5678`,
   register `http://localhost:5678/rest/oauth2-credential/callback` on the client,
   open the credential in the editor at `localhost:5678` and connect. Then put
   `N8N_EDITOR_BASE_URL` back. Refreshes happen server-side, so the token keeps working.
4. **Publish the OAuth app.** While its publishing status is Testing, Google expires
   refresh tokens after 7 days, which breaks a weekly workflow.

## Memory

Node sizes its heap from the host's total RAM, not the container limit, so
`NODE_OPTIONS=--max-old-space-size` is set; without it the pod grows past its
limit and the kernel kills it. It settles around 350 MiB.

The limit is larger than that because the n8n CLI (`make n8n-workflows`) starts a
second n8n **inside the serving container**, so both count against one limit; import
peaks around 560 MiB. The CLI's own heap is capped in `import-workflows.sh`.
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
