SHELL := /bin/bash

HOST_ARG := $(or $(HOST),$(word 2,$(MAKECMDGOALS)))
ifeq ($(firstword $(MAKECMDGOALS)),setup-linux)
EXTRA_SETUP_LINUX_GOALS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
$(EXTRA_SETUP_LINUX_GOALS):
	@:
endif

MISE ?= mise
MISE_CONFIG := $(CURDIR)/config/mise/config.toml
MISE_RUN := MISE_GLOBAL_CONFIG_FILE=$(MISE_CONFIG) MISE_TRUSTED_CONFIG_PATHS=$(MISE_CONFIG) MISE_TASK_RUN_AUTO_INSTALL=false $(MISE)
SHFMT_FILES := config/zsh/*.zsh home/.zshrc home/.p10k.mise.zsh home/.p10k.zsh local/bin/tmux-sesh
TOML_FILES := '**/*.toml'

.PHONY: help install setup setup-linux tools test update dev-update fmt lint mise-tasks

help:
	@printf 'Targets:\n'
	@printf '  install     Install mise tools, then apply dotfiles\n'
	@printf '  setup       Apply dotfiles\n'
	@printf '  setup-linux Bootstrap a remote Linux host (HOST=user@host or make setup-linux user@host)\n'
	@printf '  tools       Install mise-managed tools\n'
	@printf '  test        Run TOML, shell, mise, and Neovim checks\n'
	@printf '  update      Update mise-managed tools\n'
	@printf '  dev-update  Update Homebrew and mise-managed tools\n'
	@printf '  fmt         Format TOML and shell files\n'
	@printf '  lint        Run format/lint checks only\n'

install: tools setup

setup:
	$(MISE_RUN) run setup

setup-linux:
	@test -n "$(HOST_ARG)" || (echo "usage: make setup-linux HOST=user@host"; echo "   or: make setup-linux user@host"; exit 1)
	$(MAKE) -C bootstrap setup-linux HOST="$(HOST_ARG)"

tools:
	$(MISE_RUN) install

test: lint
	$(MISE_RUN) run test

update:
	$(MISE_RUN) run update

dev-update:
	$(MISE_RUN) run dev-update

fmt:
	$(MISE_RUN) exec taplo -- taplo format --config taplo.toml $(TOML_FILES)
	$(MISE_RUN) exec shfmt -- shfmt -w $(SHFMT_FILES)

lint:
	$(MISE_RUN) exec taplo -- taplo format --config taplo.toml --check $(TOML_FILES)
	$(MISE_RUN) exec taplo -- taplo lint --config taplo.toml $(TOML_FILES)
	$(MISE_RUN) exec shfmt -- shfmt -d $(SHFMT_FILES)

mise-tasks:
	$(MISE_RUN) tasks
