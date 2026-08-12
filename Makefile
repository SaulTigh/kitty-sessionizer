PREFIX ?= $(HOME)/.local
BINDIR := $(PREFIX)/bin
ROOT   := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
TARGET := $(BINDIR)/kitty-sessionizer

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this text
	@grep -hE '^[a-z-]+:.*?## ' $(MAKEFILE_LIST) \
	  | awk -F':.*?## ' '{ printf "  %-10s %s\n", $$1, $$2 }'

.PHONY: install
install: ## Link the dispatcher into PREFIX/bin
	@mkdir -p "$(BINDIR)"
	@if [ -e "$(TARGET)" ] && [ ! -L "$(TARGET)" ]; then \
	    mv "$(TARGET)" "$(TARGET).pre-refactor"; \
	    echo "kept the previous file as $(TARGET).pre-refactor"; \
	fi
	@ln -sfn "$(ROOT)/bin/kitty-sessionizer" "$(TARGET)"
	@echo "linked $(TARGET)"
	@echo
	@echo "Add these lines to kitty.conf:"
	@echo '  map alt+shift+p launch --type=overlay --title "Project Selector" /bin/zsh $(TARGET) open'
	@echo '  map alt+shift+d launch --type=overlay --title "Delete Sessions" /bin/zsh $(TARGET) delete'

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
