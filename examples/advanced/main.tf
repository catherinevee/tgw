# Advanced Transit Gateway Example
# This example creates a Transit Gateway with VPC attachments and custom route tables

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
  region = var.aws_region
}

# Create VPCs for demonstration
resource "aws_vpc" "vpc1" {
  cidr_block = "10.1.0.0/16"
  
  tags = {
    Name = "vpc-1"
    Environment = "development"
  }
}

resource "aws_vpc" "vpc2" {
  cidr_block = "10.2.0.0/16"
  
  tags = {
    Name = "vpc-2"
    Environment = "development"
  }
}

# Create subnets for VPC attachments
resource "aws_subnet" "vpc1_subnet1" {
  vpc_id     = aws_vpc.vpc1.id
  cidr_block = "10.1.1.0/24"
  availability_zone = "${var.aws_region}a"
  
  tags = {
    Name = "vpc1-subnet1"
  }
}

resource "aws_subnet" "vpc1_subnet2" {
  vpc_id     = aws_vpc.vpc1.id
  cidr_block = "10.1.2.0/24"
  availability_zone = "${var.aws_region}b"
  
  tags = {
    Name = "vpc1-subnet2"
  }
}

resource "aws_subnet" "vpc2_subnet1" {
  vpc_id     = aws_vpc.vpc2.id
  cidr_block = "10.2.1.0/24"
  availability_zone = "${var.aws_region}a"
  
  tags = {
    Name = "vpc2-subnet1"
  }
}

resource "aws_subnet" "vpc2_subnet2" {
  vpc_id     = aws_vpc.vpc2.id
  cidr_block = "10.2.2.0/24"
  availability_zone = "${var.aws_region}b"
  
  tags = {
    Name = "vpc2-subnet2"
  }
}

# Create an advanced Transit Gateway
module "transit_gateway" {
  source = "../../"

  tgw_name = "advanced-transit-gateway"
  description = "Advanced Transit Gateway with VPC attachments and route tables"
  
  # Enable route tables
  create_route_tables = true
  
  # Create custom route tables
  route_tables = [
    {
      name = "shared-routes"
      tags = {
        Purpose = "shared-services"
      }
    },
    {
      name = "isolated-routes"
      tags = {
        Purpose = "isolated-workloads"
      }
    }
  ]
  
  # Create VPC attachments
  vpc_attachments = [
    {
      name = "vpc1-attachment"
      vpc_id = aws_vpc.vpc1.id
      subnet_ids = [aws_subnet.vpc1_subnet1.id, aws_subnet.vpc1_subnet2.id]
      appliance_mode_support = "enable"
      dns_support = "enable"
      ipv6_support = "disable"
      transit_gateway_default_route_table_association = false
      transit_gateway_default_route_table_propagation = false
      tags = {
        VPC = "vpc-1"
        Purpose = "shared-services"
      }
    },
    {
      name = "vpc2-attachment"
      vpc_id = aws_vpc.vpc2.id
      subnet_ids = [aws_subnet.vpc2_subnet1.id, aws_subnet.vpc2_subnet2.id]
      appliance_mode_support = "enable"
      dns_support = "enable"
      ipv6_support = "disable"
      transit_gateway_default_route_table_association = false
      transit_gateway_default_route_table_propagation = false
      tags = {
        VPC = "vpc-2"
        Purpose = "isolated-workloads"
      }
    }
  ]
  
  # Create route table associations
  route_table_associations = [
    {
      transit_gateway_attachment_id = "vpc1-attachment"
      transit_gateway_route_table_id = "shared-routes"
    },
    {
      transit_gateway_attachment_id = "vpc2-attachment"
      transit_gateway_route_table_id = "isolated-routes"
    }
  ]
  
  # Create routes
  routes = [
    {
      destination_cidr_block = "10.1.0.0/16"
      transit_gateway_attachment_id = "vpc1-attachment"
      transit_gateway_route_table_id = "shared-routes"
    },
    {
      destination_cidr_block = "10.2.0.0/16"
      transit_gateway_attachment_id = "vpc2-attachment"
      transit_gateway_route_table_id = "isolated-routes"
    }
  ]
  
  # Tags
  tags = {
    Environment = "development"
    Project     = "transit-gateway-advanced-demo"
    Owner       = "terraform"
  }
} 