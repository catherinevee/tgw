# ALB Enhanced Monitoring Example

This example demonstrates how to implement comprehensive monitoring and observability for the ALB module with advanced alerting, logging, and dashboard capabilities.

## Overview

Enhanced monitoring provides comprehensive visibility into ALB performance, health, and security with automated alerting, detailed logging, and operational dashboards.

## Directory Structure

```
examples/monitoring/
├── main.tf
├── variables.tf
├── outputs.tf
├── versions.tf
├── terraform.tfvars.example
├── cloudwatch_dashboard.json
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

# ALB with Enhanced Monitoring
module "alb_monitoring" {
  source = "../../"

  name = "monitoring-alb"
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
  security_group_name = "monitoring-alb-sg"
  security_group_description = "Security group for Monitoring ALB"
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

  # Target Groups
  target_groups = {
    app = {
      name = "app-target-group"
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
        Monitoring = "enabled"
      }
    }
  }

  # Listeners Configuration
  listeners = {
    http = {
      port = 80
      protocol = "HTTP"
      default_action = "forward"
      default_target_group_key = "app"
      rules = []
    }
    https = {
      port = 443
      protocol = "HTTPS"
      certificate_arn = var.certificate_arn
      default_action = "forward"
      default_target_group_key = "app"
      rules = []
    }
  }

  # Access Logs
  enable_access_logs = true
  access_logs_bucket = var.access_logs_bucket
  access_logs_prefix = "monitoring-alb"

  # Tags
  tags = {
    Environment = "production"
    Project = "monitoring-example"
    Owner = "terraform"
    Monitoring = "enhanced"
    Purpose = "observability"
  }
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "alb_monitoring" {
  dashboard_name = "alb-monitoring-dashboard"
  dashboard_body = file("${path.module}/cloudwatch_dashboard.json")
}

# CloudWatch Alarms - Performance
resource "aws_cloudwatch_metric_alarm" "response_time" {
  alarm_name = "alb-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods = "2"
  metric_name = "TargetResponseTime"
  namespace = "AWS/ApplicationELB"
  period = "300"
  statistic = "Average"
  threshold = "2"
  alarm_description = "ALB response time is high"
  alarm_actions = [aws_sns_topic.monitoring_alerts.arn]

  dimensions = {
    LoadBalancer = module.alb_monitoring.load_balancer.arn_suffix
  }

  tags = {
    Environment = "production"
    Metric = "response_time"
  }
}

resource "aws_cloudwatch_metric_alarm" "request_count" {
  alarm_name = "alb-request-count"
  comparison_operator = "LessThanThreshold"
  evaluation_periods = "2"
  metric_name = "RequestCount"
  namespace = "AWS/ApplicationELB"
  period = "300"
  statistic = "Sum"
  threshold = "10"
  alarm_description = "ALB request count is low"
  alarm_actions = [aws_sns_topic.monitoring_alerts.arn]

  dimensions = {
    LoadBalancer = module.alb_monitoring.load_balancer.arn_suffix
  }

  tags = {
    Environment = "production"
    Metric = "request_count"
  }
}

# CloudWatch Alarms - Health
resource "aws_cloudwatch_metric_alarm" "healthy_hosts" {
  alarm_name = "alb-healthy-hosts"
  comparison_operator = "LessThanThreshold"
  evaluation_periods = "2"
  metric_name = "HealthyHostCount"
  namespace = "AWS/ApplicationELB"
  period = "60"
  statistic = "Average"
  threshold = "1"
  alarm_description = "ALB healthy hosts count is low"
  alarm_actions = [aws_sns_topic.monitoring_alerts.arn]

  dimensions = {
    TargetGroup = module.alb_monitoring.target_groups["app"].arn_suffix
    LoadBalancer = module.alb_monitoring.load_balancer.arn_suffix
  }

  tags = {
    Environment = "production"
    Metric = "healthy_hosts"
  }
}

resource "aws_cloudwatch_metric_alarm" "unhealthy_hosts" {
  alarm_name = "alb-unhealthy-hosts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods = "1"
  metric_name = "UnHealthyHostCount"
  namespace = "AWS/ApplicationELB"
  period = "60"
  statistic = "Average"
  threshold = "0"
  alarm_description = "ALB has unhealthy hosts"
  alarm_actions = [aws_sns_topic.monitoring_alerts.arn]

  dimensions = {
    TargetGroup = module.alb_monitoring.target_groups["app"].arn_suffix
    LoadBalancer = module.alb_monitoring.load_balancer.arn_suffix
  }

  tags = {
    Environment = "production"
    Metric = "unhealthy_hosts"
  }
}

# CloudWatch Alarms - Errors
resource "aws_cloudwatch_metric_alarm" "elb_5xx_errors" {
  alarm_name = "alb-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods = "1"
  metric_name = "HTTPCode_ELB_5XX_Count"
  namespace = "AWS/ApplicationELB"
  period = "300"
  statistic = "Sum"
  threshold = "5"
  alarm_description = "ALB 5XX errors detected"
  alarm_actions = [aws_sns_topic.monitoring_alerts.arn]

  dimensions = {
    LoadBalancer = module.alb_monitoring.load_balancer.arn_suffix
  }

  tags = {
    Environment = "production"
    Metric = "elb_5xx_errors"
  }
}

resource "aws_cloudwatch_metric_alarm" "target_5xx_errors" {
  alarm_name = "alb-target-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods = "1"
  metric_name = "HTTPCode_Target_5XX_Count"
  namespace = "AWS/ApplicationELB"
  period = "300"
  statistic = "Sum"
  threshold = "5"
  alarm_description = "Target 5XX errors detected"
  alarm_actions = [aws_sns_topic.monitoring_alerts.arn]

  dimensions = {
    LoadBalancer = module.alb_monitoring.load_balancer.arn_suffix
  }

  tags = {
    Environment = "production"
    Metric = "target_5xx_errors"
  }
}

# CloudWatch Alarms - Security
resource "aws_cloudwatch_metric_alarm" "rejected_connections" {
  alarm_name = "alb-rejected-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods = "1"
  metric_name = "RejectedConnectionCount"
  namespace = "AWS/ApplicationELB"
  period = "300"
  statistic = "Sum"
  threshold = "10"
  alarm_description = "ALB rejected connections detected"
  alarm_actions = [aws_sns_topic.monitoring_alerts.arn]

  dimensions = {
    LoadBalancer = module.alb_monitoring.load_balancer.arn_suffix
  }

  tags = {
    Environment = "production"
    Metric = "rejected_connections"
  }
}

# SNS Topic for Monitoring Alerts
resource "aws_sns_topic" "monitoring_alerts" {
  name = "alb-monitoring-alerts"
  
  tags = {
    Environment = "production"
    Project = "monitoring-example"
    Purpose = "alerts"
  }
}

# SNS Topic Subscriptions
resource "aws_sns_topic_subscription" "email_alerts" {
  count = var.alert_email != null ? 1 : 0
  
  topic_arn = aws_sns_topic.monitoring_alerts.arn
  protocol = "email"
  endpoint = var.alert_email
}

resource "aws_sns_topic_subscription" "slack_alerts" {
  count = var.slack_webhook_url != null ? 1 : 0
  
  topic_arn = aws_sns_topic.monitoring_alerts.arn
  protocol = "https"
  endpoint = var.slack_webhook_url
}

# CloudWatch Log Group for Custom Metrics
resource "aws_cloudwatch_log_group" "alb_logs" {
  name = "/aws/alb/monitoring"
  retention_in_days = 30

  tags = {
    Environment = "production"
    Purpose = "monitoring"
  }
}

# Lambda Function for Custom Metrics
resource "aws_lambda_function" "custom_metrics" {
  filename = "custom_metrics.zip"
  function_name = "alb-custom-metrics"
  role = aws_iam_role.lambda_execution.arn
  handler = "index.handler"
  runtime = "python3.9"
  timeout = 60

  environment {
    variables = {
      LOG_GROUP_NAME = aws_cloudwatch_log_group.alb_logs.name
      ALB_ARN = module.alb_monitoring.load_balancer.arn
    }
  }

  tags = {
    Environment = "production"
    Project = "monitoring-example"
    Purpose = "custom-metrics"
  }
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_execution" {
  name = "alb-monitoring-lambda-execution"

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
  name = "alb-monitoring-lambda-policy"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
          "logs:FilterLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetHealth"
        ]
        Resource = "*"
      }
    ]
  })
}

# EventBridge Rule for Custom Metrics
resource "aws_cloudwatch_event_rule" "custom_metrics" {
  name = "alb-custom-metrics"
  description = "Trigger custom metrics collection for ALB"

  schedule_expression = "rate(5 minutes)"

  tags = {
    Environment = "production"
    Purpose = "monitoring"
  }
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule = aws_cloudwatch_event_rule.custom_metrics.name
  target_id = "ALBCustomMetrics"
  arn = aws_lambda_function.custom_metrics.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id = "AllowExecutionFromEventBridge"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.custom_metrics.function_name
  principal = "events.amazonaws.com"
  source_arn = aws_cloudwatch_event_rule.custom_metrics.arn
}

# WAF Web ACL for Security Monitoring
resource "aws_wafv2_web_acl" "alb_security" {
  name = "alb-security-waf"
  description = "WAF for ALB security monitoring"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name = "RateLimit"
    priority = 1

    override_action {
      none {}
    }

    statement {
      rate_based_statement {
        limit = 2000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name = "RateLimitRule"
      sampled_requests_enabled = true
    }
  }

  rule {
    name = "BlockedIPs"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name = "BlockedIPsRule"
      sampled_requests_enabled = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name = "ALBSecurityWAF"
    sampled_requests_enabled = true
  }

  tags = {
    Environment = "production"
    Purpose = "security"
  }
}

# WAF Association
resource "aws_wafv2_web_acl_association" "alb" {
  resource_arn = module.alb_monitoring.load_balancer.arn
  web_acl_arn = aws_wafv2_web_acl.alb_security.arn
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
  description = "Email address for monitoring alerts"
  type = string
  default = null
}

variable "slack_webhook_url" {
  description = "Slack webhook URL for monitoring alerts"
  type = string
  default = null
  sensitive = true
}

variable "monitoring_interval" {
  description = "Monitoring interval in minutes"
  type = number
  default = 5
  
  validation {
    condition = var.monitoring_interval >= 1 && var.monitoring_interval <= 60
    error_message = "Monitoring interval must be between 1 and 60 minutes."
  }
}

variable "retention_days" {
  description = "CloudWatch log retention in days"
  type = number
  default = 30
  
  validation {
    condition = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.retention_days)
    error_message = "Retention days must be a valid CloudWatch retention period."
  }
}

variable "enable_waf" {
  description = "Enable WAF for security monitoring"
  type = bool
  default = true
}

variable "enable_custom_metrics" {
  description = "Enable custom metrics collection"
  type = bool
  default = true
}

variable "enable_dashboard" {
  description = "Enable CloudWatch dashboard"
  type = bool
  default = true
}
```

