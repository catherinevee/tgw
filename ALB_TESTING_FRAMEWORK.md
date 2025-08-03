# ALB Module Testing Framework

## Testing Strategy Overview

This document outlines a comprehensive testing strategy for the Terraform AWS Application Load Balancer module, including native Terraform tests, CI/CD workflows, and validation tools.

## 1. Native Terraform Tests

### Test File Structure

```hcl
# test/alb_test.tftest.hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.2.0"
    }
  }
}

# Test 1: Basic ALB Creation
run "test_basic_alb_creation" {
  command = plan

  variables {
    name = "test-alb"
    vpc_id = "vpc-12345678"
    subnet_ids = ["subnet-12345678", "subnet-87654321"]
    create_security_group = true
    enable_http = true
    enable_https = true
  }

  assert {
    condition     = aws_lb.main.load_balancer_type == "application"
    error_message = "Load balancer type should be application"
  }

  assert {
    condition     = aws_lb.main.internal == false
    error_message = "ALB should be internet-facing by default"
  }

  assert {
    condition     = aws_lb.main.enable_deletion_protection == false
    error_message = "Deletion protection should be disabled by default"
  }

  assert {
    condition     = aws_lb.main.enable_http2 == true
    error_message = "HTTP/2 should be enabled by default"
  }
}

# Test 2: Target Group Creation
run "test_target_group_creation" {
  command = plan

  variables {
    name = "test-alb"
    vpc_id = "vpc-12345678"
    subnet_ids = ["subnet-12345678", "subnet-87654321"]
    target_groups = {
      web = {
        name = "web-tg"
        port = 80
        protocol = "HTTP"
        target_type = "instance"
        health_check = {
          path = "/health"
          matcher = "200"
          interval = 30
          timeout = 5
          healthy_threshold = 2
          unhealthy_threshold = 2
        }
      }
    }
  }

  assert {
    condition     = aws_lb_target_group.main["web"].protocol == "HTTP"
    error_message = "Target group protocol should be HTTP"
  }

  assert {
    condition     = aws_lb_target_group.main["web"].port == 80
    error_message = "Target group port should be 80"
  }

  assert {
    condition     = aws_lb_target_group.main["web"].target_type == "instance"
    error_message = "Target type should be instance"
  }

  assert {
    condition     = aws_lb_target_group.main["web"].health_check[0].path == "/health"
    error_message = "Health check path should be /health"
  }
}

# Test 3: Listener Creation
run "test_listener_creation" {
  command = plan

  variables {
    name = "test-alb"
    vpc_id = "vpc-12345678"
    subnet_ids = ["subnet-12345678", "subnet-87654321"]
    target_groups = {
      web = {
        name = "web-tg"
        port = 80
        protocol = "HTTP"
        target_type = "instance"
        health_check = {
          path = "/health"
          matcher = "200"
        }
      }
    }
    listeners = {
      https = {
        port = 443
        protocol = "HTTPS"
        ssl_policy = "ELBSecurityPolicy-TLS-1-2-2017-01"
        certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"
        default_action = {
          type = "forward"
          target_group_key = "web"
        }
      }
    }
  }

  assert {
    condition     = aws_lb_listener.main["https"].port == 443
    error_message = "HTTPS listener port should be 443"
  }

  assert {
    condition     = aws_lb_listener.main["https"].protocol == "HTTPS"
    error_message = "Listener protocol should be HTTPS"
  }

  assert {
    condition     = aws_lb_listener.main["https"].ssl_policy == "ELBSecurityPolicy-TLS-1-2-2017-01"
    error_message = "SSL policy should be set correctly"
  }
}

# Test 4: Security Group Creation
run "test_security_group_creation" {
  command = plan

  variables {
    name = "test-alb"
    vpc_id = "vpc-12345678"
    subnet_ids = ["subnet-12345678", "subnet-87654321"]
    create_security_group = true
    enable_http = true
    enable_https = true
    http_cidr_blocks = ["0.0.0.0/0"]
    https_cidr_blocks = ["0.0.0.0/0"]
  }

  assert {
    condition     = aws_security_group.alb[0].name == "test-alb-alb-sg"
    error_message = "Security group name should be correctly formatted"
  }

  assert {
    condition     = length(aws_security_group.alb[0].ingress) == 2
    error_message = "Should have 2 ingress rules (HTTP and HTTPS)"
  }

  assert {
    condition     = length(aws_security_group.alb[0].egress) == 1
    error_message = "Should have 1 egress rule"
  }
}

# Test 5: Listener Rules
run "test_listener_rules" {
  command = plan

  variables {
    name = "test-alb"
    vpc_id = "vpc-12345678"
    subnet_ids = ["subnet-12345678", "subnet-87654321"]
    target_groups = {
      web = {
        name = "web-tg"
        port = 80
        protocol = "HTTP"
        target_type = "instance"
        health_check = {
          path = "/health"
          matcher = "200"
        }
      }
      api = {
        name = "api-tg"
        port = 8080
        protocol = "HTTP"
        target_type = "instance"
        health_check = {
          path = "/api/health"
          matcher = "200"
        }
      }
    }
    listeners = {
      https = {
        port = 443
        protocol = "HTTPS"
        ssl_policy = "ELBSecurityPolicy-TLS-1-2-2017-01"
        certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"
        default_action = {
          type = "forward"
          target_group_key = "web"
        }
      }
    }
    listener_rules = {
      api_rule = {
        listener_key = "https"
        priority = 100
        conditions = [
          {
            path_pattern = {
              values = ["/api/*"]
            }
          }
        ]
        actions = [
          {
            type = "forward"
            target_group_key = "api"
          }
        ]
      }
    }
  }

  assert {
    condition     = aws_lb_listener_rule.main["api_rule"].priority == 100
    error_message = "Listener rule priority should be 100"
  }
}

# Test 6: Variable Validation - Invalid Target Type
run "test_invalid_target_type" {
  command = plan

  variables {
    name = "test-alb"
    vpc_id = "vpc-12345678"
    subnet_ids = ["subnet-12345678", "subnet-87654321"]
    target_groups = {
      web = {
        name = "web-tg"
        port = 80
        protocol = "HTTP"
        target_type = "invalid_type"
        health_check = {
          path = "/health"
          matcher = "200"
        }
      }
    }
  }

  expect_failures = [
    aws_lb_target_group.main,
  ]
}

# Test 7: Variable Validation - Invalid Protocol
run "test_invalid_protocol" {
  command = plan

  variables {
    name = "test-alb"
    vpc_id = "vpc-12345678"
    subnet_ids = ["subnet-12345678", "subnet-87654321"]
    target_groups = {
      web = {
        name = "web-tg"
        port = 80
        protocol = "INVALID"
        target_type = "instance"
        health_check = {
          path = "/health"
          matcher = "200"
        }
      }
    }
  }

  expect_failures = [
    aws_lb_target_group.main,
  ]
}

# Test 8: WAF Integration
run "test_waf_integration" {
  command = plan

  variables {
    name = "test-alb"
    vpc_id = "vpc-12345678"
    subnet_ids = ["subnet-12345678", "subnet-87654321"]
    enable_waf = true
    waf_web_acl_arn = "arn:aws:wafv2:us-east-1:123456789012:regional/webacl/test-waf/12345678-1234-1234-1234-123456789012"
  }

  assert {
    condition     = aws_wafv2_web_acl_association.main[0].resource_arn == aws_lb.main.arn
    error_message = "WAF should be associated with the ALB"
  }
}

# Test 9: Access Logs
run "test_access_logs" {
  command = plan

  variables {
    name = "test-alb"
    vpc_id = "vpc-12345678"
    subnet_ids = ["subnet-12345678", "subnet-87654321"]
    enable_access_logs = true
    access_logs_bucket = "test-alb-logs-bucket"
    access_logs_prefix = "alb-logs"
  }

  assert {
    condition     = aws_lb.main.access_logs[0].enabled == true
    error_message = "Access logs should be enabled"
  }

  assert {
    condition     = aws_lb.main.access_logs[0].bucket == "test-alb-logs-bucket"
    error_message = "Access logs bucket should be set correctly"
  }
}

# Test 10: Tags
run "test_tags" {
  command = plan

  variables {
    name = "test-alb"
    vpc_id = "vpc-12345678"
    subnet_ids = ["subnet-12345678", "subnet-87654321"]
    tags = {
      Environment = "test"
      Project = "alb-testing"
      Owner = "terraform"
    }
  }

  assert {
    condition     = aws_lb.main.tags["Environment"] == "test"
    error_message = "Environment tag should be set correctly"
  }

  assert {
    condition     = aws_lb.main.tags["Project"] == "alb-testing"
    error_message = "Project tag should be set correctly"
  }
}
```

