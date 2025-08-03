# ALB Blue-Green Deployment Example

This example demonstrates how to implement a Blue-Green deployment strategy using the ALB module for zero-downtime deployments.

## Overview

Blue-Green deployment allows you to deploy new versions of your application with zero downtime by maintaining two identical production environments (Blue and Green). Only one environment serves traffic at a time, allowing for safe rollbacks.

## Directory Structure

```
examples/blue-green/
├── main.tf
├── variables.tf
├── outputs.tf
├── versions.tf
├── terraform.tfvars.example
└── README.md
```

## Implementation

### main.tf

```hcl
# Data Sources
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  
  filter {
    name   = "map-public-ip-on-launch"
    values = ["true"]
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  
  filter {
    name   = "map-public-ip-on-launch"
    values = ["false"]
  }
}

# ALB for Blue-Green Deployment
module "alb_blue_green" {
  source = "../../"

  name = "blue-green-alb"
  vpc_id = data.aws_vpc.default.id
  subnet_ids = data.aws_subnets.public.ids

  # ALB Configuration
  internal = false
  enable_http = true
  enable_https = true
  enable_deletion_protection = true
  enable_http2 = true
  idle_timeout = 60

  # Security Group Configuration
  create_security_group = true
  security_group_name = "blue-green-alb-sg"
  security_group_description = "Security group for Blue-Green ALB"
  security_group_rules = [
    {
      type = "ingress"
      from_port = 80
      to_port = 80
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTP access"
    },
    {
      type = "ingress"
      from_port = 443
      to_port = 443
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTPS access"
    },
    {
      type = "egress"
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow all outbound traffic"
    }
  ]

  # Target Groups for Blue and Green Environments
  target_groups = {
    blue = {
      name = "blue-target-group"
      port = 80
      protocol = "HTTP"
      target_type = "ip"
      health_check = {
        enabled = true
        healthy_threshold = 2
        interval = 30
        matcher = "200"
        path = "/health"
        port = "traffic-port"
        protocol = "HTTP"
        timeout = 5
        unhealthy_threshold = 2
      }
      tags = {
        Environment = "blue"
        Deployment = "blue-green"
      }
    }
    green = {
      name = "green-target-group"
      port = 80
      protocol = "HTTP"
      target_type = "ip"
      health_check = {
        enabled = true
        healthy_threshold = 2
        interval = 30
        matcher = "200"
        path = "/health"
        port = "traffic-port"
        protocol = "HTTP"
        timeout = 5
        unhealthy_threshold = 2
      }
      tags = {
        Environment = "green"
        Deployment = "blue-green"
      }
    }
  }

  # Listeners Configuration
  listeners = {
    http = {
      port = 80
      protocol = "HTTP"
      default_action = "forward"
      default_target_group_key = "blue" # Start with Blue environment
      rules = []
    }
    https = {
      port = 443
      protocol = "HTTPS"
      certificate_arn = var.certificate_arn
      default_action = "forward"
      default_target_group_key = "blue" # Start with Blue environment
      rules = []
    }
  }

  # Access Logs
  enable_access_logs = true
  access_logs_bucket = var.access_logs_bucket
  access_logs_prefix = "blue-green-alb"

  # Tags
  tags = {
    Environment = "production"
    Project = "blue-green-example"
    Owner = "terraform"
    Deployment = "blue-green"
    Purpose = "zero-downtime-deployment"
  }
}

# CloudWatch Alarms for Blue-Green Monitoring
resource "aws_cloudwatch_metric_alarm" "blue_healthy_hosts" {
  alarm_name = "blue-healthy-hosts"
  comparison_operator = "LessThanThreshold"
  evaluation_periods = "2"
  metric_name = "HealthyHostCount"
  namespace = "AWS/ApplicationELB"
  period = "60"
  statistic = "Average"
  threshold = "1"
  alarm_description = "Blue environment healthy hosts count"
  alarm_actions = [aws_sns_topic.blue_green_alerts.arn]

  dimensions = {
    TargetGroup = module.alb_blue_green.target_groups["blue"].arn_suffix
    LoadBalancer = module.alb_blue_green.load_balancer.arn_suffix
  }

  tags = {
    Environment = "blue"
    Deployment = "blue-green"
  }
}

resource "aws_cloudwatch_metric_alarm" "green_healthy_hosts" {
  alarm_name = "green-healthy-hosts"
  comparison_operator = "LessThanThreshold"
  evaluation_periods = "2"
  metric_name = "HealthyHostCount"
  namespace = "AWS/ApplicationELB"
  period = "60"
  statistic = "Average"
  threshold = "1"
  alarm_description = "Green environment healthy hosts count"
  alarm_actions = [aws_sns_topic.blue_green_alerts.arn]

  dimensions = {
    TargetGroup = module.alb_blue_green.target_groups["green"].arn_suffix
    LoadBalancer = module.alb_blue_green.load_balancer.arn_suffix
  }

  tags = {
    Environment = "green"
    Deployment = "blue-green"
  }
}

# SNS Topic for Blue-Green Alerts
resource "aws_sns_topic" "blue_green_alerts" {
  name = "blue-green-alb-alerts"
  
  tags = {
    Environment = "production"
    Project = "blue-green-example"
    Purpose = "alerts"
  }
}

# SNS Topic Subscription (example)
resource "aws_sns_topic_subscription" "email_alerts" {
  count = var.alert_email != null ? 1 : 0
  
  topic_arn = aws_sns_topic.blue_green_alerts.arn
  protocol = "email"
  endpoint = var.alert_email
}

# Lambda Function for Blue-Green Traffic Switching
resource "aws_lambda_function" "traffic_switcher" {
  filename = "traffic_switcher.zip"
  function_name = "blue-green-traffic-switcher"
  role = aws_iam_role.lambda_execution.arn
  handler = "index.handler"
  runtime = "python3.9"
  timeout = 30

  environment {
    variables = {
      ALB_ARN = module.alb_blue_green.load_balancer.arn
      BLUE_TARGET_GROUP_ARN = module.alb_blue_green.target_groups["blue"].arn
      GREEN_TARGET_GROUP_ARN = module.alb_blue_green.target_groups["green"].arn
      HTTPS_LISTENER_ARN = module.alb_blue_green.listeners["https"].arn
      HTTP_LISTENER_ARN = module.alb_blue_green.listeners["http"].arn
    }
  }

  tags = {
    Environment = "production"
    Project = "blue-green-example"
    Purpose = "traffic-switching"
  }
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_execution" {
  name = "blue-green-lambda-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for Lambda
resource "aws_iam_role_policy" "lambda_policy" {
  name = "blue-green-lambda-policy"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:ModifyListener",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetHealth"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# EventBridge Rule for Automated Traffic Switching
resource "aws_cloudwatch_event_rule" "traffic_switch" {
  name = "blue-green-traffic-switch"
  description = "Trigger traffic switching between Blue and Green environments"

  event_pattern = jsonencode({
    source = ["aws.ecs"]
    detail-type = ["ECS Task State Change"]
    detail = {
      lastStatus = ["RUNNING"]
      desiredStatus = ["RUNNING"]
    }
  })
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule = aws_cloudwatch_event_rule.traffic_switch.name
  target_id = "BlueGreenTrafficSwitcher"
  arn = aws_lambda_function.traffic_switcher.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id = "AllowExecutionFromEventBridge"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.traffic_switcher.function_name
  principal = "events.amazonaws.com"
  source_arn = aws_cloudwatch_event_rule.traffic_switch.arn
}
```

