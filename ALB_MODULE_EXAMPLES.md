# ALB Module Examples Structure

## Examples Directory Organization

```
examples/
├── README.md                    # Examples overview and usage guide
├── basic/                       # Basic ALB configuration
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── advanced/                    # Advanced Layer 7 features
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── ssl/                         # SSL/TLS termination
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── waf/                         # WAF integration
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── microservices/               # Microservices routing
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── blue-green/                  # Blue-green deployment
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── canary/                      # Canary deployment
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── monitoring/                  # Enhanced monitoring
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
└── terragrunt/                  # Terragrunt usage
    └── terragrunt.hcl
```

## Example Implementations

### 1. Basic ALB Configuration

```hcl
# examples/basic/main.tf
module "alb_basic" {
  source = "../../"

  name = "basic-alb"
  vpc_id = data.aws_vpc.default.id
  subnet_ids = data.aws_subnets.public.ids

  # Basic configuration
  internal = false
  enable_http = true
  enable_https = true

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
      certificate_arn = data.aws_acm_certificate.main.arn
      default_action = {
        type = "forward"
        target_group_key = "web"
      }
    }
  }

  # Monitoring
  enable_access_logs = true
  access_logs_bucket = aws_s3_bucket.alb_logs.bucket
  access_logs_prefix = "alb-logs"

  tags = {
    Environment = "production"
    Project = "basic-alb-example"
    Owner = "terraform"
  }
}
```

### 2. Advanced Layer 7 Features

```hcl
# examples/advanced/main.tf
module "alb_advanced" {
  source = "../../"

  name = "advanced-alb"
  vpc_id = data.aws_vpc.default.id
  subnet_ids = data.aws_subnets.public.ids

  # Advanced configuration
  internal = false
  enable_http = true
  enable_https = true
  enable_http2 = true
  idle_timeout = 60
  deletion_protection = true

  # Multiple target groups
  target_groups = {
    web = {
      name = "web-tg"
      port = 80
      protocol = "HTTP"
      target_type = "instance"
      health_check = {
        path = "/health"
        matcher = "200,302"
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
    static = {
      name = "static-tg"
      port = 80
      protocol = "HTTP"
      target_type = "instance"
      health_check = {
        path = "/static/health"
        matcher = "200"
      }
    }
  }

  # Advanced listeners with rules
  listeners = {
    https = {
      port = 443
      protocol = "HTTPS"
      ssl_policy = "ELBSecurityPolicy-TLS-1-2-2017-01"
      certificate_arn = data.aws_acm_certificate.main.arn
      default_action = {
        type = "forward"
        target_group_key = "web"
      }
    }
  }

  # Listener rules for advanced routing
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
    static_rule = {
      listener_key = "https"
      priority = 200
      conditions = [
        {
          path_pattern = {
            values = ["/static/*", "/assets/*"]
          }
        }
      ]
      actions = [
        {
          type = "forward"
          target_group_key = "static"
        }
      ]
    }
    host_based_routing = {
      listener_key = "https"
      priority = 300
      conditions = [
        {
          host_header = {
            values = ["api.example.com"]
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

  # Enhanced monitoring
  enable_access_logs = true
  access_logs_bucket = aws_s3_bucket.alb_logs.bucket
  access_logs_prefix = "alb-logs"

  tags = {
    Environment = "production"
    Project = "advanced-alb-example"
    Owner = "terraform"
  }
}
```

### 3. SSL/TLS Termination

```hcl
# examples/ssl/main.tf
module "alb_ssl" {
  source = "../../"

  name = "ssl-alb"
  vpc_id = data.aws_vpc.default.id
  subnet_ids = data.aws_subnets.public.ids

  # SSL configuration
  internal = false
  enable_https = true
  enable_http = true

  # Security
  create_security_group = true
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
      }
    }
  }

  # SSL listeners
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
    https_main = {
      port = 443
      protocol = "HTTPS"
      ssl_policy = "ELBSecurityPolicy-TLS-1-2-2017-01"
      certificate_arn = data.aws_acm_certificate.main.arn
      default_action = {
        type = "forward"
        target_group_key = "web"
      }
    }
    https_www = {
      port = 443
      protocol = "HTTPS"
      ssl_policy = "ELBSecurityPolicy-TLS-1-2-2017-01"
      certificate_arn = data.aws_acm_certificate.wildcard.arn
      default_action = {
        type = "forward"
        target_group_key = "web"
      }
    }
  }

  # SSL-specific listener rules
  listener_rules = {
    www_redirect = {
      listener_key = "https_main"
      priority = 100
      conditions = [
        {
          host_header = {
            values = ["www.example.com"]
          }
        }
      ]
      actions = [
        {
          type = "redirect"
          redirect_config = {
            status_code = "HTTP_301"
            host = "example.com"
            path = "/#{path}"
            query = "#{query}"
          }
        }
      ]
    }
  }

  tags = {
    Environment = "production"
    Project = "ssl-alb-example"
    Owner = "terraform"
  }
}
```