## 2. CI/CD Workflow

### GitHub Actions Workflow

```yaml
# .github/workflows/terraform.yml
name: "Terraform ALB Module"

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

env:
  TF_VERSION: "1.13.0"
  AWS_PROVIDER_VERSION: "6.2.0"

jobs:
  validate:
    name: "Validate"
    runs-on: ubuntu-latest

    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v3
      with:
        terraform_version: ${{ env.TF_VERSION }}

    - name: Terraform Format Check
      run: terraform fmt -check -recursive

    - name: Terraform Init
      run: terraform init

    - name: Terraform Validate
      run: terraform validate

    - name: Terraform Plan (Dry Run)
      run: |
        cd examples/basic
        terraform init
        terraform plan -var-file="test.tfvars"

  lint:
    name: "Lint"
    runs-on: ubuntu-latest

    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Setup TFLint
      uses: terraform-linters/setup-tflint@v4
      with:
        tflint_version: v0.48.0

    - name: Run TFLint
      run: tflint --init && tflint

  security:
    name: "Security Scanning"
    runs-on: ubuntu-latest

    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Run tfsec
      uses: aquasecurity/tfsec-action@v1.0.0
      with:
        format: sarif
        out: tfsec.sarif
        working_directory: .

    - name: Upload tfsec results
      uses: github/codeql-action/upload-sarif@v3
      with:
        sarif_file: tfsec.sarif

    - name: Run Checkov
      uses: bridgecrewio/checkov-action@master
      with:
        directory: .
        framework: terraform
        output_format: sarif
        output_file_path: checkov.sarif

    - name: Upload Checkov results
      uses: github/codeql-action/upload-sarif@v3
      with:
        sarif_file: checkov.sarif

  test:
    name: "Test"
    runs-on: ubuntu-latest

    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v3
      with:
        terraform_version: ${{ env.TF_VERSION }}

    - name: Run Terraform Tests
      run: |
        cd test
        terraform test

  documentation:
    name: "Documentation"
    runs-on: ubuntu-latest

    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Check README exists
      run: |
        if [ ! -f "README.md" ]; then
          echo "README.md is missing"
          exit 1
        fi

    - name: Check examples exist
      run: |
        if [ ! -d "examples" ]; then
          echo "examples directory is missing"
          exit 1
        fi

    - name: Check examples README
      run: |
        if [ ! -f "examples/README.md" ]; then
          echo "examples/README.md is missing"
          exit 1
        fi

    - name: Validate example configurations
      run: |
        for example in examples/*/; do
          if [ -d "$example" ]; then
            echo "Validating $example"
            cd "$example"
            if [ -f "main.tf" ]; then
              terraform init
              terraform validate
            fi
            cd ../..
          fi
        done

  release:
    name: "Release"
    runs-on: ubuntu-latest
    needs: [validate, lint, security, test, documentation]
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'

    steps:
    - name: Checkout code
      uses: actions/checkout@v4
      with:
        fetch-depth: 0

    - name: Create Release
      uses: actions/create-release@v1
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      with:
        tag_name: ${{ github.ref }}
        release_name: Release ${{ github.ref }}
        body: |
          Changes in this Release:
          ${{ github.event.head_commit.message }}
        draft: false
        prerelease: false
```