### variables.tf

```hcl
variable "certificate_arn" {
  description = "ARN of the SSL certificate for HTTPS listener"
  type = string
  default = null
}

variable "access_logs_bucket" {
  description = "S3 bucket for ALB access logs"
  type = string
  default = null
}

variable "alert_email" {
  description = "Email address for Blue-Green deployment alerts"
  type = string
  default = null
}

variable "environment" {
  description = "Deployment environment"
  type = string
  default = "production"
  
  validation {
    condition = contains(["production", "staging", "development"], var.environment)
    error_message = "Environment must be one of: production, staging, development."
  }
}

variable "deployment_strategy" {
  description = "Blue-Green deployment strategy"
  type = string
  default = "manual"
  
  validation {
    condition = contains(["manual", "automatic", "semi-automatic"], var.deployment_strategy)
    error_message = "Deployment strategy must be one of: manual, automatic, semi-automatic."
  }
}

variable "health_check_path" {
  description = "Health check path for target groups"
  type = string
  default = "/health"
}

variable "health_check_interval" {
  description = "Health check interval in seconds"
  type = number
  default = 30
  
  validation {
    condition = var.health_check_interval >= 5 && var.health_check_interval <= 300
    error_message = "Health check interval must be between 5 and 300 seconds."
  }
}

variable "health_check_timeout" {
  description = "Health check timeout in seconds"
  type = number
  default = 5
  
  validation {
    condition = var.health_check_timeout >= 2 && var.health_check_timeout <= 60
    error_message = "Health check timeout must be between 2 and 60 seconds."
  }
}

variable "healthy_threshold" {
  description = "Number of consecutive health checks required for healthy status"
  type = number
  default = 2
  
  validation {
    condition = var.healthy_threshold >= 2 && var.healthy_threshold <= 10
    error_message = "Healthy threshold must be between 2 and 10."
  }
}

variable "unhealthy_threshold" {
  description = "Number of consecutive health checks required for unhealthy status"
  type = number
  default = 2
  
  validation {
    condition = var.unhealthy_threshold >= 2 && var.unhealthy_threshold <= 10
    error_message = "Unhealthy threshold must be between 2 and 10."
  }
}
```

