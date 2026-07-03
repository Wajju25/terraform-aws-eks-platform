# Terraform AWS EKS Platform
#
# Usage:
#   make init ENV=dev
#   make plan ENV=prod
#   make apply ENV=dev
#   make destroy ENV=dev
#
# ENV defaults to dev.

ENV      ?= dev
TF_DIR   := environments/$(ENV)
PLAN_OUT := $(ENV).tfplan

.PHONY: help init plan apply destroy fmt fmt-check validate lint security clean

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-12s %s\n", $$1, $$2}'

init: ## Initialize the selected environment (ENV=dev|prod)
	terraform -chdir=$(TF_DIR) init

plan: ## Produce a plan file for the selected environment
	terraform -chdir=$(TF_DIR) plan -input=false -out=$(PLAN_OUT)

apply: ## Apply the most recent plan file for the selected environment
	terraform -chdir=$(TF_DIR) apply -input=false $(PLAN_OUT)

destroy: ## Destroy the selected environment (asks for confirmation)
	terraform -chdir=$(TF_DIR) destroy -input=false

fmt: ## Format all Terraform files in place
	terraform fmt -recursive

fmt-check: ## Verify formatting without changing files
	terraform fmt -recursive -check -diff

validate: init ## Validate the selected environment
	terraform -chdir=$(TF_DIR) validate

lint: ## Run tflint across the repository
	tflint --init
	tflint --recursive --config "$(CURDIR)/.tflint.hcl"

security: ## Run tfsec and checkov static analysis
	tfsec .
	checkov --directory . --framework terraform

clean: ## Remove local plan files and .terraform directories
	find . -name "*.tfplan" -delete
	find . -type d -name ".terraform" -prune -exec rm -rf {} +
