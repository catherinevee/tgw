# Terraform AWS Transit Gateway Module

A comprehensive Terraform module for deploying AWS Transit Gateway with best practices and security configurations.

## Features

- **Transit Gateway**: Deploy Transit Gateway with customizable settings
- **Route Tables**: Create and manage Transit Gateway route tables
- **VPC Attachments**: Attach VPCs to Transit Gateway
- **Peering Connections**: Establish Transit Gateway peering
- **Route Associations**: Manage route table associations
- **Security**: Implement least-privilege access controls
- **Tagging**: Comprehensive resource tagging support

## Resource Map

### Core Transit Gateway Resources

| Resource Type | Resource Name | Purpose | Dependencies |
|---------------|---------------|---------|--------------|
| `aws_ec2_transit_gateway` | `main` | Primary Transit Gateway instance | None |
| `aws_ec2_transit_gateway_route_table` | `main` | Default route table for Transit Gateway | `aws_ec2_transit_gateway.main` |
| `aws_ec2_transit_gateway_route_table_association` | `main` | Associates VPC attachments with route table | `aws_ec2_transit_gateway_route_table.main`, `aws_ec2_transit_gateway_vpc_attachment.*` |

### VPC Attachments

| Resource Type | Resource Name | Purpose | Dependencies |
|---------------|---------------|---------|--------------|
| `aws_ec2_transit_gateway_vpc_attachment` | `vpc_attachments` | Attaches VPCs to Transit Gateway | `aws_ec2_transit_gateway.main`, `aws_subnet.*` |
| `aws_ec2_transit_gateway_route` | `vpc_routes` | Routes traffic between VPCs | `aws_ec2_transit_gateway_route_table.main`, `aws_ec2_transit_gateway_vpc_attachment.*` |

### Peering Connections

| Resource Type | Resource Name | Purpose | Dependencies |
|---------------|---------------|---------|--------------|
| `aws_ec2_transit_gateway_peering_attachment` | `peering` | Establishes peering with other Transit Gateways | `aws_ec2_transit_gateway.main` |
| `aws_ec2_transit_gateway_route` | `peering_routes` | Routes traffic through peering connections | `aws_ec2_transit_gateway_route_table.main`, `aws_ec2_transit_gateway_peering_attachment.peering` |

### Route Tables and Associations

| Resource Type | Resource Name | Purpose | Dependencies |
|---------------|---------------|---------|--------------|
| `aws_ec2_transit_gateway_route_table` | `custom_route_tables` | Custom route tables for traffic segmentation | `aws_ec2_transit_gateway.main` |
| `aws_ec2_transit_gateway_route_table_association` | `custom_associations` | Associates attachments with custom route tables | `aws_ec2_transit_gateway_route_table.custom_route_tables`, `aws_ec2_transit_gateway_vpc_attachment.*` |
| `aws_ec2_transit_gateway_route_table_propagation` | `route_propagations` | Propagates routes between route tables | `aws_ec2_transit_gateway_route_table.*` |

### Data Sources

| Resource Type | Resource Name | Purpose | Dependencies |
|---------------|---------------|---------|--------------|
| `data.aws_caller_identity` | `current` | Gets current AWS account information | None |
| `data.aws_region` | `current` | Gets current AWS region | None |
| `data.aws_vpc` | `vpc_data` | Retrieves VPC information for attachments | None |
| `data.aws_subnets` | `subnet_data` | Retrieves subnet information for attachments | None |

### IAM and Security

| Resource Type | Resource Name | Purpose | Dependencies |
|---------------|---------------|---------|--------------|
| `aws_iam_role` | `transit_gateway_role` | IAM role for Transit Gateway operations | None |
| `aws_iam_policy` | `transit_gateway_policy` | IAM policy for Transit Gateway permissions | None |
| `aws_iam_role_policy_attachment` | `transit_gateway_policy_attachment` | Attaches policy to Transit Gateway role | `aws_iam_role.transit_gateway_role`, `aws_iam_policy.transit_gateway_policy` |