### outputs.tf

```hcl
output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value = module.alb_monitoring.load_balancer.arn
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value = module.alb_monitoring.load_balancer.dns_name
}

output "dashboard_url" {
  description = "URL of the CloudWatch dashboard"
  value = "https://console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${aws_cloudwatch_dashboard.alb_monitoring.dashboard_name}"
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for monitoring alerts"
  value = aws_sns_topic.monitoring_alerts.arn
}

output "cloudwatch_alarms" {
  description = "Map of CloudWatch alarms"
  value = {
    response_time = aws_cloudwatch_metric_alarm.response_time.arn
    request_count = aws_cloudwatch_metric_alarm.request_count.arn
    healthy_hosts = aws_cloudwatch_metric_alarm.healthy_hosts.arn
    unhealthy_hosts = aws_cloudwatch_metric_alarm.unhealthy_hosts.arn
    elb_5xx_errors = aws_cloudwatch_metric_alarm.elb_5xx_errors.arn
    target_5xx_errors = aws_cloudwatch_metric_alarm.target_5xx_errors.arn
    rejected_connections = aws_cloudwatch_metric_alarm.rejected_connections.arn
  }
}

output "waf_web_acl_arn" {
  description = "ARN of the WAF Web ACL"
  value = aws_wafv2_web_acl.alb_security.arn
}

output "lambda_function_arn" {
  description = "ARN of the custom metrics Lambda function"
  value = aws_lambda_function.custom_metrics.arn
}
```