### 4. WAF Integration

```hcl
# examples/waf/main.tf
module "alb_waf" {
  source = "../../"

  name = "waf-alb"
  vpc_id = data.aws_vpc.default.id
  subnet_ids = data.aws_subnets.public.ids

  # Basic configuration
  internal = false
  enable_https = true

  # Security
  create_security_group = true
  enable_waf = true
  waf_web_acl_arn = aws_wafv2_web_acl.main.arn

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
      }
    }
  }

  # Listeners
  listeners = {
    https = {
      port = 443
      protocol = "HTTPS"
      ssl_policy = "ELBSecurityPolicy-TLS-1-2-2017-01"
      certificate_arn = data.aws_acm_certificate.main.arn
      default_action = {
        type = "forward"
        target_group_key = "web"
      }
    }
  }

  tags = {
    Environment = "production"
    Project = "waf-alb-example"
    Owner = "terraform"
  }
}

# WAF Web ACL
resource "aws_wafv2_web_acl" "main" {
  name        = "alb-waf-web-acl"
  description = "WAF Web ACL for ALB"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name               = "AWSManagedRulesCommonRuleSetMetric"
      sampled_requests_enabled  = true
    }
  }

  rule {
    name     = "RateLimitRule"
    priority = 2

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name               = "RateLimitRuleMetric"
      sampled_requests_enabled  = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name               = "ALBWAFWebACLMetric"
    sampled_requests_enabled  = true
  }
}
```

### 5. Microservices Routing

```hcl
# examples/microservices/main.tf
module "alb_microservices" {
  source = "../../"

  name = "microservices-alb"
  vpc_id = data.aws_vpc.default.id
  subnet_ids = data.aws_subnets.public.ids

  # Configuration
  internal = false
  enable_https = true

  # Multiple microservice target groups
  target_groups = {
    users = {
      name = "users-service-tg"
      port = 8080
      protocol = "HTTP"
      target_type = "instance"
      health_check = {
        path = "/users/health"
        matcher = "200"
      }
    }
    products = {
      name = "products-service-tg"
      port = 8081
      protocol = "HTTP"
      target_type = "instance"
      health_check = {
        path = "/products/health"
        matcher = "200"
      }
    }
    orders = {
      name = "orders-service-tg"
      port = 8082
      protocol = "HTTP"
      target_type = "instance"
      health_check = {
        path = "/orders/health"
        matcher = "200"
      }
    }
    payments = {
      name = "payments-service-tg"
      port = 8083
      protocol = "HTTP"
      target_type = "instance"
      health_check = {
        path = "/payments/health"
        matcher = "200"
      }
    }
  }

  # Listeners
  listeners = {
    https = {
      port = 443
      protocol = "HTTPS"
      ssl_policy = "ELBSecurityPolicy-TLS-1-2-2017-01"
      certificate_arn = data.aws_acm_certificate.main.arn
      default_action = {
        type = "forward"
        target_group_key = "users"
      }
    }
  }

  # Microservice routing rules
  listener_rules = {
    users_service = {
      listener_key = "https"
      priority = 100
      conditions = [
        {
          path_pattern = {
            values = ["/api/users/*"]
          }
        }
      ]
      actions = [
        {
          type = "forward"
          target_group_key = "users"
        }
      ]
    }
    products_service = {
      listener_key = "https"
      priority = 200
      conditions = [
        {
          path_pattern = {
            values = ["/api/products/*"]
          }
        }
      ]
      actions = [
        {
          type = "forward"
          target_group_key = "products"
        }
      ]
    }
    orders_service = {
      listener_key = "https"
      priority = 300
      conditions = [
        {
          path_pattern = {
            values = ["/api/orders/*"]
          }
        }
      ]
      actions = [
        {
          type = "forward"
          target_group_key = "orders"
        }
      ]
    }
    payments_service = {
      listener_key = "https"
      priority = 400
      conditions = [
        {
          path_pattern = {
            values = ["/api/payments/*"]
          }
        }
      ]
      actions = [
        {
          type = "forward"
          target_group_key = "payments"
        }
      ]
    }
  }

  tags = {
    Environment = "production"
    Project = "microservices-alb-example"
    Owner = "terraform"
  }
}
```

### 6. Terragrunt Configuration

