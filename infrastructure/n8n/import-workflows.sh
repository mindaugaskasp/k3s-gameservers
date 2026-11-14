#!/usr/bin/env bash
# Loads infrastructure/n8n/workflows/*.json into the running n8n, with the host's own
# values from infrastructure/site.env: the Discord webhook becomes an encrypted n8n
# credential, and GRAFANA_HOST is substituted in (n8n blocks $env, so a workflow cannot
# read it at run time). Each file carries a stable id, so re-running updates in place.
# Imported workflows arrive inactive: activate them in the editor.
set -euo pipefail
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}" # /etc/rancher/k3s/k3s.yaml is root-only
cd "$(dirname "${BASH_SOURCE[0]}")/../.."

[ -f infrastructure/site.env ] || { echo "Missing infrastructure/site.env" >&2; exit 1; }
grafana_host=$(sed -n 's/^GRAFANA_HOST=//p' infrastructure/site.env)
discord_webhook=$(sed -n 's/^ALERTS_DISCORD_WEBHOOK_URL=//p' infrastructure/site.env)
[ -n "$grafana_host" ] || { echo "Missing GRAFANA_HOST in infrastructure/site.env" >&2; exit 1; }
[ -n "$discord_webhook" ] || { echo "Missing ALERTS_DISCORD_WEBHOOK_URL in infrastructure/site.env" >&2; exit 1; }

pod=$(kubectl -n n8n get pod -l app.kubernetes.io/name=n8n -o jsonpath='{.items[0].metadata.name}')
[ -n "$pod" ] || { echo "No n8n pod running; deploy it first with make n8n" >&2; exit 1; }

# n8n encrypts the credential on import, so the webhook never sits in a workflow or in git.
printf '[{"id":"discordalertswebhook","name":"Discord alerts webhook","type":"discordWebhookApi","data":{"webhookUri":"%s"}}]' \
  "$discord_webhook" | kubectl -n n8n exec -i "$pod" -- sh -c 'umask 077; cat > /tmp/credential.json'
kubectl -n n8n exec "$pod" -- n8n import:credentials --input=/tmp/credential.json
kubectl -n n8n exec "$pod" -- rm -f /tmp/credential.json

for workflow in infrastructure/n8n/workflows/*.json; do
  sed "s|GRAFANA_HOST|$grafana_host|g" "$workflow" \
    | kubectl -n n8n exec -i "$pod" -- sh -c 'cat > /tmp/workflow.json'
  kubectl -n n8n exec "$pod" -- n8n import:workflow --input=/tmp/workflow.json
  kubectl -n n8n exec "$pod" -- rm -f /tmp/workflow.json
  echo "imported $(basename "$workflow")"
done
