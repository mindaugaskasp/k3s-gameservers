# The game's own status-metrics image: game-server/status-metrics/ plus games/<game>/status-metrics/.
# Included by game.mk. Tagging by the last commit touching either replaces the pod
# when its source changes and leaves the game alone when it does not. "-dirty" means uncommitted.
STATUS_METRICS_DIR := $(REPO_ROOT)/game-server/status-metrics
GAME_STATUS_METRICS_DIR := games/$(notdir $(CURDIR))/status-metrics
STATUS_METRICS_SOURCES := game-server/status-metrics $(GAME_STATUS_METRICS_DIR)
STATUS_METRICS_TAG := $(shell git -C $(REPO_ROOT) log -1 --format=%h -- $(STATUS_METRICS_SOURCES))$(shell git -C $(REPO_ROOT) status --porcelain -- $(STATUS_METRICS_SOURCES) | grep -q . && echo -dirty)
STATUS_METRICS_IMAGE := localhost:30500/k3s-gameservers/$(notdir $(CURDIR))-status-metrics:$(STATUS_METRICS_TAG)
STATUS_METRICS_BUILD_FLAGS := --build-context game=$(REPO_ROOT)/$(GAME_STATUS_METRICS_DIR) \
	--build-arg GAME_DIR=$(GAME_STATUS_METRICS_DIR)
