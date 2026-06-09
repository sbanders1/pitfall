# Pitfall — Makefile
# Requires the Godot 4 editor binary on PATH (`godot`).

GODOT  ?= godot
PROJECT := .
MAIN    := res://scenes/Main.tscn

.DEFAULT_GOAL := help

.PHONY: help run edit check headless import clean

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

run: ## Run the game
	$(GODOT) --path $(PROJECT) $(MAIN)

edit: ## Open the project in the Godot editor
	$(GODOT) --path $(PROJECT) --editor

check: ## Validate/lint all scripts without running
	$(GODOT) --path $(PROJECT) --headless --check-only --script res://scripts/Main.gd

headless: ## Run the game without a window (CI / smoke test)
	$(GODOT) --path $(PROJECT) --headless $(MAIN)

import: ## Reimport assets and regenerate the .godot cache
	$(GODOT) --path $(PROJECT) --headless --import

clean: ## Remove the generated .godot cache
	rm -rf .godot