### cloudwatch_dashboard.json

```json
{
  "widgets": [
    {
      "type": "metric",
      "x": 0,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", "app/monitoring-alb/1234567890abcdef"],
          [".", "TargetResponseTime", ".", "."],
          [".", "HealthyHostCount", ".", "."]
        ],
        "view": "timeSeries",
        "stacked": false,
        "region": "us-east-1",
        "title": "ALB Performance Metrics",
        "period": 300
      }
    },
    {
      "type": "metric",
      "x": 12,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", "app/monitoring-alb/1234567890abcdef"],
          [".", "HTTPCode_Target_5XX_Count", ".", "."],
          [".", "RejectedConnectionCount", ".", "."]
        ],
        "view": "timeSeries",
        "stacked": false,
        "region": "us-east-1",
        "title": "ALB Error Metrics",
        "period": 300
      }
    },
    {
      "type": "log",
      "x": 0,
      "y": 6,
      "width": 24,
      "height": 6,
      "properties": {
        "query": "SOURCE '/aws/alb/monitoring'\n| fields @timestamp, @message\n| filter @message like /ERROR/\n| sort @timestamp desc\n| limit 20",
        "region": "us-east-1",
        "title": "ALB Error Logs",
        "view": "table"
      }
    }
  ]
}
```

### README.md

