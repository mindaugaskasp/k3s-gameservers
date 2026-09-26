# Player database commands, run inside the game's status-metrics container, which holds
# the database. Included by game.mk. The file's path comes from the exporter's config.js, its one definition.
PLAYER_DATABASE_EXEC := kubectl -n $(NAMESPACE) exec $(RELEASE)-0 -c status-metrics --

## Open a read-only SQLite shell on the player database
##   SQL='query'   run one query and print the result instead of opening a shell
##   e.g. make read-player-db SQL='select count(*) from player'
read-player-db:
	@db=$$($(PLAYER_DATABASE_EXEC) node -p 'require("/app/game-server/status-metrics/config").PLAYERS_DATABASE_FILE') \
		|| { echo "$(RELEASE)-0 is not running: scale it up first" >&2; exit 1; }; \
	if [ -n "$(SQL)" ]; then $(PLAYER_DATABASE_EXEC) sqlite3 -readonly -box "$$db" "$(SQL)"; \
	else kubectl -n $(NAMESPACE) exec -it $(RELEASE)-0 -c status-metrics -- sqlite3 -readonly -box "$$db"; fi

## Zero every player's time played, deaths and the game's own stats (asks first)
reset-player-stats:
	@read -r -p "Zero time played, deaths and the game's own stats for every $(RELEASE) player? [y/N] " answer; \
	[ "$$answer" = y ] || { echo "Cancelled, nothing changed."; exit 0; }; \
	$(PLAYER_DATABASE_EXEC) node /app/game-server/status-metrics/reset-player-stats.js