## Usage

### Basic Usage

```hcl
module "transit_gateway" {
  source = "git::https://github.com/your-org/terraform-aws-tgw.git?ref=v1.0.0"

  name = "my-transit-gateway"
  
  vpc_attachments = {
    vpc1 = {
      vpc_id = "vpc-12345678"
      subnet_ids = ["subnet-12345678", "subnet-87654321"]
    }
  }
}
```

### Advanced Usage

```hcl
module "transit_gateway" {
  source = "git::https://github.com/your-org/terraform-aws-tgw.git?ref=v1.0.0"

  name = "production-transit-gateway"
  
  # Transit Gateway Configuration
  description = "Production Transit Gateway for multi-VPC connectivity"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"
  
  # VPC Attachments
  vpc_attachments = {
    app_vpc = {
      vpc_id = module.app_vpc.vpc_id
      subnet_ids = module.app_vpc.private_subnet_ids
      dns_support = "enable"
      ipv6_support = "disable"
      appliance_mode_support = "enable"
    }
    data_vpc = {
      vpc_id = module.data_vpc.vpc_id
      subnet_ids = module.data_vpc.private_subnet_ids
      dns_support = "enable"
      ipv6_support = "disable"
    }
  }
  
  # Custom Route Tables
  route_tables = {
    app_routes = {
      name = "app-route-table"
      description = "Route table for application VPCs"
    }
    data_routes = {
      name = "data-route-table"
      description = "Route table for data VPCs"
    }
  }
  
  # Route Associations
  route_table_associations = {
    app_vpc = "app_routes"
    data_vpc = "data_routes"
  }
  
  # Tags
  tags = {
    Environment = "production"
    Project     = "multi-vpc-connectivity"
    Owner       = "platform-team"
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.13.0 |
| aws | >= 6.2.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 6.2.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| name | Name of the Transit Gateway | `string` | n/a | yes |
| description | Description of the Transit Gateway | `string` | `null` | no |
| amazon_side_asn | Private Autonomous System Number (ASN) for the Amazon side of a BGP session | `number` | `64512` | no |
| auto_accept_shared_attachments | Whether resource attachments are automatically accepted | `string` | `"disable"` | no |
| default_route_table_association | Whether resource attachments are automatically associated with the default association route table | `string` | `"enable"` | no |
| default_route_table_propagation | Whether resource attachments automatically propagate routes to the default propagation route table | `string` | `"enable"` | no |
| dns_support | Whether DNS support is enabled | `string` | `"enable"` | no |
| vpn_ecmp_support | Whether VPN Equal Cost Multipath Protocol support is enabled | `string` | `"enable"` | no |
| multicast_support | Whether multicast support is enabled | `string` | `"disable"` | no |
| vpc_attachments | Map of VPC attachments to create | `map(object)` | `{}` | no |
| route_tables | Map of custom route tables to create | `map(object)` | `{}` | no |
| route_table_associations | Map of route table associations | `map(string)` | `{}` | no |
| tags | A map of tags to assign to the Transit Gateway | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| transit_gateway_id | The ID of the Transit Gateway |
| transit_gateway_arn | The ARN of the Transit Gateway |
| transit_gateway_owner_id | The ID of the AWS account that owns the Transit Gateway |
| transit_gateway_association_default_route_table_id | The ID of the default association route table |
| transit_gateway_propagation_default_route_table_id | The ID of the default propagation route table |
| vpc_attachment_ids | Map of VPC attachment IDs |
| route_table_ids | Map of route table IDs |
| route_table_association_ids | Map of route table association IDs |

## Examples

- [Basic Usage](examples/basic/) - Simple Transit Gateway deployment
- [Advanced Usage](examples/advanced/) - Complex multi-VPC setup with custom route tables

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for a list of changes and version history.