### outputs.tf

```hcl
output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value = module.alb_blue_green.load_balancer.arn
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value = module.alb_blue_green.load_balancer.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value = module.alb_blue_green.load_balancer.zone_id
}

output "blue_target_group_arn" {
  description = "ARN of the Blue target group"
  value = module.alb_blue_green.target_groups["blue"].arn
}

output "green_target_group_arn" {
  description = "ARN of the Green target group"
  value = module.alb_blue_green.target_groups["green"].arn
}

output "https_listener_arn" {
  description = "ARN of the HTTPS listener"
  value = module.alb_blue_green.listeners["https"].arn
}

output "http_listener_arn" {
  description = "ARN of the HTTP listener"
  value = module.alb_blue_green.listeners["http"].arn
}

output "security_group_id" {
  description = "ID of the ALB security group"
  value = module.alb_blue_green.security_group.id
}

output "lambda_function_arn" {
  description = "ARN of the traffic switching Lambda function"
  value = aws_lambda_function.traffic_switcher.arn
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for Blue-Green alerts"
  value = aws_sns_topic.blue_green_alerts.arn
}

output "cloudwatch_alarms" {
  description = "Map of CloudWatch alarms for Blue-Green monitoring"
  value = {
    blue_healthy_hosts = aws_cloudwatch_metric_alarm.blue_healthy_hosts.arn
    green_healthy_hosts = aws_cloudwatch_metric_alarm.green_healthy_hosts.arn
  }
}
```

### versions.tf

```hcl
terraform {
  required_version = "1.13.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.2.0"
    }
  }
}

# Terragrunt version: 0.84.0
```

### terraform.tfvars.example

```hcl
# SSL Certificate ARN (required for HTTPS)
certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"

# S3 Bucket for Access Logs
access_logs_bucket = "my-alb-access-logs-bucket"

# Alert Email for Blue-Green Deployments
alert_email = "devops@example.com"

# Deployment Configuration
environment = "production"
deployment_strategy = "semi-automatic"

# Health Check Configuration
health_check_path = "/health"
health_check_interval = 30
health_check_timeout = 5
healthy_threshold = 2
unhealthy_threshold = 2
```

### README.md

