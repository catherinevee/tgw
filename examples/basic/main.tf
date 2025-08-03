# Basic Transit Gateway Example
# This example creates a simple Transit Gateway with basic configuration

terraform {
  required_version = ">= 1.13.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Create a basic Transit Gateway
module "transit_gateway" {
  source = "../../"

  name = "basic-transit-gateway"
  description = "Basic Transit Gateway for demonstration"
  
  # Basic configuration
  amazon_side_asn = 64512
  dns_support = "enable"
  vpn_ecmp_support = "enable"
  
  # Tags
  tags = {
    Environment = "development"
    Project     = "transit-gateway-demo"
    Owner       = "terraform"
  }
}

# Output the Transit Gateway ID
output "transit_gateway_id" {
  description = "The ID of the created Transit Gateway"
  value       = module.transit_gateway.transit_gateway_id
}

output "transit_gateway_arn" {
  description = "The ARN of the created Transit Gateway"
  value       = module.transit_gateway.transit_gateway_arn
} 