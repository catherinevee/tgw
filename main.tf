# Data Sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Local Values
locals {
  # Common tags for all resources
  common_tags = merge(var.tags, {
    Module    = "terraform-aws-tgw"
    ManagedBy = "terraform"
  })

  # Transit Gateway tags
  transit_gateway_tags = merge(local.common_tags, {
    Name = var.name
  })
}

# Transit Gateway
resource "aws_ec2_transit_gateway" "main" {
  description = var.description

  amazon_side_asn                 = var.amazon_side_asn
  auto_accept_shared_attachments  = var.auto_accept_shared_attachments
  default_route_table_association = var.default_route_table_association
  default_route_table_propagation = var.default_route_table_propagation
  dns_support                     = var.dns_support
  vpn_ecmp_support                = var.vpn_ecmp_support
  multicast_support               = var.multicast_support

  tags = local.transit_gateway_tags

  lifecycle {
    prevent_destroy = true
  }
}

# VPC Attachments
resource "aws_ec2_transit_gateway_vpc_attachment" "vpc_attachments" {
  for_each = var.vpc_attachments

  transit_gateway_id = aws_ec2_transit_gateway.main.id
  vpc_id             = each.value.vpc_id
  subnet_ids         = each.value.subnet_ids

  dns_support                = each.value.dns_support
  ipv6_support               = each.value.ipv6_support
  appliance_mode_support     = each.value.appliance_mode_support

  transit_gateway_default_route_table_association = each.value.transit_gateway_default_route_table_association
  transit_gateway_default_route_table_propagation  = each.value.transit_gateway_default_route_table_propagation

  tags = merge(local.common_tags, {
    Name = "${var.name}-vpc-attachment-${each.key}"
  }, each.value.tags)

  depends_on = [aws_ec2_transit_gateway.main]
}

# Custom Route Tables
resource "aws_ec2_transit_gateway_route_table" "custom_route_tables" {
  for_each = var.route_tables

  transit_gateway_id = aws_ec2_transit_gateway.main.id

  tags = merge(local.common_tags, {
    Name = each.value.name
  }, each.value.tags)

  depends_on = [aws_ec2_transit_gateway.main]
}

# Route Table Associations
resource "aws_ec2_transit_gateway_route_table_association" "custom_associations" {
  for_each = var.route_table_associations

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.vpc_attachments[each.key].id
  transit_gateway_route_table_id = each.value == "main" ? aws_ec2_transit_gateway.main.association_default_route_table_id : aws_ec2_transit_gateway_route_table.custom_route_tables[each.value].id

  depends_on = [
    aws_ec2_transit_gateway_vpc_attachment.vpc_attachments,
    aws_ec2_transit_gateway_route_table.custom_route_tables
  ]
}

# Route Table Propagations
resource "aws_ec2_transit_gateway_route_table_propagation" "route_propagations" {
  for_each = {
    for k, v in var.vpc_attachments : k => v
    if contains(keys(var.route_table_associations), k)
  }

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.vpc_attachments[each.key].id
  transit_gateway_route_table_id = var.route_table_associations[each.key] == "main" ? aws_ec2_transit_gateway.main.propagation_default_route_table_id : aws_ec2_transit_gateway_route_table.custom_route_tables[var.route_table_associations[each.key]].id

  depends_on = [
    aws_ec2_transit_gateway_vpc_attachment.vpc_attachments,
    aws_ec2_transit_gateway_route_table.custom_route_tables
  ]
}

# VPC Routes
resource "aws_ec2_transit_gateway_route" "vpc_routes" {
  for_each = {
    for k, v in var.routes : k => v
    if can(regex("^vpc_", k))
  }

  destination_cidr_block         = each.value.destination_cidr_block
  transit_gateway_attachment_id  = each.value.transit_gateway_attachment_id
  transit_gateway_route_table_id = each.value.transit_gateway_route_table_id

  depends_on = [
    aws_ec2_transit_gateway_vpc_attachment.vpc_attachments,
    aws_ec2_transit_gateway_route_table.custom_route_tables
  ]
}

# Peering Attachments
resource "aws_ec2_transit_gateway_peering_attachment" "peering" {
  for_each = var.peering_attachments

  peer_region             = each.value.peer_region
  peer_transit_gateway_id = each.value.peer_transit_gateway_id
  transit_gateway_id      = aws_ec2_transit_gateway.main.id

  peer_account_id = each.value.peer_account_id

  tags = merge(local.common_tags, {
    Name = "${var.name}-peering-${each.key}"
  }, each.value.tags)

  depends_on = [aws_ec2_transit_gateway.main]
}

# Peering Routes
resource "aws_ec2_transit_gateway_route" "peering_routes" {
  for_each = {
    for k, v in var.routes : k => v
    if can(regex("^peering_", k))
  }

  destination_cidr_block         = each.value.destination_cidr_block
  transit_gateway_attachment_id  = each.value.transit_gateway_attachment_id
  transit_gateway_route_table_id = each.value.transit_gateway_route_table_id

  depends_on = [
    aws_ec2_transit_gateway_peering_attachment.peering,
    aws_ec2_transit_gateway_route_table.custom_route_tables
  ]
}

# VPC Flow Logs (Optional)
resource "aws_flow_log" "transit_gateway_flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  log_destination_type = "cloud-watch-logs"
  log_group_name       = "/aws/transit-gateway/${var.name}"
  traffic_type         = "ALL"

  tags = merge(local.common_tags, {
    Name = "${var.name}-flow-logs"
  })

  depends_on = [aws_ec2_transit_gateway.main]
}

# CloudWatch Log Group for Flow Logs
resource "aws_cloudwatch_log_group" "transit_gateway_flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name              = "/aws/transit-gateway/${var.name}"
  retention_in_days = var.flow_log_retention_in_days

  tags = merge(local.common_tags, {
    Name = "${var.name}-flow-logs"
  })
}

# IAM Role for Flow Logs
resource "aws_iam_role" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name = "${var.name}-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

# IAM Policy for Flow Logs
resource "aws_iam_role_policy" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name = "${var.name}-flow-logs-policy"
  role = aws_iam_role.flow_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })
} 