.PHONY: help fmt fmt-check tflint checkov actionlint lint validate plan apply clean

TF_DIR ?= .

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

fmt: ## Auto-format Terraform files
	terraform fmt -recursive $(TF_DIR)

fmt-check: ## Check formatting without modifying files (what CI runs)
	terraform fmt -check -recursive $(TF_DIR)

tflint: ## Run TFLint
	tflint --init
	tflint -f compact --recursive $(TF_DIR)

checkov: ## Run Checkov security/compliance scan
	checkov -d $(TF_DIR) --framework terraform --quiet

actionlint: ## Lint GitHub Actions workflow files
	actionlint

lint: fmt-check tflint checkov actionlint ## Run all lint checks (mirrors lint.yml)

validate: ## terraform init (no backend) + validate
	terraform -chdir=$(TF_DIR) init -backend=false
	terraform -chdir=$(TF_DIR) validate

plan: ## terraform init + plan (requires real backend/provider creds)
	terraform -chdir=$(TF_DIR) init
	terraform -chdir=$(TF_DIR) plan

apply: ## terraform apply (requires real backend/provider creds)
	terraform -chdir=$(TF_DIR) apply

clean: ## Remove local Terraform + TFLint artifacts
	rm -rf .terraform .terraform.lock.hcl .tflint.d
