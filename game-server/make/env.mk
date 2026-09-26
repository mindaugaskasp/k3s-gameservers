# The game's gitignored .env, which holds its passwords. Included by game.mk.

## Create .env from .env.example if missing, then show which values are set
##   Never overwrites an existing .env or prints its values; edit the file to set them.
init-env:
	@if [ -f .env ]; then echo "$(CURDIR)/.env already exists, left unchanged"; \
	else cp .env.example .env && chmod 600 .env && echo "Created $(CURDIR)/.env from .env.example"; fi
	@# As the shell reads it: a value ends at the first space, so "VAR=   # note" is empty.
	@grep -E '^[A-Z_]+=' .env | while IFS='=' read -r name value; do \
		value=$${value%%[[:space:]]*}; \
		if [ -n "$$value" ]; then echo "  $$name set"; else echo "  $$name empty"; fi; \
	done
