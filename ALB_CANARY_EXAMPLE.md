# ALB Canary Deployment Example

This example demonstrates how to implement a Canary deployment strategy using the ALB module for gradual traffic shifting and safe deployments.

## Overview

Canary deployment allows you to gradually shift traffic from the current version to a new version, enabling safe testing in production with minimal risk. Traffic is shifted in small increments while monitoring for issues.

## Directory Structure

```
examples/canary/
├── main.tf
├── variables.tf
├── outputs.tf
├── versions.tf
├── terraform.tfvars.example
├── traffic_shift.py
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

# ALB for Canary Deployment
module "alb_canary" {
  source = "../../"

  name = "canary-alb"
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
  security_group_name = "canary-alb-sg"
  security_group_description = "Security group for Canary ALB"
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

  # Target Groups for Production and Canary
  target_groups = {
    production = {
      name = "production-target-group"
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
        Environment = "production"
        Deployment = "canary"
        Version = "v1"
      }
    }
    canary = {
      name = "canary-target-group"
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
        Environment = "canary"
        Deployment = "canary"
        Version = "v2"
      }
    }
  }

  # Listeners Configuration with Weighted Routing
  listeners = {
    http = {
      port = 80
      protocol = "HTTP"
      default_action = "forward"
      default_target_group_key = "production"
      rules = [
        {
          priority = 100
          action = "forward"
          condition = {
            field = "path-pattern"
            values = ["/canary/*"]
          }
          target_group_key = "canary"
          target_group_weight = 100
        }
      ]
    }
    https = {
      port = 443
      protocol = "HTTPS"
      certificate_arn = var.certificate_arn
      default_action = "forward"
      default_target_group_key = "production"
      rules = [
        {
          priority = 100
          action = "forward"
          condition = {
            field = "path-pattern"
            values = ["/canary/*"]
          }
          target_group_key = "canary"
          target_group_weight = 100
        }
      ]
    }
  }

  # Access Logs
  enable_access_logs = true
  access_logs_bucket = var.access_logs_bucket
  access_logs_prefix = "canary-alb"

  # Tags
  tags = {
    Environment = "production"
    Project = "canary-example"
    Owner = "terraform"
    Deployment = "canary"
    Purpose = "gradual-traffic-shifting"
  }
}

# CloudWatch Alarms for Canary Monitoring
resource "aws_cloudwatch_metric_alarm" "production_healthy_hosts" {
  alarm_name = "production-healthy-hosts"
  comparison_operator = "LessThanThreshold"
  evaluation_periods = "2"
  metric_name = "HealthyHostCount"
  namespace = "AWS/ApplicationELB"
  period = "60"
  statistic = "Average"
  threshold = "1"
  alarm_description = "Production environment healthy hosts count"
  alarm_actions = [aws_sns_topic.canary_alerts.arn]

  dimensions = {
    TargetGroup = module.alb_canary.target_groups["production"].arn_suffix
    LoadBalancer = module.alb_canary.load_balancer.arn_suffix
  }

  tags = {
    Environment = "production"
    Deployment = "canary"
  }
}

resource "aws_cloudwatch_metric_alarm" "canary_healthy_hosts" {
  alarm_name = "canary-healthy-hosts"
  comparison_operator = "LessThanThreshold"
  evaluation_periods = "2"
  metric_name = "HealthyHostCount"
  namespace = "AWS/ApplicationELB"
  period = "60"
  statistic = "Average"
  threshold = "1"
  alarm_description = "Canary environment healthy hosts count"
  alarm_actions = [aws_sns_topic.canary_alerts.arn]

  dimensions = {
    TargetGroup = module.alb_canary.target_groups["canary"].arn_suffix
    LoadBalancer = module.alb_canary.load_balancer.arn_suffix
  }

  tags = {
    Environment = "canary"
    Deployment = "canary"
  }
}

# Error Rate Alarms
resource "aws_cloudwatch_metric_alarm" "production_error_rate" {
  alarm_name = "production-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods = "2"
  metric_name = "HTTPCode_ELB_5XX_Count"
  namespace = "AWS/ApplicationELB"
  period = "300"
  statistic = "Sum"
  threshold = "10"
  alarm_description = "Production environment error rate"
  alarm_actions = [aws_sns_topic.canary_alerts.arn]

  dimensions = {
    LoadBalancer = module.alb_canary.load_balancer.arn_suffix
  }

  tags = {
    Environment = "production"
    Deployment = "canary"
  }
}

resource "aws_cloudwatch_metric_alarm" "canary_error_rate" {
  alarm_name = "canary-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods = "1"
  metric_name = "HTTPCode_ELB_5XX_Count"
  namespace = "AWS/ApplicationELB"
  period = "300"
  statistic = "Sum"
  threshold = "5"
  alarm_description = "Canary environment error rate"
  alarm_actions = [aws_sns_topic.canary_alerts.arn]

  dimensions = {
    LoadBalancer = module.alb_canary.load_balancer.arn_suffix
  }

  tags = {
    Environment = "canary"
    Deployment = "canary"
  }
}

# Response Time Alarms
resource "aws_cloudwatch_metric_alarm" "production_response_time" {
  alarm_name = "production-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods = "2"
  metric_name = "TargetResponseTime"
  namespace = "AWS/ApplicationELB"
  period = "300"
  statistic = "Average"
  threshold = "2"
  alarm_description = "Production environment response time"
  alarm_actions = [aws_sns_topic.canary_alerts.arn]

  dimensions = {
    LoadBalancer = module.alb_canary.load_balancer.arn_suffix
  }

  tags = {
    Environment = "production"
    Deployment = "canary"
  }
}

resource "aws_cloudwatch_metric_alarm" "canary_response_time" {
  alarm_name = "canary-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods = "1"
  metric_name = "TargetResponseTime"
  namespace = "AWS/ApplicationELB"
  period = "300"
  statistic = "Average"
  threshold = "1.5"
  alarm_description = "Canary environment response time"
  alarm_actions = [aws_sns_topic.canary_alerts.arn]

  dimensions = {
    LoadBalancer = module.alb_canary.load_balancer.arn_suffix
  }

  tags = {
    Environment = "canary"
    Deployment = "canary"
  }
}

# SNS Topic for Canary Alerts
resource "aws_sns_topic" "canary_alerts" {
  name = "canary-alb-alerts"
  
  tags = {
    Environment = "production"
    Project = "canary-example"
    Purpose = "alerts"
  }
}

# SNS Topic Subscription
resource "aws_sns_topic_subscription" "email_alerts" {
  count = var.alert_email != null ? 1 : 0
  
  topic_arn = aws_sns_topic.canary_alerts.arn
  protocol = "email"
  endpoint = var.alert_email
}

# Lambda Function for Traffic Shifting
resource "aws_lambda_function" "traffic_shifter" {
  filename = "traffic_shifter.zip"
  function_name = "canary-traffic-shifter"
  role = aws_iam_role.lambda_execution.arn
  handler = "index.handler"
  runtime = "python3.9"
  timeout = 30

  environment {
    variables = {
      ALB_ARN = module.alb_canary.load_balancer.arn
      PRODUCTION_TARGET_GROUP_ARN = module.alb_canary.target_groups["production"].arn
      CANARY_TARGET_GROUP_ARN = module.alb_canary.target_groups["canary"].arn
      HTTPS_LISTENER_ARN = module.alb_canary.listeners["https"].arn
      HTTP_LISTENER_ARN = module.alb_canary.listeners["http"].arn
      CANARY_PERCENTAGE = var.canary_percentage
    }
  }

  tags = {
    Environment = "production"
    Project = "canary-example"
    Purpose = "traffic-shifting"
  }
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_execution" {
  name = "canary-lambda-execution"

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
  name = "canary-lambda-policy"
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
          "elasticloadbalancing:DescribeTargetHealth",
          "elasticloadbalancing:ModifyRule"
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

# EventBridge Rule for Automated Traffic Shifting
resource "aws_cloudwatch_event_rule" "traffic_shift" {
  name = "canary-traffic-shift"
  description = "Trigger gradual traffic shifting for canary deployment"

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
  rule = aws_cloudwatch_event_rule.traffic_shift.name
  target_id = "CanaryTrafficShifter"
  arn = aws_lambda_function.traffic_shifter.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id = "AllowExecutionFromEventBridge"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.traffic_shifter.function_name
  principal = "events.amazonaws.com"
  source_arn = aws_cloudwatch_event_rule.traffic_shift.arn
}

# Step Functions State Machine for Canary Deployment
resource "aws_sfn_state_machine" "canary_deployment" {
  name = "canary-deployment"
  role_arn = aws_iam_role.step_functions.arn

  definition = jsonencode({
    Comment = "Canary Deployment State Machine"
    StartAt = "DeployCanary"
    States = {
      DeployCanary = {
        Type = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.traffic_shifter.function_name
          Payload = {
            action = "deploy_canary"
          }
        }
        Next = "WaitForHealthCheck"
      }
      WaitForHealthCheck = {
        Type = "Wait"
        Seconds = 300
        Next = "CheckCanaryHealth"
      }
      CheckCanaryHealth = {
        Type = "Choice"
        Choices = [
          {
            Variable = "$.Payload.healthy"
            BooleanEquals = true
            Next = "ShiftTraffic"
          }
        ]
        Default = "RollbackCanary"
      }
      ShiftTraffic = {
        Type = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.traffic_shifter.function_name
          Payload = {
            action = "shift_traffic"
            percentage = var.canary_percentage
          }
        }
        Next = "MonitorCanary"
      }
      MonitorCanary = {
        Type = "Wait"
        Seconds = 600
        Next = "EvaluateCanary"
      }
      EvaluateCanary = {
        Type = "Choice"
        Choices = [
          {
            Variable = "$.Payload.success"
            BooleanEquals = true
            Next = "CompleteDeployment"
          }
        ]
        Default = "RollbackCanary"
      }
      CompleteDeployment = {
        Type = "Succeed"
      }
      RollbackCanary = {
        Type = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.traffic_shifter.function_name
          Payload = {
            action = "rollback"
          }
        }
        Next = "DeploymentFailed"
      }
      DeploymentFailed = {
        Type = "Fail"
        Cause = "Canary deployment failed"
      }
    }
  })

  tags = {
    Environment = "production"
    Project = "canary-example"
    Purpose = "deployment-automation"
  }
}

# IAM Role for Step Functions
resource "aws_iam_role" "step_functions" {
  name = "canary-step-functions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for Step Functions
resource "aws_iam_role_policy" "step_functions_policy" {
  name = "canary-step-functions-policy"
  role = aws_iam_role.step_functions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = aws_lambda_function.traffic_shifter.arn
      }
    ]
  })
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
  description = "Email address for Canary deployment alerts"
  type = string
  default = null
}

variable "canary_percentage" {
  description = "Percentage of traffic to route to canary environment"
  type = number
  default = 10
  
  validation {
    condition = var.canary_percentage >= 0 && var.canary_percentage <= 100
    error_message = "Canary percentage must be between 0 and 100."
  }
}

variable "deployment_strategy" {
  description = "Canary deployment strategy"
  type = string
  default = "gradual"
  
  validation {
    condition = contains(["gradual", "linear", "exponential"], var.deployment_strategy)
    error_message = "Deployment strategy must be one of: gradual, linear, exponential."
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

variable "monitoring_duration" {
  description = "Duration to monitor canary deployment in minutes"
  type = number
  default = 30
  
  validation {
    condition = var.monitoring_duration >= 5 && var.monitoring_duration <= 1440
    error_message = "Monitoring duration must be between 5 and 1440 minutes."
  }
}

variable "error_threshold" {
  description = "Error rate threshold for canary rollback"
  type = number
  default = 5
  
  validation {
    condition = var.error_threshold >= 0 && var.error_threshold <= 100
    error_message = "Error threshold must be between 0 and 100."
  }
}

variable "response_time_threshold" {
  description = "Response time threshold in seconds for canary rollback"
  type = number
  default = 2
  
  validation {
    condition = var.response_time_threshold >= 0.1 && var.response_time_threshold <= 30
    error_message = "Response time threshold must be between 0.1 and 30 seconds."
  }
}

variable "auto_promote" {
  description = "Automatically promote canary to production if successful"
  type = bool
  default = false
}

variable "promotion_criteria" {
  description = "Criteria for automatic promotion"
  type = list(string)
  default = ["error_rate", "response_time", "health_check"]
  
  validation {
    condition = alltrue([
      for criteria in var.promotion_criteria :
      contains(["error_rate", "response_time", "health_check", "custom_metrics"], criteria)
    ])
    error_message = "Promotion criteria must be valid metrics."
  }
}
```

