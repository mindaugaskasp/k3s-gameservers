# Steam Workshop mods, kept in mods.json (JSON is YAML, so helm reads it with -f). Include
# at the END of the Makefile: its targets must not become the default goal.
STEAM_WORKSHOP_DETAILS := https://api.steampowered.com/ISteamRemoteStorage/GetPublishedFileDetails/v1/
ZOMBOID_APP_ID := 108600
DEPLOY_HINT := Run make deploy to apply it: that restarts the server, so check make players first.

define require-listed-mod
	@test -n "$(WORKSHOP_ID)" || { echo "Set WORKSHOP_ID=<id>; make mods lists them" >&2; exit 1; }
	@jq -e --arg id "$(WORKSHOP_ID)" 'any(.server.mods[]; .workshopId == $$id)' $(MODS_FILE) >/dev/null \
		|| { echo "$(WORKSHOP_ID) is not in $(MODS_FILE); make mods lists them" >&2; exit 1; }
endef

# $(1) is a jq filter over mods.json; $id is WORKSHOP_ID. Written whole, then renamed into place.
define update-mods-file
	@jq --arg id "$(WORKSHOP_ID)" '$(1)' $(MODS_FILE) > $(MODS_FILE).tmp && mv $(MODS_FILE).tmp $(MODS_FILE)
endef

## List the Workshop mods and whether each is enabled
mods:
	@jq -e '.server.mods | length > 0' $(MODS_FILE) >/dev/null || { echo "No mods yet: make add-mod WORKSHOP_ID=<id>"; exit 0; }; \
	jq -r '.server.mods[] | [(if .enabled then "on" else "off" end), .workshopId, (.modIds | join(";")), .title] | @tsv' \
		$(MODS_FILE) | column -t -s "$$(printf '\t')"

## Add a Steam Workshop mod by its item ID
##   WORKSHOP_ID=<id>   the number at the end of the mod's Workshop page URL (required)
##   MOD_ID=<a;b>       its in-game Mod ID(s), needed only when the page lists no "Mod ID:"
##   e.g. make add-mod WORKSHOP_ID=2169435993
add-mod:
	@test -n "$(WORKSHOP_ID)" || { echo "Set WORKSHOP_ID=<id>, the number at the end of the Workshop page URL" >&2; exit 1; }
	@! jq -e --arg id "$(WORKSHOP_ID)" 'any(.server.mods[]; .workshopId == $$id)' $(MODS_FILE) >/dev/null \
		|| { echo "$(WORKSHOP_ID) is already added; make mods lists them" >&2; exit 1; }
	@details=$$(curl -fsS --max-time 15 -d itemcount=1 -d 'publishedfileids[0]=$(WORKSHOP_ID)' $(STEAM_WORKSHOP_DETAILS) \
		| jq '.response.publishedfiledetails[0]') || { echo "Steam did not answer; try again" >&2; exit 1; }; \
	[ "$$(echo "$$details" | jq -r .consumer_app_id)" = $(ZOMBOID_APP_ID) ] \
		|| { echo "$(WORKSHOP_ID) is not a Project Zomboid Workshop item" >&2; exit 1; }; \
	if [ -n "$(MOD_ID)" ]; then mod_ids=$$(jq -cn --arg ids "$(MOD_ID)" '$$ids | split(";")'); \
	else mod_ids=$$(echo "$$details" | jq -c '[.description | scan("(?i)Mod ?ID:\\s*([^\\s\\[\\]]+)") | .[0]] \
		| reduce .[] as $$modId ([]; if index([$$modId]) then . else . + [$$modId] end)'); fi; \
	[ "$$mod_ids" != "[]" ] || { echo "The Workshop page names no Mod ID: add MOD_ID=<id> (the id= line in the mod's mod.info)" >&2; exit 1; }; \
	title=$$(echo "$$details" | jq -r .title); \
	jq --arg id "$(WORKSHOP_ID)" --arg title "$$title" --argjson modIds "$$mod_ids" \
		'.server.mods += [{ workshopId: $$id, modIds: $$modIds, title: $$title, enabled: true }]' \
		$(MODS_FILE) > $(MODS_FILE).tmp && mv $(MODS_FILE).tmp $(MODS_FILE); \
	echo "Added $$title (Mod ID $$(echo "$$mod_ids" | jq -r 'join(";")')). $(DEPLOY_HINT)"

## Stop loading a mod but keep it listed, so enable-mod brings it back
##   WORKSHOP_ID=<id>   as listed by make mods
disable-mod:
	$(require-listed-mod)
	$(call update-mods-file,(.server.mods[] | select(.workshopId == $$id) | .enabled) = false)
	@echo "Disabled $(WORKSHOP_ID). $(DEPLOY_HINT)"

## Load a disabled mod again
##   WORKSHOP_ID=<id>   as listed by make mods
enable-mod:
	$(require-listed-mod)
	$(call update-mods-file,(.server.mods[] | select(.workshopId == $$id) | .enabled) = true)
	@echo "Enabled $(WORKSHOP_ID). $(DEPLOY_HINT)"

## Remove a mod from the list; the server stops downloading and loading it
##   WORKSHOP_ID=<id>   as listed by make mods
remove-mod:
	$(require-listed-mod)
	$(call update-mods-file,.server.mods |= map(select(.workshopId != $$id)))
	@echo "Removed $(WORKSHOP_ID). $(DEPLOY_HINT)"
