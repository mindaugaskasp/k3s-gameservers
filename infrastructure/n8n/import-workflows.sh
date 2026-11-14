#!/usr/bin/env bash
# Loads infrastructure/n8n/workflows/*.json into the running n8n, with the host's own
# values from infrastructure/site.env. n8n blocks $env in nodes and expressions, so
# hostnames and addresses are substituted into the workflow before import rather than
# read at run time; secrets become encrypted n8n credentials. Each workflow carries a
# stable id, so re-running updates it in place. Imported workflows arrive inactive.
set -euo pipefail
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}" # /etc/rancher/k3s/k3s.yaml is root-only
cd "$(dirname "${BASH_SOURCE[0]}")/../.."

[ -f infrastructure/site.env ] || { echo "Missing infrastructure/site.env" >&2; exit 1; }
read_setting() { sed -n "s/^$1=//p" infrastructure/site.env; }

grafana_host=$(read_setting GRAFANA_HOST)
gmail_address=$(read_setting GMAIL_ADDRESS)
timezone=$(read_setting N8N_TIMEZONE)
gmail_app_password=$(read_setting GMAIL_APP_PASSWORD)
google_client_id=$(read_setting GOOGLE_OAUTH_CLIENT_ID)
google_client_secret=$(read_setting GOOGLE_OAUTH_CLIENT_SECRET)

for required in grafana_host gmail_address timezone; do
  [ -n "${!required}" ] || { echo "Missing ${required^^} in infrastructure/site.env" >&2; exit 1; }
done

# The CLI starts a second n8n inside the serving container; cap its heap so the
# two together stay under the container limit.
cli="env NODE_OPTIONS=--max-old-space-size=384"
pod=$(kubectl -n n8n get pod -l app.kubernetes.io/name=n8n -o jsonpath='{.items[0].metadata.name}')
[ -n "$pod" ] || { echo "No n8n pod running; deploy it first with make n8n" >&2; exit 1; }

# n8n encrypts credentials on import, so no secret sits in a workflow or in git.
import_credential() {
  printf '%s' "$1" | kubectl -n n8n exec -i "$pod" -- sh -c 'umask 077; cat > /tmp/credential.json'
  kubectl -n n8n exec "$pod" -- $cli n8n import:credentials --input=/tmp/credential.json
  kubectl -n n8n exec "$pod" -- rm -f /tmp/credential.json
}

if [ -n "$gmail_app_password" ]; then
  import_credential "$(printf '[{"id":"gmailsmtp","name":"Gmail SMTP","type":"smtp","data":{"host":"smtp.gmail.com","port":587,"secure":false,"user":"%s","password":"%s"}}]' \
    "$gmail_address" "$gmail_app_password")"
else
  echo "No GMAIL_APP_PASSWORD in infrastructure/site.env: skipping the Gmail SMTP credential, so the email steps will fail until it is set" >&2
fi

# Only the client half can be imported; the token comes from the browser consent flow,
# so open the credential in the editor and press "Connect my account" once.
if [ -n "$google_client_id" ] && [ -n "$google_client_secret" ]; then
  import_credential "$(printf '[{"id":"googlecalendar","name":"Google Calendar","type":"googleCalendarOAuth2Api","data":{"clientId":"%s","clientSecret":"%s"}}]' \
    "$google_client_id" "$google_client_secret")"
else
  echo "No GOOGLE_OAUTH_CLIENT_ID/SECRET in infrastructure/site.env: skipping the Google Calendar credential, so the calendar step will fail until it is connected" >&2
fi

for workflow in infrastructure/n8n/workflows/*.json; do
  sed -e "s|GRAFANA_HOST|$grafana_host|g" \
      -e "s|GMAIL_ADDRESS|$gmail_address|g" \
      -e "s|N8N_TIMEZONE|$timezone|g" "$workflow" \
    | kubectl -n n8n exec -i "$pod" -- sh -c 'cat > /tmp/workflow.json'
  kubectl -n n8n exec "$pod" -- $cli n8n import:workflow --input=/tmp/workflow.json
  kubectl -n n8n exec "$pod" -- rm -f /tmp/workflow.json
  echo "imported $(basename "$workflow")"
done
