# Sourced by each game's `make deploy` after it loads .env: turns .env settings into Helm
# flags, collected in helm_flags for `helm upgrade --install ... "${helm_flags[@]}"`.
helm_flags=()

# Helm's --set splits on commas, so a value holding one would become two settings.
escape_commas() {
  printf '%s' "${1//,/\\,}"
}

# set_value <chart value> <value>: set even when empty, e.g. a password that may be cleared.
set_value() {
  helm_flags+=(--set-string "$1=$(escape_commas "$2")")
}

# set_value_if_given <chart value> <value>: an empty value keeps what values.override.yaml sets.
set_value_if_given() {
  [ -z "$2" ] || set_value "$1" "$2"
}

# set_discord_alerts <webhook URL>: alerts stay off without one.
set_discord_alerts() {
  if [ -n "$1" ]; then
    helm_flags+=(--set alerts.enabled=true)
    set_value alerts.discordWebhook "$1"
  else
    echo "note: no Discord webhook in .env, deploying without Discord alerts" >&2
  fi
}

# set_game_settings <"KEY=value,KEY=value">: each becomes gameSettings.KEY; spaces are dropped.
set_game_settings() {
  local game_setting
  local -a game_settings
  IFS=',' read -ra game_settings <<< "$1"
  for game_setting in "${game_settings[@]}"; do
    game_setting=${game_setting// }
    [ -n "$game_setting" ] || continue
    helm_flags+=(--set-string "gameSettings.${game_setting%%=*}=${game_setting#*=}")
  done
}
