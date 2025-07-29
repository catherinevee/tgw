output "transit_gateway_id" {
  description = "The ID of the test Transit Gateway"
  value       = module.transit_gateway_test.transit_gateway_id
}

output "transit_gateway_arn" {
  description = "The ARN of the test Transit Gateway"
  value       = module.transit_gateway_test.transit_gateway_arn
}

output "transit_gateway_owner_id" {
  description = "The ID of the AWS account that owns the test Transit Gateway"
  value       = module.transit_gateway_test.transit_gateway_owner_id
} 