output "transit_gateway_id" {
  description = "The ID of the created Transit Gateway"
  value       = module.transit_gateway.transit_gateway_id
}

output "transit_gateway_arn" {
  description = "The ARN of the created Transit Gateway"
  value       = module.transit_gateway.transit_gateway_arn
}

output "vpc_attachment_ids" {
  description = "List of VPC attachment IDs"
  value       = module.transit_gateway.transit_gateway_vpc_attachment_ids
}

output "route_table_ids" {
  description = "List of Transit Gateway route table IDs"
  value       = module.transit_gateway.transit_gateway_route_table_ids
}

output "vpc_ids" {
  description = "List of VPC IDs"
  value       = [aws_vpc.vpc1.id, aws_vpc.vpc2.id]
} 