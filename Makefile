PREFIX ?= $(HOME)/.local
BINDIR := $(PREFIX)/bin
ROOT   := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
TARGET := $(BINDIR)/kitty-sessionizer

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this text
	@grep -hE '^[a-z-]+:.*?## ' $(MAKEFILE_LIST) \
	  | awk -F':.*?## ' '{ printf "  %-10s %s\n", $$1, $$2 }'

.PHONY: deps
deps: ## Check that every tool in lib/config.zsh is installed
	@zsh -c 'set -u; KS_ROOT="$(ROOT)"; KS_LIB="$$KS_ROOT/lib"; \
	  source "$$KS_LIB/bootstrap.zsh"; ks_use config; missing=0; \
	  for var in KS_KITTEN KS_FD KS_FZF KS_GUM KS_TREE KS_BAT KS_GIT KS_EDITOR; do \
	    ( ks_require_tools "$$var" ) || missing=1; \
	  done; \
	  (( ! missing )) || { print -ru2 -- "install the missing tools, or export the KS_* variable with another path"; exit 1 }; \
	  print -r -- "all tools found"'

.PHONY: install
install: deps ## Check the tools, then link the dispatcher into PREFIX/bin
	@mkdir -p "$(BINDIR)"
	@if [ -e "$(TARGET)" ] && [ ! -L "$(TARGET)" ]; then \
	    mv "$(TARGET)" "$(TARGET).bak"; \
	    echo "kept the previous file as $(TARGET).bak"; \
	fi
	@ln -sfn "$(ROOT)/bin/kitty-sessionizer" "$(TARGET)"
	@echo "linked $(TARGET)"
	@echo
	@echo "Add these lines to kitty.conf:"
	@echo '  map alt+shift+p launch --type=overlay --title "Project Selector" /bin/zsh $(TARGET) open'
	@echo '  map alt+shift+d launch --type=overlay --title "Delete Sessions" /bin/zsh $(TARGET) delete'
	@echo '  map alt+shift+c launch --type=overlay --title "Clone Repository" /bin/zsh $(TARGET) clone'
	@echo '  map alt+shift+[ remote_control_script /bin/zsh $(TARGET) prev'
	@echo '  map alt+shift+] remote_control_script /bin/zsh $(TARGET) next'
	@echo '  map alt+shift+backslash remote_control_script /bin/zsh $(TARGET) last'
	@echo '  watcher $(ROOT)/kitty/autosave.py'

.PHONY: uninstall
uninstall: ## Remove the link from PREFIX/bin
	@rm -f "$(TARGET)"
	@echo "removed $(TARGET)"

.PHONY: check
check: ## Parse every script
	@for f in bin/kitty-sessionizer lib/*.zsh libexec/*.zsh; do \
	    zsh -n "$$f" || exit 1; \
	done
	@echo "all scripts parse"

.PHONY: test
test: check ## Run the tests
	@zsh tests/test_session.zsh
	@PYTHONDONTWRITEBYTECODE=1 kitty +launch tests/test_autosave.py
