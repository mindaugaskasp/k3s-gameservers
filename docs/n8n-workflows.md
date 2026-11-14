# n8n workflows

What each workflow does and how its credentials are granted. The service itself is in
[n8n.md](n8n.md).

## Workflows

`infrastructure/n8n/workflows/*.json` is the source of truth; `make n8n-workflows`
loads them, updating in place by their stable ids. They arrive inactive, so activate
one in the editor after reading it. Editor changes live only in n8n's database until
they are exported back into the repo.

| Workflow | Runs | Sends |
|---|---|---|
| `cluster-daily-digest` | every day 07:00 | one summary of cluster checks |
| `weekly-calendar-overview` | Mondays 07:00 | the next 7 days of calendar commitments |
| `renovate-watcher` | every day 07:30 | open dependency PRs, worst state first |

Both email over Gmail SMTP, as an HTML table with a plain-text part for clients that
drop it. Grafana's alert rules stay the event-driven half, so the digest is the
heartbeat and reports on a quiet day too.

The digest's checks are of two kinds, set in its `Build checks` node. An `objects`
check queries one series per offending object and the mail names it
(`namespace/pod/container`, with the reason or count beside it); a `value` check
returns one number compared against `warnAbove`/`warnBelow`. When anything is wrong
it also books a 30-minute "Check cluster health" event an hour out, listing what
failed. A branch that returns no items books nothing, so an all-clear run is silent.
A problem that persists books one event per day, which is the intent.

**Host values are substituted at import, not read at run time.** n8n blocks `$env`
in nodes and expressions (`N8N_BLOCK_ENV_ACCESS_IN_NODE`), and unblocking it would
expose `N8N_ENCRYPTION_KEY` to every workflow. So `make n8n-workflows` reads
`infrastructure/site.env`, writes `GRAFANA_HOST`, `GMAIL_ADDRESS` and `N8N_TIMEZONE`
into the workflows, and imports the secrets as encrypted n8n credentials. The repo's
copies hold none of them.

The watcher finds pull requests with one search, `author:app/renovate` across
`GITHUB_OWNER`: the bot is the marker, where a label only catches repositories whose
config sets one. Private repositories need the token, as the anonymous API cannot
see them, and a classic token needs the whole `repo` scope -- `repo:status` and
`repo_deployment` alone return 404. It then reads each PR's
`mergeable_state`, so `dirty` reads as a conflict and `unstable` as failing checks.
`GITHUB_TOKEN` only ever reads.

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
