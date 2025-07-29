# Test configuration for Transit Gateway module

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Test the Transit Gateway module
module "transit_gateway_test" {
  source = "../"

  tgw_name = "test-transit-gateway"
  description = "Test Transit Gateway"
  
  # Basic configuration for testing
  amazon_side_asn = 64512
  dns_support = "enable"
  vpn_ecmp_support = "enable"
  
  tags = {
    Environment = "test"
    Project     = "transit-gateway-test"
  }
}

# Outputs for testing
output "transit_gateway_id" {
  description = "The ID of the test Transit Gateway"
  value       = module.transit_gateway_test.transit_gateway_id
}

output "transit_gateway_arn" {
  description = "The ARN of the test Transit Gateway"
  value       = module.transit_gateway_test.transit_gateway_arn
} 