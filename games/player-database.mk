# Player database commands, run inside the game's status-metrics container, which holds
# the database. Include at the END of a game's Makefile: its targets must not become the
# default goal. The file's path comes from the exporter's config.js, its one definition.
PLAYER_DATABASE_EXEC := kubectl -n $(NAMESPACE) exec $(RELEASE)-0 -c status-metrics --

read-player-db:
	@db=$$($(PLAYER_DATABASE_EXEC) node -p 'require("/app/config").PLAYERS_DATABASE_FILE') \
		|| { echo "$(RELEASE)-0 is not running: scale it up first" >&2; exit 1; }; \
	if [ -n "$(SQL)" ]; then $(PLAYER_DATABASE_EXEC) sqlite3 -readonly -box "$$db" "$(SQL)"; \
	else kubectl -n $(NAMESPACE) exec -it $(RELEASE)-0 -c status-metrics -- sqlite3 -readonly -box "$$db"; fi

reset-player-stats:
	@read -r -p "Zero time played, deaths and zombie kills for every $(RELEASE) player? [y/N] " answer; \
	[ "$$answer" = y ] || { echo "Cancelled, nothing changed."; exit 0; }; \
	$(PLAYER_DATABASE_EXEC) node /app/reset-player-stats.js