```markdown
# Enhanced Monitoring Example

This example demonstrates comprehensive monitoring and observability for the ALB module with advanced alerting, logging, and dashboard capabilities.

## Features

- **CloudWatch Dashboard**: Real-time monitoring dashboard
- **Comprehensive Alarms**: Performance, health, error, and security alarms
- **Custom Metrics**: Lambda function for custom metric collection
- **WAF Integration**: Security monitoring with AWS WAF
- **Multi-Channel Alerting**: Email and Slack notifications
- **Access Logging**: Detailed request logging
- **Log Analysis**: CloudWatch Logs integration

## Monitoring Components

### Performance Metrics
- Response time monitoring
- Request count tracking
- Throughput analysis

### Health Metrics
- Healthy host count
- Unhealthy host detection
- Target group health

### Error Metrics
- ELB 5XX errors
- Target 5XX errors
- Rejected connections

### Security Metrics
- WAF rule violations
- Rate limiting alerts
- Security threat detection

## Usage

1. **Deploy Infrastructure**:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

2. **Access Dashboard**:
   - Use the dashboard URL from outputs
   - Monitor real-time metrics

3. **Configure Alerts**:
   - Subscribe to SNS topic
   - Configure notification channels

## Best Practices

1. **Alarm Thresholds**: Set appropriate thresholds based on baseline
2. **Log Retention**: Configure appropriate log retention periods
3. **Security**: Enable WAF for production workloads
4. **Custom Metrics**: Extend with application-specific metrics
5. **Alert Fatigue**: Avoid too many alerts

## Cleanup

```bash
terraform destroy
```
```

## Key Features

This Enhanced Monitoring example includes:

1. **Comprehensive CloudWatch Alarms**: Performance, health, error, and security monitoring
2. **Real-time Dashboard**: CloudWatch dashboard with key metrics
3. **Custom Metrics Collection**: Lambda function for application-specific metrics
4. **WAF Integration**: Security monitoring and threat detection
5. **Multi-channel Alerting**: Email and Slack notifications
6. **Access Logging**: Detailed request logging and analysis
7. **Automated Monitoring**: EventBridge triggers for metric collection
8. **Production-Ready**: Comprehensive observability for production workloads

This example provides a complete monitoring solution that can be extended with custom metrics and integrated into existing monitoring systems. 