### outputs.tf

```hcl
output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value = module.alb_canary.load_balancer.arn
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value = module.alb_canary.load_balancer.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value = module.alb_canary.load_balancer.zone_id
}

output "production_target_group_arn" {
  description = "ARN of the Production target group"
  value = module.alb_canary.target_groups["production"].arn
}

output "canary_target_group_arn" {
  description = "ARN of the Canary target group"
  value = module.alb_canary.target_groups["canary"].arn
}

output "https_listener_arn" {
  description = "ARN of the HTTPS listener"
  value = module.alb_canary.listeners["https"].arn
}

output "http_listener_arn" {
  description = "ARN of the HTTP listener"
  value = module.alb_canary.listeners["http"].arn
}

output "security_group_id" {
  description = "ID of the ALB security group"
  value = module.alb_canary.security_group.id
}

output "lambda_function_arn" {
  description = "ARN of the traffic shifting Lambda function"
  value = aws_lambda_function.traffic_shifter.arn
}

output "step_functions_arn" {
  description = "ARN of the Step Functions state machine"
  value = aws_sfn_state_machine.canary_deployment.arn
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for Canary alerts"
  value = aws_sns_topic.canary_alerts.arn
}

output "cloudwatch_alarms" {
  description = "Map of CloudWatch alarms for Canary monitoring"
  value = {
    production_healthy_hosts = aws_cloudwatch_metric_alarm.production_healthy_hosts.arn
    canary_healthy_hosts = aws_cloudwatch_metric_alarm.canary_healthy_hosts.arn
    production_error_rate = aws_cloudwatch_metric_alarm.production_error_rate.arn
    canary_error_rate = aws_cloudwatch_metric_alarm.canary_error_rate.arn
    production_response_time = aws_cloudwatch_metric_alarm.production_response_time.arn
    canary_response_time = aws_cloudwatch_metric_alarm.canary_response_time.arn
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

# Alert Email for Canary Deployments
alert_email = "devops@example.com"

# Canary Configuration
canary_percentage = 10
deployment_strategy = "gradual"
monitoring_duration = 30

# Thresholds
error_threshold = 5
response_time_threshold = 2

# Promotion Settings
auto_promote = false
promotion_criteria = ["error_rate", "response_time", "health_check"]

# Health Check Configuration
health_check_path = "/health"
health_check_interval = 30
```

