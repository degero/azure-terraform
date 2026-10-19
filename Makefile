# Makefile for azure-terraform-template
SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

ENV ?= dev

.PHONY: help
help: ## Display this help screen
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-16s\033[0m %s\n", $$1, $$2}'

.PHONY: init
init: ## Initialize Terraform for an environment (e.g. make init ENV=dev)
	@if [ ! -d "environments/$(ENV)" ]; then echo "Error: environments/$(ENV) does not exist" >&2; exit 1; fi
	cd environments/$(ENV) && bash ../../scripts/tf-init.sh

.PHONY: plan
plan: ## Run terraform plan for an environment (e.g. make plan ENV=dev)
	@if [ ! -d "environments/$(ENV)" ]; then echo "Error: environments/$(ENV) does not exist" >&2; exit 1; fi
	terraform -chdir=environments/$(ENV) plan -var-file=terraform.tfvars

.PHONY: validate
validate: ## Validate all environments with local backend
	@failed=0; \
	for env_path in environments/*/; do \
		env_name=$$(basename "$$env_path"); \
		echo "==> Validating $$env_name"; \
		terraform -chdir="$$env_path" init -backend=false -input=false > /dev/null || failed=1; \
		terraform -chdir="$$env_path" validate || failed=1; \
	done; \
	exit $$failed

.PHONY: test
test: ## Run Terraform tests across all modules
	bash scripts/tf-test.sh

.PHONY: fmt
fmt: ## Format Terraform and repository files
	terraform fmt -recursive
	@if command -v npx >/dev/null 2>&1; then \
		npx --no-install prettier --write "**/*.{json,jsonc,yaml,yml,md,code-workspace}"; \
	fi

.PHONY: fmt-check
fmt-check: ## Check formatting without modifying files
	terraform fmt -check -recursive
	@if command -v npx >/dev/null 2>&1; then \
		npx --no-install prettier --check "**/*.{json,jsonc,yaml,yml,md,code-workspace}"; \
	fi

.PHONY: lint
lint: ## Run TFLint on modules and environments
	@if command -v tflint >/dev/null 2>&1; then \
		echo "==> tflint (modules)"; \
		tflint -f compact --recursive --chdir=modules --config=.tflint.modules.hcl; \
		echo "==> tflint (environments)"; \
		tflint -f compact --recursive --chdir=environments; \
	else \
		echo "tflint not installed"; exit 1; \
	fi

.PHONY: check
check: ## Run all local static checks (pre-push checks)
	bash scripts/prepush.sh

.PHONY: docs
docs: ## Generate terraform-docs for modules and environments
	@for root in environments modules modulegroups; do \
		if [ -d "$$root" ]; then \
			mkdir -p "docs/$$root"; \
			echo "Generating docs/$$root/README.md"; \
			{ \
				echo "# $$root"; \
				find "$$root" -name '*.tf' -not -path '*/.terraform/*' -exec dirname {} \; \
					| sort -u \
					| while read -r dir; do \
						echo ""; \
						echo "## $$dir"; \
						terraform-docs markdown table --hide header --indent 3 "$$dir"; \
					done; \
			} > "docs/$$root/README.md"; \
		fi; \
	done
