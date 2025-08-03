# Makefile for Terraform Transit Gateway Module operations
# Usage: make <target>

.PHONY: help init plan apply destroy validate fmt lint test clean

# Default target
help:
	@echo "Available targets:"
	@echo "  init     - Initialize Terraform"
	@echo "  plan     - Plan Terraform changes"
	@echo "  apply    - Apply Terraform changes"
	@echo "  destroy  - Destroy Terraform resources"
	@echo "  validate - Validate Terraform configuration"
	@echo "  fmt      - Format Terraform code"
	@echo "  lint     - Lint Terraform code"
	@echo "  test     - Run Terraform tests"
	@echo "  clean    - Clean up temporary files"

# Initialize Terraform
init:
	terraform init

# Plan Terraform changes
plan:
	terraform plan

# Apply Terraform changes
apply:
	terraform apply

# Destroy Terraform resources
destroy:
	terraform destroy

# Validate Terraform configuration
validate:
	terraform validate

# Format Terraform code
fmt:
	terraform fmt -recursive

# Lint Terraform code (requires tflint)
lint:
	tflint

# Run Terraform tests
test:
	cd test && terraform test

# Clean up temporary files
clean:
	rm -rf .terraform
	rm -rf .terraform.lock.hcl
	rm -rf terraform.tfstate*
	rm -rf test/.terraform
	rm -rf test/.terraform.lock.hcl
	rm -rf test/terraform.tfstate*

# Install development dependencies
install-deps:
	@echo "Installing development dependencies..."
	@if ! command -v tflint >/dev/null 2>&1; then \
		echo "Installing tflint..."; \
		curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash; \
	fi

# Check code quality
check: fmt lint validate
	@echo "Code quality checks completed"

# Prepare for release
release: check test
	@echo "Release preparation completed" 