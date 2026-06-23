SHELL := /bin/bash

HOST_ARG := $(or $(HOST),$(word 2,$(MAKECMDGOALS)))
ifeq ($(firstword $(MAKECMDGOALS)),setup-linux)
EXTRA_SETUP_LINUX_GOALS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
$(EXTRA_SETUP_LINUX_GOALS):
	@:
endif

.PHONY: help setup-linux

help:
	@printf 'Targets:\n'
	@printf '  setup-linux Bootstrap a remote Linux host (HOST=user@host or make setup-linux user@host)\n'

setup-linux:
	@test -n "$(HOST_ARG)" || (echo "usage: make setup-linux HOST=user@host"; echo "   or: make setup-linux user@host"; exit 1)
	./setup-remote-linux "$(HOST_ARG)"