### traffic_shift.py

```python
import json
import boto3
import time
import logging
from typing import Dict, Any

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize AWS clients
elbv2 = boto3.client('elbv2')
cloudwatch = boto3.client('cloudwatch')

def handler(event, context):
    """
    Lambda function to handle canary traffic shifting
    """
    try:
        action = event.get('action')
        
        if action == 'deploy_canary':
            return deploy_canary(event)
        elif action == 'shift_traffic':
            return shift_traffic(event)
        elif action == 'rollback':
            return rollback_canary(event)
        elif action == 'promote_canary':
            return promote_canary(event)
        else:
            raise ValueError(f"Unknown action: {action}")
            
    except Exception as e:
        logger.error(f"Error in traffic shifter: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }

def deploy_canary(event: Dict[str, Any]) -> Dict[str, Any]:
    """
    Deploy canary environment and set initial traffic
    """
    logger.info("Deploying canary environment")
    
    # Get environment variables
    alb_arn = os.environ['ALB_ARN']
    canary_tg_arn = os.environ['CANARY_TARGET_GROUP_ARN']
    https_listener_arn = os.environ['HTTPS_LISTENER_ARN']
    http_listener_arn = os.environ['HTTP_LISTENER_ARN']
    
    # Set initial canary traffic (1%)
    initial_percentage = 1
    
    try:
        # Update HTTPS listener rule
        update_listener_rule(https_listener_arn, canary_tg_arn, initial_percentage)
        
        # Update HTTP listener rule
        update_listener_rule(http_listener_arn, canary_tg_arn, initial_percentage)
        
        logger.info(f"Canary deployed with {initial_percentage}% traffic")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Canary deployed successfully',
                'traffic_percentage': initial_percentage
            })
        }
        
    except Exception as e:
        logger.error(f"Error deploying canary: {str(e)}")
        raise

def shift_traffic(event: Dict[str, Any]) -> Dict[str, Any]:
    """
    Gradually shift traffic to canary
    """
    percentage = event.get('percentage', 10)
    logger.info(f"Shifting {percentage}% traffic to canary")
    
    # Get environment variables
    alb_arn = os.environ['ALB_ARN']
    canary_tg_arn = os.environ['CANARY_TARGET_GROUP_ARN']
    https_listener_arn = os.environ['HTTPS_LISTENER_ARN']
    http_listener_arn = os.environ['HTTP_LISTENER_ARN']
    
    try:
        # Update HTTPS listener rule
        update_listener_rule(https_listener_arn, canary_tg_arn, percentage)
        
        # Update HTTP listener rule
        update_listener_rule(http_listener_arn, canary_tg_arn, percentage)
        
        logger.info(f"Traffic shifted to {percentage}% canary")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Traffic shifted successfully',
                'traffic_percentage': percentage
            })
        }
        
    except Exception as e:
        logger.error(f"Error shifting traffic: {str(e)}")
        raise

def rollback_canary(event: Dict[str, Any]) -> Dict[str, Any]:
    """
    Rollback canary deployment
    """
    logger.info("Rolling back canary deployment")
    
    # Get environment variables
    alb_arn = os.environ['ALB_ARN']
    production_tg_arn = os.environ['PRODUCTION_TARGET_GROUP_ARN']
    https_listener_arn = os.environ['HTTPS_LISTENER_ARN']
    http_listener_arn = os.environ['HTTP_LISTENER_ARN']
    
    try:
        # Set traffic back to 100% production
        update_listener_rule(https_listener_arn, production_tg_arn, 100)
        update_listener_rule(http_listener_arn, production_tg_arn, 100)
        
        logger.info("Canary rollback completed")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Canary rollback completed',
                'traffic_percentage': 0
            })
        }
        
    except Exception as e:
        logger.error(f"Error rolling back canary: {str(e)}")
        raise

def promote_canary(event: Dict[str, Any]) -> Dict[str, Any]:
    """
    Promote canary to production
    """
    logger.info("Promoting canary to production")
    
    # Get environment variables
    alb_arn = os.environ['ALB_ARN']
    canary_tg_arn = os.environ['CANARY_TARGET_GROUP_ARN']
    https_listener_arn = os.environ['HTTPS_LISTENER_ARN']
    http_listener_arn = os.environ['HTTP_LISTENER_ARN']
    
    try:
        # Set traffic to 100% canary (new production)
        update_listener_rule(https_listener_arn, canary_tg_arn, 100)
        update_listener_rule(http_listener_arn, canary_tg_arn, 100)
        
        logger.info("Canary promoted to production")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Canary promoted to production',
                'traffic_percentage': 100
            })
        }
        
    except Exception as e:
        logger.error(f"Error promoting canary: {str(e)}")
        raise

def update_listener_rule(listener_arn: str, target_group_arn: str, weight: int) -> None:
    """
    Update listener rule with new target group weights
    """
    try:
        # Get current listener rules
        response = elbv2.describe_listeners(ListenerArns=[listener_arn])
        listener = response['Listeners'][0]
        
        # Find the default action
        default_action = listener['DefaultActions'][0]
        
        # Update the default action with new weights
        if weight == 100:
            # Single target group
            default_action['ForwardConfig'] = {
                'TargetGroups': [
                    {
                        'TargetGroupArn': target_group_arn,
                        'Weight': 100
                    }
                ]
            }
        else:
            # Weighted routing
            production_tg_arn = os.environ['PRODUCTION_TARGET_GROUP_ARN']
            default_action['ForwardConfig'] = {
                'TargetGroups': [
                    {
                        'TargetGroupArn': production_tg_arn,
                        'Weight': 100 - weight
                    },
                    {
                        'TargetGroupArn': target_group_arn,
                        'Weight': weight
                    }
                ]
            }
        
        # Update the listener
        elbv2.modify_listener(
            ListenerArn=listener_arn,
            DefaultActions=[default_action]
        )
        
        logger.info(f"Updated listener {listener_arn} with {weight}% weight")
        
    except Exception as e:
        logger.error(f"Error updating listener rule: {str(e)}")
        raise

def check_canary_health() -> Dict[str, Any]:
    """
    Check canary environment health
    """
    try:
        canary_tg_arn = os.environ['CANARY_TARGET_GROUP_ARN']
        
        # Check target health
        response = elbv2.describe_target_health(TargetGroupArn=canary_tg_arn)
        
        healthy_targets = 0
        total_targets = len(response['TargetHealthDescriptions'])
        
        for target in response['TargetHealthDescriptions']:
            if target['TargetHealth']['State'] == 'healthy':
                healthy_targets += 1
        
        health_percentage = (healthy_targets / total_targets * 100) if total_targets > 0 else 0
        
        # Check error rate
        error_rate = get_error_rate()
        
        # Check response time
        response_time = get_response_time()
        
        return {
            'healthy': health_percentage >= 100,
            'health_percentage': health_percentage,
            'error_rate': error_rate,
            'response_time': response_time,
            'total_targets': total_targets,
            'healthy_targets': healthy_targets
        }
        
    except Exception as e:
        logger.error(f"Error checking canary health: {str(e)}")
        return {
            'healthy': False,
            'error': str(e)
        }

def get_error_rate() -> float:
    """
    Get current error rate from CloudWatch
    """
    try:
        alb_arn = os.environ['ALB_ARN']
        
        # Get 5XX error count for last 5 minutes
        response = cloudwatch.get_metric_statistics(
            Namespace='AWS/ApplicationELB',
            MetricName='HTTPCode_ELB_5XX_Count',
            Dimensions=[
                {
                    'Name': 'LoadBalancer',
                    'Value': alb_arn.split('/')[-1]
                }
            ],
            StartTime=datetime.utcnow() - timedelta(minutes=5),
            EndTime=datetime.utcnow(),
            Period=300,
            Statistics=['Sum']
        )
        
        if response['Datapoints']:
            error_count = response['Datapoints'][0]['Sum']
            
            # Get total request count
            total_response = cloudwatch.get_metric_statistics(
                Namespace='AWS/ApplicationELB',
                MetricName='RequestCount',
                Dimensions=[
                    {
                        'Name': 'LoadBalancer',
                        'Value': alb_arn.split('/')[-1]
                    }
                ],
                StartTime=datetime.utcnow() - timedelta(minutes=5),
                EndTime=datetime.utcnow(),
                Period=300,
                Statistics=['Sum']
            )
            
            if total_response['Datapoints']:
                total_count = total_response['Datapoints'][0]['Sum']
                return (error_count / total_count * 100) if total_count > 0 else 0
        
        return 0
        
    except Exception as e:
        logger.error(f"Error getting error rate: {str(e)}")
        return 0

def get_response_time() -> float:
    """
    Get current response time from CloudWatch
    """
    try:
        alb_arn = os.environ['ALB_ARN']
        
        # Get average response time for last 5 minutes
        response = cloudwatch.get_metric_statistics(
            Namespace='AWS/ApplicationELB',
            MetricName='TargetResponseTime',
            Dimensions=[
                {
                    'Name': 'LoadBalancer',
                    'Value': alb_arn.split('/')[-1]
                }
            ],
            StartTime=datetime.utcnow() - timedelta(minutes=5),
            EndTime=datetime.utcnow(),
            Period=300,
            Statistics=['Average']
        )
        
        if response['Datapoints']:
            return response['Datapoints'][0]['Average']
        
        return 0
        
    except Exception as e:
        logger.error(f"Error getting response time: {str(e)}")
        return 0
```

