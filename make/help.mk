# `make help [<command>]`, built from the `## ` lines above each target. Include before the first target.
HELP_SCRIPT := $(dir $(lastword $(MAKEFILE_LIST)))help.awk
HELP_TOPIC := $(word 2,$(MAKECMDGOALS))

# Goals after `help` are topics, not commands: a shell that does nothing runs them.
ifeq ($(firstword $(MAKECMDGOALS)),help)
ifneq ($(HELP_TOPIC),)
SHELL := true
.SILENT:
help: SHELL := /bin/bash
help: .SHELLFLAGS := -c
endif
endif

## List the commands, or explain one
##   make help <command>   its arguments, defaults and an example
help:
	@awk -v topic='$(HELP_TOPIC)' -f $(HELP_SCRIPT) $(MAKEFILE_LIST)
