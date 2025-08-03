output "transit_gateway_id" {
  description = "The ID of the test Transit Gateway"
  value       = module.transit_gateway.transit_gateway_id
}

output "transit_gateway_arn" {
  description = "The ARN of the test Transit Gateway"
  value       = module.transit_gateway.transit_gateway_arn
}

output "transit_gateway_owner_id" {
  description = "The ID of the AWS account that owns the Transit Gateway"
  value       = module.transit_gateway.transit_gateway_owner_id
}

output "vpc_attachment_ids" {
  description = "Map of VPC attachment IDs"
  value       = module.transit_gateway.vpc_attachment_ids
}

output "vpc_attachment_arns" {
  description = "Map of VPC attachment ARNs"
  value       = module.transit_gateway.vpc_attachment_arns
}

output "route_table_ids" {
  description = "Map of route table IDs"
  value       = module.transit_gateway.route_table_ids
}

output "route_table_arns" {
  description = "Map of route table ARNs"
  value       = module.transit_gateway.route_table_arns
}

output "route_table_association_ids" {
  description = "Map of route table association IDs"
  value       = module.transit_gateway.route_table_association_ids
}

output "route_count" {
  description = "The number of routes in the Transit Gateway route tables"
  value       = module.transit_gateway.route_count
}

output "vpc_attachment_count" {
  description = "The number of VPC attachments"
  value       = module.transit_gateway.vpc_attachment_count
}

output "route_table_count" {
  description = "The number of custom route tables"
  value       = module.transit_gateway.route_table_count
}

output "test_vpc_id" {
  description = "The ID of the test VPC"
  value       = aws_vpc.test_vpc.id
}

output "test_subnet_ids" {
  description = "The IDs of the test subnets"
  value       = [aws_subnet.test_subnet_1.id, aws_subnet.test_subnet_2.id]
} 