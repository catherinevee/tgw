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
  region = "us-west-2"
}

# Test VPC for Transit Gateway attachments
resource "aws_vpc" "test_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "test-vpc"
  }
}

resource "aws_subnet" "test_subnet_1" {
  vpc_id            = aws_vpc.test_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-west-2a"

  tags = {
    Name = "test-subnet-1"
  }
}

resource "aws_subnet" "test_subnet_2" {
  vpc_id            = aws_vpc.test_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-west-2b"

  tags = {
    Name = "test-subnet-2"
  }
}

# Test Transit Gateway module
module "transit_gateway" {
  source = "../"

  name = "test-transit-gateway"
  
  description = "Test Transit Gateway for validation"
  
  vpc_attachments = {
    test_vpc = {
      vpc_id     = aws_vpc.test_vpc.id
      subnet_ids = [aws_subnet.test_subnet_1.id, aws_subnet.test_subnet_2.id]
    }
  }
  
  route_tables = {
    test_routes = {
      name = "test-route-table"
    }
  }
  
  route_table_associations = {
    test_vpc = "test_routes"
  }
  
  tags = {
    Environment = "test"
    Project     = "transit-gateway-test"
  }
}

# Outputs for testing
output "transit_gateway_id" {
  description = "The ID of the test Transit Gateway"
  value       = module.transit_gateway.transit_gateway_id
}

output "transit_gateway_arn" {
  description = "The ARN of the test Transit Gateway"
  value       = module.transit_gateway.transit_gateway_arn
} 