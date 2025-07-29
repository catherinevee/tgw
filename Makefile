# Makefile for Terraform Transit Gateway Module operations
# Usage: make <target>

.PHONY: help init plan apply destroy fmt validate lint clean test

# Default target
help:
	@echo "Available targets:"
	@echo "  init      - Initialize Terraform"
	@echo "  plan      - Create Terraform plan"
	@echo "  apply     - Apply Terraform changes"
	@echo "  destroy   - Destroy Terraform resources"
	@echo "  fmt       - Format Terraform code"
	@echo "  validate  - Validate Terraform configuration"
	@echo "  lint      - Run TFLint"
	@echo "  clean     - Clean up Terraform files"
	@echo "  test      - Run tests"

# Initialize Terraform
init:
	@echo "Initializing Terraform..."
	terraform init
	@echo "Terraform initialized successfully!"

# Create Terraform plan
plan:
	@echo "Creating Terraform plan..."
	terraform plan -out=tfplan
	@echo "Plan created successfully!"

# Apply Terraform changes
apply:
	@echo "Applying Terraform changes..."
	terraform apply tfplan
	@echo "Changes applied successfully!"

# Destroy Terraform resources
destroy:
	@echo "Destroying Terraform resources..."
	terraform destroy -auto-approve
	@echo "Resources destroyed successfully!"

# Format Terraform code
fmt:
	@echo "Formatting Terraform code..."
	terraform fmt -recursive
	@echo "Code formatted successfully!"

# Validate Terraform configuration
validate:
	@echo "Validating Terraform configuration..."
	terraform validate
	@echo "Configuration is valid!"

# Run TFLint
lint:
	@echo "Running TFLint..."
	tflint --init
	tflint
	@echo "Linting completed!"

# Clean up Terraform files
clean:
	@echo "Cleaning up Terraform files..."
	rm -rf .terraform
	rm -f .terraform.lock.hcl
	rm -f tfplan
	rm -f *.tfstate
	rm -f *.tfstate.backup
	@echo "Cleanup completed!"

# Run tests
test: validate lint
	@echo "Running tests..."
	cd test && terraform init
	cd test && terraform plan -detailed-exitcode
	@echo "Tests completed!"

# Development workflow
dev: fmt validate lint
	@echo "Development checks completed!"

# Production workflow
prod: fmt validate lint test
	@echo "Production checks completed!"

# Install dependencies
install:
	@echo "Installing dependencies..."
	curl -sSLo ~/.local/bin/tflint https://github.com/terraform-linters/tflint/releases/latest/download/tflint_linux_amd64
	chmod +x ~/.local/bin/tflint
	@echo "Dependencies installed successfully!"

# Show current workspace
workspace:
	@echo "Current workspace: $(shell terraform workspace show)"

# List workspaces
workspaces:
	@echo "Available workspaces:"
	@terraform workspace list

# Create new workspace
workspace-new:
	@read -p "Enter workspace name: " name; \
	terraform workspace new $$name

# Switch workspace
workspace-switch:
	@read -p "Enter workspace name: " name; \
	terraform workspace select $$name 