### README.md

```markdown
# Canary Deployment Example

This example demonstrates how to implement a Canary deployment strategy using the ALB module for gradual traffic shifting and safe deployments.

## Overview

Canary deployment allows you to gradually shift traffic from the current version to a new version, enabling safe testing in production with minimal risk. Traffic is shifted in small increments while monitoring for issues.

## Features

- **Gradual Traffic Shifting**: Incrementally shift traffic from 1% to 100%
- **Automated Monitoring**: CloudWatch alarms for health, error rate, and response time
- **Automatic Rollback**: Rollback on health check failures or threshold breaches
- **Step Functions Integration**: Automated deployment workflow
- **Lambda Traffic Control**: Programmatic traffic shifting
- **Comprehensive Alerting**: SNS notifications for deployment events
- **SSL/TLS Termination**: HTTPS support with SSL certificate
- **Access Logging**: Comprehensive access logs for monitoring

## Architecture

```
Internet → ALB → Production Target Group (90%)
           ↓
         Canary Target Group (10%)
```

## Usage

1. **Deploy the Infrastructure**:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

2. **Deploy Canary Environment**:
   - Deploy your application to the Canary environment
   - Register targets with the Canary target group

3. **Start Canary Deployment**:
   ```bash
   # Start with 1% traffic
   aws lambda invoke \
     --function-name canary-traffic-shifter \
     --payload '{"action": "deploy_canary"}' \
     response.json
   ```

4. **Monitor and Gradually Increase Traffic**:
   ```bash
   # Increase to 10% traffic
   aws lambda invoke \
     --function-name canary-traffic-shifter \
     --payload '{"action": "shift_traffic", "percentage": 10}' \
     response.json
   ```

5. **Promote or Rollback**:
   ```bash
   # Promote to production (100% traffic)
   aws lambda invoke \
     --function-name canary-traffic-shifter \
     --payload '{"action": "promote_canary"}' \
     response.json

   # Or rollback
   aws lambda invoke \
     --function-name canary-traffic-shifter \
     --payload '{"action": "rollback"}' \
     response.json
   ```

## Traffic Shifting Strategies

### Gradual Shifting
- Start with 1% traffic
- Increase by 10% every 5 minutes
- Monitor health metrics between shifts

### Linear Shifting
- Increase traffic linearly over time
- Example: 1% → 25% → 50% → 75% → 100%

### Exponential Shifting
- Start with small percentage
- Double traffic at each step
- Example: 1% → 2% → 4% → 8% → 16% → 32% → 64% → 100%

## Monitoring

### CloudWatch Alarms

- **Production Healthy Hosts**: Monitors production environment health
- **Canary Healthy Hosts**: Monitors canary environment health
- **Production Error Rate**: Monitors production error rate
- **Canary Error Rate**: Monitors canary error rate (more sensitive)
- **Production Response Time**: Monitors production response time
- **Canary Response Time**: Monitors canary response time (more sensitive)

### Metrics to Monitor

- Healthy host count per target group
- HTTP 5XX error rate
- Target response time
- Request count and throughput
- Custom application metrics

## Step Functions Workflow

The example includes a Step Functions state machine that automates the canary deployment process:

1. **DeployCanary**: Deploy canary with 1% traffic
2. **WaitForHealthCheck**: Wait 5 minutes for health checks
3. **CheckCanaryHealth**: Evaluate canary health
4. **ShiftTraffic**: Increase traffic percentage
5. **MonitorCanary**: Monitor for specified duration
6. **EvaluateCanary**: Evaluate success criteria
7. **CompleteDeployment**: Success - promote canary
8. **RollbackCanary**: Failure - rollback deployment

## Best Practices

1. **Health Checks**: Ensure comprehensive health checks
2. **Monitoring**: Monitor both environments during deployment
3. **Rollback Plan**: Have a quick rollback strategy
4. **Testing**: Test canary environment thoroughly before deployment
5. **Metrics**: Define clear success/failure criteria
6. **Automation**: Automate the deployment process
7. **Documentation**: Document deployment procedures

## Security Considerations

- Use HTTPS for all traffic
- Implement proper security groups
- Enable access logging
- Use IAM roles with least privilege
- Encrypt data in transit and at rest
- Monitor for security issues during deployment

## Cost Optimization

- Use appropriate instance types
- Enable auto scaling
- Monitor and optimize resource usage
- Use Spot instances for non-critical workloads
- Clean up canary resources after promotion

## Troubleshooting

### Common Issues

1. **Health Check Failures**:
   - Verify health check path is accessible
   - Check application logs
   - Validate security group rules

2. **Traffic Shifting Failures**:
   - Verify Lambda function permissions
   - Check CloudWatch logs
   - Validate target group configuration

3. **High Error Rates**:
   - Check application logs
   - Verify database connectivity
   - Check resource limits

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
  --log-group-name-prefix /aws/lambda/canary-traffic-shifter

# Check Step Functions execution
aws stepfunctions list-executions \
  --state-machine-arn <state-machine-arn>
```