## 3. TFLint Configuration

```hcl
# .tflint.hcl
plugin "aws" {
  enabled = true
  version = "0.27.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

config {
  module = true
  force  = false
}

# ALB Specific Rules
rule "aws_lb_invalid_type" {
  enabled = true
}

rule "aws_lb_invalid_name" {
  enabled = true
}

rule "aws_lb_target_group_invalid_protocol" {
  enabled = true
}

rule "aws_lb_target_group_invalid_target_type" {
  enabled = true
}

rule "aws_lb_listener_invalid_protocol" {
  enabled = true
}

rule "aws_lb_listener_invalid_port" {
  enabled = true
}

# Security Group Rules
rule "aws_security_group_invalid_name" {
  enabled = true
}

rule "aws_security_group_rule_invalid_type" {
  enabled = true
}

rule "aws_security_group_rule_invalid_protocol" {
  enabled = true
}

# General Terraform Rules
rule "terraform_documented_outputs" {
  enabled = true
}

rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_typed_variables" {
  enabled = true
}

rule "terraform_naming_convention" {
  enabled = true
}

rule "terraform_required_version" {
  enabled = true
}

rule "terraform_required_providers" {
  enabled = true
}

# AWS Best Practices
rule "aws_resource_missing_tags" {
  enabled = true
}

rule "aws_instance_invalid_type" {
  enabled = true
}

rule "aws_instance_invalid_ami" {
  enabled = true
}
```

