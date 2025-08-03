output "transit_gateway_id" {
  description = "The ID of the Transit Gateway."
  value       = aws_ec2_transit_gateway.main.id
}

output "transit_gateway_arn" {
  description = "The ARN of the Transit Gateway."
  value       = aws_ec2_transit_gateway.main.arn
}

output "transit_gateway_owner_id" {
  description = "The ID of the AWS account that owns the Transit Gateway."
  value       = aws_ec2_transit_gateway.main.owner_id
}

output "transit_gateway_association_default_route_table_id" {
  description = "The ID of the default association route table."
  value       = aws_ec2_transit_gateway.main.association_default_route_table_id
}

output "transit_gateway_propagation_default_route_table_id" {
  description = "The ID of the default propagation route table."
  value       = aws_ec2_transit_gateway.main.propagation_default_route_table_id
}

output "transit_gateway_amazon_side_asn" {
  description = "The private ASN for the Amazon side of BGP sessions."
  value       = aws_ec2_transit_gateway.main.amazon_side_asn
}

output "vpc_attachment_ids" {
  description = "Map of VPC attachment IDs."
  value       = { for k, v in aws_ec2_transit_gateway_vpc_attachment.vpc_attachments : k => v.id }
}

output "vpc_attachment_arns" {
  description = "Map of VPC attachment ARNs."
  value       = { for k, v in aws_ec2_transit_gateway_vpc_attachment.vpc_attachments : k => v.arn }
}

output "vpc_attachment_vpc_owner_ids" {
  description = "Map of VPC owner IDs for Transit Gateway VPC attachments."
  value       = { for k, v in aws_ec2_transit_gateway_vpc_attachment.vpc_attachments : k => v.vpc_owner_id }
}

output "route_table_ids" {
  description = "Map of route table IDs."
  value       = { for k, v in aws_ec2_transit_gateway_route_table.custom_route_tables : k => v.id }
}

output "route_table_arns" {
  description = "Map of route table ARNs."
  value       = { for k, v in aws_ec2_transit_gateway_route_table.custom_route_tables : k => v.arn }
}

output "route_table_association_ids" {
  description = "Map of route table association IDs."
  value       = { for k, v in aws_ec2_transit_gateway_route_table_association.custom_associations : k => v.id }
}

output "route_table_propagation_ids" {
  description = "Map of route table propagation IDs."
  value       = { for k, v in aws_ec2_transit_gateway_route_table_propagation.route_propagations : k => v.id }
}

output "peering_attachment_ids" {
  description = "Map of Transit Gateway peering attachment IDs."
  value       = { for k, v in aws_ec2_transit_gateway_peering_attachment.peering : k => v.id }
}

output "peering_attachment_arns" {
  description = "Map of Transit Gateway peering attachment ARNs."
  value       = { for k, v in aws_ec2_transit_gateway_peering_attachment.peering : k => v.arn }
}

output "all_transit_gateway_attachment_ids" {
  description = "Map of all Transit Gateway attachment IDs (VPC, Peering)."
  value = merge(
    { for k, v in aws_ec2_transit_gateway_vpc_attachment.vpc_attachments : "vpc_${k}" => v.id },
    { for k, v in aws_ec2_transit_gateway_peering_attachment.peering : "peering_${k}" => v.id }
  )
}

output "all_transit_gateway_attachment_arns" {
  description = "Map of all Transit Gateway attachment ARNs (VPC, Peering)."
  value = merge(
    { for k, v in aws_ec2_transit_gateway_vpc_attachment.vpc_attachments : "vpc_${k}" => v.arn },
    { for k, v in aws_ec2_transit_gateway_peering_attachment.peering : "peering_${k}" => v.arn }
  )
}

output "transit_gateway_tags" {
  description = "A map of tags assigned to the Transit Gateway."
  value       = aws_ec2_transit_gateway.main.tags
}

output "route_count" {
  description = "The number of routes in the Transit Gateway route tables."
  value       = length(aws_ec2_transit_gateway_route.vpc_routes) + length(aws_ec2_transit_gateway_route.peering_routes)
}

output "vpc_attachment_count" {
  description = "The number of VPC attachments."
  value       = length(aws_ec2_transit_gateway_vpc_attachment.vpc_attachments)
}

output "route_table_count" {
  description = "The number of custom route tables."
  value       = length(aws_ec2_transit_gateway_route_table.custom_route_tables)
}

output "peering_attachment_count" {
  description = "The number of peering attachments."
  value       = length(aws_ec2_transit_gateway_peering_attachment.peering)
} 