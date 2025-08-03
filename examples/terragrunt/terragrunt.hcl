# Terragrunt configuration for Transit Gateway module
# Compatible with Terragrunt version 0.84.0

include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../"
}

inputs = {
  name = "terragrunt-transit-gateway"
  description = "Transit Gateway deployed via Terragrunt"
  
  # Transit Gateway Configuration
  amazon_side_asn = 64512
  auto_accept_shared_attachments = "disable"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"
  dns_support = "enable"
  vpn_ecmp_support = "enable"
  multicast_support = "disable"
  
  # VPC Attachments (example - adjust as needed)
  vpc_attachments = {
    example_vpc = {
      vpc_id = "vpc-example123"
      subnet_ids = ["subnet-example1", "subnet-example2"]
      dns_support = "enable"
      ipv6_support = "disable"
      appliance_mode_support = "disable"
      transit_gateway_default_route_table_association = true
      transit_gateway_default_route_table_propagation = true
      tags = {
        Environment = "development"
        ManagedBy = "terragrunt"
      }
    }
  }
  
  # Tags
  tags = {
    Environment = "development"
    Project = "transit-gateway-terragrunt"
    ManagedBy = "terragrunt"
    Owner = "infrastructure-team"
  }
} 