## 4. Test Variables File

```hcl
# test/test.tfvars
name = "test-alb"
vpc_id = "vpc-12345678"
subnet_ids = ["subnet-12345678", "subnet-87654321"]

# Basic configuration
internal = false
enable_http = true
enable_https = true
enable_http2 = true
idle_timeout = 60
deletion_protection = false

# Security
create_security_group = true
http_cidr_blocks = ["0.0.0.0/0"]
https_cidr_blocks = ["0.0.0.0/0"]

# Target groups
target_groups = {
  web = {
    name = "web-tg"
    port = 80
    protocol = "HTTP"
    target_type = "instance"
    health_check = {
      path = "/health"
      matcher = "200"
      interval = 30
      timeout = 5
      healthy_threshold = 2
      unhealthy_threshold = 2
    }
  }
}

# Listeners
listeners = {
  http = {
    port = 80
    protocol = "HTTP"
    default_action = {
      type = "redirect"
      redirect_config = {
        status_code = "HTTP_301"
        protocol = "HTTPS"
        port = "443"
      }
    }
  }
  https = {
    port = 443
    protocol = "HTTPS"
    ssl_policy = "ELBSecurityPolicy-TLS-1-2-2017-01"
    certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"
    default_action = {
      type = "forward"
      target_group_key = "web"
    }
  }
}

# Monitoring
enable_access_logs = true
access_logs_bucket = "test-alb-logs-bucket"
access_logs_prefix = "alb-logs"

# Tags
tags = {
  Environment = "test"
  Project = "alb-testing"
  Owner = "terraform"
}
```

## 5. Integration Tests

### Terratest Integration

```go
// test/terratest/alb_test.go
package test

import (
    "testing"
    "time"

    "github.com/gruntwork-io/terratest/modules/terraform"
    "github.com/gruntwork-io/terratest/modules/aws"
    "github.com/stretchr/testify/assert"
)

func TestALBModule(t *testing.T) {
    terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
        TerraformDir: "../examples/basic",
        Vars: map[string]interface{}{
            "name": "test-alb-terratest",
        },
    })

    defer terraform.Destroy(t, terraformOptions)

    terraform.InitAndApply(t, terraformOptions)

    albID := terraform.Output(t, terraformOptions, "alb_id")
    albARN := terraform.Output(t, terraformOptions, "alb_arn")
    albDNSName := terraform.Output(t, terraformOptions, "alb_dns_name")

    // Verify ALB exists
    assert.NotEmpty(t, albID)
    assert.NotEmpty(t, albARN)
    assert.NotEmpty(t, albDNSName)

    // Verify ALB is accessible
    aws.AssertElbExists(t, albID, "us-east-1")
}
```

## 6. Performance Tests

### Load Testing Script

```bash
#!/bin/bash
# test/performance/load_test.sh

ALB_DNS_NAME=$1
NUM_REQUESTS=1000
CONCURRENT_REQUESTS=10

echo "Starting load test for ALB: $ALB_DNS_NAME"

# Test HTTP endpoints
echo "Testing HTTP endpoint..."
ab -n $NUM_REQUESTS -c $CONCURRENT_REQUESTS http://$ALB_DNS_NAME/

echo "Testing HTTPS endpoint..."
ab -n $NUM_REQUESTS -c $CONCURRENT_REQUESTS https://$ALB_DNS_NAME/

echo "Testing health check endpoint..."
ab -n $NUM_REQUESTS -c $CONCURRENT_REQUESTS http://$ALB_DNS_NAME/health

echo "Load test completed"
```

## 7. Security Tests

### Security Validation Script