```hcl
# examples/terragrunt/terragrunt.hcl
# Terragrunt ALB Example
# This example demonstrates how to use the ALB module with Terragrunt

# Include the root terragrunt.hcl configuration
include "root" {
  path = find_in_parent_folders()
}

# Include common variables
include "common" {
  path = find_in_parent_folders("common.hcl")
}

# Terraform configuration
terraform {
  source = "../../"
}

# Inputs for the ALB module
inputs = {
  name = "terragrunt-alb"
  vpc_id = dependency.vpc.outputs.vpc_id
  subnet_ids = dependency.vpc.outputs.public_subnets

  # Basic configuration
  internal = false
  enable_http = true
  enable_https = true

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
      certificate_arn = dependency.acm.outputs.certificate_arn
      default_action = {
        type = "forward"
        target_group_key = "web"
      }
    }
  }

  # Monitoring
  enable_access_logs = true
  access_logs_bucket = dependency.s3.outputs.alb_logs_bucket
  access_logs_prefix = "alb-logs"

  tags = {
    Environment = "terragrunt-example"
    Project = "terragrunt-alb"
    Owner = "terraform"
    ManagedBy = "terragrunt"
  }
}

# Dependencies
dependency "vpc" {
  config_path = "../vpc"

  mock_outputs = {
    vpc_id = "vpc-12345678"
    public_subnets = ["subnet-12345678", "subnet-87654321"]
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate"]
}

dependency "acm" {
  config_path = "../acm"

  mock_outputs = {
    certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate"]
}

dependency "s3" {
  config_path = "../s3"

  mock_outputs = {
    alb_logs_bucket = "alb-logs-bucket-12345678"
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate"]
}
```

## Examples README

```markdown
# ALB Module Examples

This directory contains comprehensive examples demonstrating how to use the Terraform AWS Application Load Balancer module for various use cases.

## Quick Start

Choose an example based on your requirements:

- **Basic**: Simple ALB with HTTP to HTTPS redirect
- **Advanced**: Complex routing with multiple target groups and rules
- **SSL**: SSL/TLS termination with multiple certificates
- **WAF**: WAF integration for security
- **Microservices**: Microservices architecture routing
- **Blue-Green**: Blue-green deployment patterns
- **Canary**: Canary deployment patterns
- **Monitoring**: Enhanced monitoring and alerting
- **Terragrunt**: Terragrunt integration

## Example Overview

| Example | Description | Use Case |
|---------|-------------|----------|
| [Basic](./basic/) | Simple ALB configuration | Getting started, simple web applications |
| [Advanced](./advanced/) | Complex routing and rules | Production applications with multiple services |
| [SSL](./ssl/) | SSL/TLS termination | Secure web applications |
| [WAF](./waf/) | WAF integration | Security-focused applications |
| [Microservices](./microservices/) | Microservices routing | Microservices architecture |
| [Blue-Green](./blue-green/) | Blue-green deployment | Zero-downtime deployments |
| [Canary](./canary/) | Canary deployment | Gradual rollouts |
| [Monitoring](./monitoring/) | Enhanced monitoring | Production monitoring |
| [Terragrunt](./terragrunt/) | Terragrunt integration | Terragrunt workflows |

## Common Configuration Options

### Basic Configuration
```hcl
module "alb" {
  source = "path/to/module"

  name = "my-alb"
  vpc_id = "vpc-12345678"
  subnet_ids = ["subnet-12345678", "subnet-87654321"]
  
  internal = false
  enable_http = true
  enable_https = true
}
```

### Security Configuration
```hcl
module "alb" {
  # ... basic configuration

  create_security_group = true
  http_cidr_blocks = ["0.0.0.0/0"]
  https_cidr_blocks = ["10.0.0.0/8"]
  
  enable_waf = true
  waf_web_acl_arn = aws_wafv2_web_acl.main.arn
}
```

### Target Groups
```hcl
module "alb" {
  # ... basic configuration

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
}
```

### Listeners and Rules
```hcl
module "alb" {
  # ... basic configuration

  listeners = {
    https = {
      port = 443
      protocol = "HTTPS"
      certificate_arn = data.aws_acm_certificate.main.arn
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
```

## Best Practices

1. **Security**: Always use HTTPS listeners in production
2. **Health Checks**: Configure appropriate health check paths and intervals
3. **Monitoring**: Enable access logs and CloudWatch monitoring
4. **WAF**: Use WAF for additional security layers
5. **Tags**: Apply consistent tagging strategy
6. **Deletion Protection**: Enable deletion protection for production ALBs

## Troubleshooting

### Common Issues

1. **Health Check Failures**: Verify health check paths and target group configuration
2. **SSL Certificate Issues**: Ensure certificate ARN is valid and in the correct region
3. **Security Group Rules**: Check that security groups allow necessary traffic
4. **Target Group Registration**: Verify targets are properly registered

### Debugging Steps

1. Check ALB target group health status
2. Review CloudWatch logs for access patterns
3. Verify security group rules
4. Test health check endpoints directly
5. Review listener rule priorities

## Contributing

When adding new examples:

1. Follow the existing directory structure
2. Include comprehensive comments in the code
3. Update this README with example description
4. Test the example thoroughly
5. Include appropriate tags and documentation
``` 