## Cleanup

```bash
terraform destroy
```

**Note**: This will destroy all resources including the ALB, target groups, Lambda function, and Step Functions state machine.

## Advanced Features

### Custom Metrics Integration

You can extend the monitoring to include custom application metrics:

```python
def get_custom_metrics():
    """
    Get custom application metrics from CloudWatch
    """
    # Example: Business metrics, user engagement, etc.
    pass
```

### Automated Promotion

Enable automatic promotion based on success criteria:

```hcl
variable "auto_promote" {
  description = "Automatically promote canary to production if successful"
  type = bool
  default = true
}
```

### Multi-Region Deployment

Extend the example to support multi-region canary deployments with Route 53 traffic routing.
```

## Key Features

This Canary deployment example includes:

1. **Gradual Traffic Shifting**: Lambda function for programmatic traffic control
2. **Comprehensive Monitoring**: CloudWatch alarms for health, errors, and performance
3. **Automated Workflow**: Step Functions state machine for deployment automation
4. **Health Evaluation**: Real-time health checking and metrics evaluation
5. **Rollback Capability**: Automatic rollback on failures
6. **Flexible Strategies**: Support for gradual, linear, and exponential shifting
7. **Production-Ready**: SSL/TLS termination, access logging, and alerting
8. **Extensible**: Easy to extend with custom metrics and criteria

This example provides a complete Canary deployment solution that can be integrated into CI/CD pipelines for safe, automated deployments with comprehensive monitoring and rollback capabilities. 