# Transit Gateway Outputs
output "transit_gateway_id" {
  description = "The ID of the Transit Gateway"
  value       = var.create_tgw ? aws_ec2_transit_gateway.main[0].id : null
}

output "transit_gateway_arn" {
  description = "The ARN of the Transit Gateway"
  value       = var.create_tgw ? aws_ec2_transit_gateway.main[0].arn : null
}

output "transit_gateway_owner_id" {
  description = "The ID of the AWS account that owns the Transit Gateway"
  value       = var.create_tgw ? aws_ec2_transit_gateway.main[0].owner_id : null
}

output "transit_gateway_amazon_side_asn" {
  description = "The private Autonomous System Number (ASN) for the Amazon side of a BGP session"
  value       = var.create_tgw ? aws_ec2_transit_gateway.main[0].amazon_side_asn : null
}

output "transit_gateway_association_default_route_table_id" {
  description = "The ID of the default association route table"
  value       = var.create_tgw ? aws_ec2_transit_gateway.main[0].association_default_route_table_id : null
}

output "transit_gateway_propagation_default_route_table_id" {
  description = "The ID of the default propagation route table"
  value       = var.create_tgw ? aws_ec2_transit_gateway.main[0].propagation_default_route_table_id : null
}

# Route Tables Outputs
output "transit_gateway_route_table_ids" {
  description = "List of Transit Gateway route table IDs"
  value       = var.create_tgw && var.create_route_tables ? aws_ec2_transit_gateway_route_table.main[*].id : []
}

output "transit_gateway_route_table_arns" {
  description = "List of Transit Gateway route table ARNs"
  value       = var.create_tgw && var.create_route_tables ? aws_ec2_transit_gateway_route_table.main[*].arn : []
}

# VPC Attachments Outputs
output "transit_gateway_vpc_attachment_ids" {
  description = "List of Transit Gateway VPC attachment IDs"
  value       = var.create_tgw ? aws_ec2_transit_gateway_vpc_attachment.main[*].id : []
}

output "transit_gateway_vpc_attachment_arns" {
  description = "List of Transit Gateway VPC attachment ARNs"
  value       = var.create_tgw ? aws_ec2_transit_gateway_vpc_attachment.main[*].arn : []
}

output "transit_gateway_vpc_attachment_vpc_owner_ids" {
  description = "List of VPC owner IDs for Transit Gateway VPC attachments"
  value       = var.create_tgw ? aws_ec2_transit_gateway_vpc_attachment.main[*].vpc_owner_id : []
}

# VPN Attachments Outputs
output "transit_gateway_vpn_attachment_ids" {
  description = "List of Transit Gateway VPN attachment IDs"
  value       = var.create_tgw ? aws_ec2_transit_gateway_vpn_attachment.main[*].id : []
}

output "transit_gateway_vpn_attachment_arns" {
  description = "List of Transit Gateway VPN attachment ARNs"
  value       = var.create_tgw ? aws_ec2_transit_gateway_vpn_attachment.main[*].arn : []
}

# Connect Attachments Outputs
output "transit_gateway_connect_attachment_ids" {
  description = "List of Transit Gateway Connect attachment IDs"
  value       = var.create_tgw ? aws_ec2_transit_gateway_connect.main[*].id : []
}

output "transit_gateway_connect_attachment_arns" {
  description = "List of Transit Gateway Connect attachment ARNs"
  value       = var.create_tgw ? aws_ec2_transit_gateway_connect.main[*].arn : []
}

# Peering Attachments Outputs
output "transit_gateway_peering_attachment_ids" {
  description = "List of Transit Gateway peering attachment IDs"
  value       = var.create_tgw ? aws_ec2_transit_gateway_peering_attachment.main[*].id : []
}

output "transit_gateway_peering_attachment_arns" {
  description = "List of Transit Gateway peering attachment ARNs"
  value       = var.create_tgw ? aws_ec2_transit_gateway_peering_attachment.main[*].arn : []
}

# Multicast Domain Outputs
output "transit_gateway_multicast_domain_id" {
  description = "The ID of the Transit Gateway multicast domain"
  value       = var.create_tgw && var.create_multicast_domain ? aws_ec2_transit_gateway_multicast_domain.main[0].id : null
}

output "transit_gateway_multicast_domain_arn" {
  description = "The ARN of the Transit Gateway multicast domain"
  value       = var.create_tgw && var.create_multicast_domain ? aws_ec2_transit_gateway_multicast_domain.main[0].arn : null
}

# Route Table Associations Outputs
output "transit_gateway_route_table_association_ids" {
  description = "List of Transit Gateway route table association IDs"
  value       = var.create_tgw ? aws_ec2_transit_gateway_route_table_association.main[*].id : []
}

# Route Table Propagations Outputs
output "transit_gateway_route_table_propagation_ids" {
  description = "List of Transit Gateway route table propagation IDs"
  value       = var.create_tgw ? aws_ec2_transit_gateway_route_table_propagation.main[*].id : []
}

# Multicast Domain Associations Outputs
output "transit_gateway_multicast_domain_association_ids" {
  description = "List of Transit Gateway multicast domain association IDs"
  value       = var.create_tgw && var.create_multicast_domain ? aws_ec2_transit_gateway_multicast_domain_association.main[*].id : []
}

# Multicast Group Members Outputs
output "transit_gateway_multicast_group_member_ids" {
  description = "List of Transit Gateway multicast group member IDs"
  value       = var.create_tgw && var.create_multicast_domain ? aws_ec2_transit_gateway_multicast_group_member.main[*].id : []
}

# Multicast Group Sources Outputs
output "transit_gateway_multicast_group_source_ids" {
  description = "List of Transit Gateway multicast group source IDs"
  value       = var.create_tgw && var.create_multicast_domain ? aws_ec2_transit_gateway_multicast_group_source.main[*].id : []
}

# All Attachment IDs Combined
output "all_transit_gateway_attachment_ids" {
  description = "List of all Transit Gateway attachment IDs (VPC, VPN, Connect, Peering)"
  value = var.create_tgw ? concat(
    aws_ec2_transit_gateway_vpc_attachment.main[*].id,
    aws_ec2_transit_gateway_vpn_attachment.main[*].id,
    aws_ec2_transit_gateway_connect.main[*].id,
    aws_ec2_transit_gateway_peering_attachment.main[*].id
  ) : []
}

# All Attachment ARNs Combined
output "all_transit_gateway_attachment_arns" {
  description = "List of all Transit Gateway attachment ARNs (VPC, VPN, Connect, Peering)"
  value = var.create_tgw ? concat(
    aws_ec2_transit_gateway_vpc_attachment.main[*].arn,
    aws_ec2_transit_gateway_vpn_attachment.main[*].arn,
    aws_ec2_transit_gateway_connect.main[*].arn,
    aws_ec2_transit_gateway_peering_attachment.main[*].arn
  ) : []
} 