```bash
#!/bin/bash
# test/security/security_test.sh

ALB_ID=$1
REGION=$2

echo "Running security tests for ALB: $ALB_ID"

# Check if ALB has deletion protection
DELETION_PROTECTION=$(aws elbv2 describe-load-balancers \
    --load-balancer-arns $ALB_ID \
    --region $REGION \
    --query 'LoadBalancers[0].LoadBalancerAttributes[?Key==`deletion_protection.enabled`].Value' \
    --output text)

if [ "$DELETION_PROTECTION" != "true" ]; then
    echo "WARNING: Deletion protection is not enabled"
fi

# Check if ALB has access logs enabled
ACCESS_LOGS=$(aws elbv2 describe-load-balancers \
    --load-balancer-arns $ALB_ID \
    --region $REGION \
    --query 'LoadBalancers[0].LoadBalancerAttributes[?Key==`access_logs.s3.enabled`].Value' \
    --output text)

if [ "$ACCESS_LOGS" != "true" ]; then
    echo "WARNING: Access logs are not enabled"
fi

# Check security group rules
SG_ID=$(aws elbv2 describe-load-balancers \
    --load-balancer-arns $ALB_ID \
    --region $REGION \
    --query 'LoadBalancers[0].SecurityGroups[0]' \
    --output text)

echo "Security group ID: $SG_ID"

# Check for overly permissive rules
PERMISSIVE_RULES=$(aws ec2 describe-security-group-rules \
    --filters "Name=group-id,Values=$SG_ID" \
    --region $REGION \
    --query 'SecurityGroupRules[?IpRanges[0].CidrIp==`0.0.0.0/0`]' \
    --output table)

if [ ! -z "$PERMISSIVE_RULES" ]; then
    echo "WARNING: Found overly permissive security group rules"
    echo "$PERMISSIVE_RULES"
fi

echo "Security tests completed"
```

## 8. Test Execution

### Makefile for Testing

```makefile
# Makefile
.PHONY: test test-unit test-integration test-security test-performance clean

# Run all tests
test: test-unit test-integration test-security test-performance

# Run unit tests (Terraform native tests)
test-unit:
	@echo "Running unit tests..."
	cd test && terraform test

# Run integration tests (Terratest)
test-integration:
	@echo "Running integration tests..."
	cd test/terratest && go test -v -timeout 30m

# Run security tests
test-security:
	@echo "Running security tests..."
	./test/security/security_test.sh $(ALB_ID) $(REGION)

# Run performance tests
test-performance:
	@echo "Running performance tests..."
	./test/performance/load_test.sh $(ALB_DNS_NAME)

# Run linting
lint:
	@echo "Running TFLint..."
	tflint --init && tflint

# Run security scanning
security-scan:
	@echo "Running tfsec..."
	tfsec .
	@echo "Running Checkov..."
	checkov -d . --framework terraform

# Format code
fmt:
	@echo "Formatting Terraform code..."
	terraform fmt -recursive

# Validate code
validate:
	@echo "Validating Terraform code..."
	terraform validate

# Clean up test artifacts
clean:
	@echo "Cleaning up test artifacts..."
	rm -rf .terraform
	rm -rf .terraform.lock.hcl
	rm -rf test/.terraform
	rm -rf test/.terraform.lock.hcl
```

## 9. Test Results and Reporting

### Test Report Template

```markdown
# ALB Module Test Report

## Test Summary
- **Date**: $(date)
- **Module Version**: $(git describe --tags)
- **Terraform Version**: $(terraform version)
- **AWS Provider Version**: 6.2.0

## Test Results

### Unit Tests
- [ ] Basic ALB Creation
- [ ] Target Group Creation
- [ ] Listener Creation
- [ ] Security Group Creation
- [ ] Listener Rules
- [ ] Variable Validation
- [ ] WAF Integration
- [ ] Access Logs
- [ ] Tags

### Integration Tests
- [ ] End-to-end deployment
- [ ] ALB accessibility
- [ ] Target group health checks
- [ ] SSL/TLS termination

### Security Tests
- [ ] Deletion protection
- [ ] Access logs enabled
- [ ] Security group rules
- [ ] WAF integration

### Performance Tests
- [ ] HTTP endpoint performance
- [ ] HTTPS endpoint performance
- [ ] Health check performance

## Issues Found
- None

## Recommendations
- None

## Next Steps
- [ ] Address any failed tests
- [ ] Update documentation if needed
- [ ] Create release if all tests pass
```

This comprehensive testing framework ensures the ALB module is thoroughly tested across multiple dimensions including functionality, security, performance, and compliance with best practices. 