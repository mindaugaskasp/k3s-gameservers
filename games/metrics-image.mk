# The status-metrics image the three games share. Include after REPO_ROOT is set.
# Tagging by the exporter's last commit replaces the pod when its source changes and
# leaves a running game alone when it does not. "-dirty" means uncommitted: commit first.
STATUS_METRICS_DIR := $(REPO_ROOT)/game-status-metrics
STATUS_METRICS_TAG := $(shell git -C $(REPO_ROOT) log -1 --format=%h -- game-status-metrics)$(shell git -C $(REPO_ROOT) status --porcelain -- game-status-metrics | grep -q . && echo -dirty)
STATUS_METRICS_IMAGE := localhost:30500/k3s-gameservers/game-status-metrics:$(STATUS_METRICS_TAG)