```markdown
# Blue-Green Deployment Example

This example demonstrates how to implement a Blue-Green deployment strategy using the ALB module for zero-downtime deployments.

## Overview

Blue-Green deployment maintains two identical production environments (Blue and Green). Only one environment serves traffic at a time, allowing for safe rollbacks and zero-downtime deployments.

## Features

- **Zero-Downtime Deployments**: Switch traffic between Blue and Green environments
- **Automated Traffic Switching**: Lambda function for automated traffic switching
- **Health Monitoring**: CloudWatch alarms for both environments
- **Rollback Capability**: Quick rollback by switching traffic back
- **SSL/TLS Termination**: HTTPS support with SSL certificate
- **Access Logging**: Comprehensive access logs for monitoring
- **Alerting**: SNS notifications for deployment events

## Architecture

```
Internet → ALB → Blue Target Group (Active)
           ↓
         Green Target Group (Standby)
```

## Usage

1. **Deploy the Infrastructure**:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

2. **Deploy to Blue Environment**:
   - Deploy your application to the Blue environment
   - Register targets with the Blue target group

3. **Test Green Environment**:
   - Deploy your application to the Green environment
   - Register targets with the Green target group
   - Test the Green environment thoroughly

4. **Switch Traffic**:
   - Use the Lambda function to switch traffic to Green
   - Monitor the deployment

5. **Rollback (if needed)**:
   - Switch traffic back to Blue if issues are detected

## Traffic Switching

### Manual Switching

Use the AWS CLI to switch traffic:

```bash
# Switch to Green
aws lambda invoke \
  --function-name blue-green-traffic-switcher \
  --payload '{"action": "switch_to_green"}' \
  response.json

# Switch to Blue
aws lambda invoke \
  --function-name blue-green-traffic-switcher \
  --payload '{"action": "switch_to_blue"}' \
  response.json
```

### Automated Switching

The Lambda function can be triggered by:
- EventBridge rules
- CloudWatch alarms
- Manual invocation
- CI/CD pipeline events

## Monitoring

### CloudWatch Alarms

- **Blue Healthy Hosts**: Monitors Blue environment health
- **Green Healthy Hosts**: Monitors Green environment health

### Metrics to Monitor

- Healthy host count per target group
- Response time
- Error rate
- Request count

## Best Practices

1. **Health Checks**: Ensure comprehensive health checks
2. **Testing**: Thoroughly test Green environment before switching
3. **Monitoring**: Monitor both environments during deployment
4. **Rollback Plan**: Have a quick rollback strategy
5. **Database Migrations**: Handle database schema changes carefully
6. **Session State**: Consider session state management

## Security Considerations

- Use HTTPS for all traffic
- Implement proper security groups
- Enable access logging
- Use IAM roles with least privilege
- Encrypt data in transit and at rest

## Cost Optimization

- Use appropriate instance types
- Enable auto scaling
- Monitor and optimize resource usage
- Use Spot instances for non-critical workloads

## Troubleshooting

### Common Issues

1. **Health Check Failures**:
   - Verify health check path is accessible
   - Check application logs
   - Validate security group rules

2. **Traffic Switching Failures**:
   - Verify Lambda function permissions
   - Check CloudWatch logs
   - Validate target group configuration

3. **SSL Certificate Issues**:
   - Verify certificate ARN
   - Check certificate validity
   - Ensure proper domain configuration

### Debugging Commands

```bash
# Check target health
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn>

# Check listener rules
aws elbv2 describe-listeners \
  --load-balancer-arn <alb-arn>

# Check Lambda logs
aws logs describe-log-groups \
  --log-group-name-prefix /aws/lambda/blue-green-traffic-switcher
```

## Cleanup

```bash
terraform destroy
```

**Note**: This will destroy all resources including the ALB, target groups, and Lambda function.
```

## Key Features

This Blue-Green deployment example includes:

1. **Dual Target Groups**: Separate target groups for Blue and Green environments
2. **Automated Traffic Switching**: Lambda function for switching traffic between environments
3. **Health Monitoring**: CloudWatch alarms for both environments
4. **Event-Driven Architecture**: EventBridge rules for automated switching
5. **Comprehensive Monitoring**: SNS alerts and CloudWatch metrics
6. **Security**: SSL/TLS termination and proper security groups
7. **Logging**: Access logs and Lambda function logs
8. **Rollback Capability**: Quick rollback by switching traffic back

This example provides a complete Blue-Green deployment solution that can be integrated into CI/CD pipelines for automated deployments with zero downtime. 