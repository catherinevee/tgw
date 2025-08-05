# Terraform AWS Transit Gateway Module

Terraform module for deploying AWS Transit Gateway with enterprise networking patterns and security controls.

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.13.0 |
| aws | >= 6.2.0 |

## Features

- Transit Gateway deployment with customizable ASN and routing
- VPC attachments with subnet placement and DNS support
- Route table management for traffic segmentation
- Peering connections between Transit Gateways
- Security controls with VPC Flow Logs and network policies
- Resource tagging for cost allocation and compliance

## Resource Architecture

### Core Resources
- `aws_ec2_transit_gateway` - Main Transit Gateway instance
- `aws_ec2_transit_gateway_route_table` - Default and custom route tables
- `aws_ec2_transit_gateway_vpc_attachment` - VPC connectivity

### Routing and Traffic Control
- `aws_ec2_transit_gateway_route` - Inter-VPC routing rules
- `aws_ec2_transit_gateway_route_table_association` - Route table assignments
- `aws_ec2_transit_gateway_route_table_propagation` - Route propagation between tables

### Peering and External Connectivity
- `aws_ec2_transit_gateway_peering_attachment` - Cross-account or cross-region peering
- `aws_ec2_transit_gateway_route` - Peering route configuration

## Usage

### Basic Transit Gateway

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

### Multi-VPC with Traffic Segmentation

```hcl
module "transit_gateway" {
  source = "git::https://github.com/your-org/terraform-aws-tgw.git?ref=v1.0.0"

  name = "production-transit-gateway"
  
  # Transit Gateway settings
  description = "Production Transit Gateway for multi-VPC connectivity"
  amazon_side_asn = 64512
  
  # VPC attachments
  vpc_attachments = {
    app_vpc = {
      vpc_id = module.app_vpc.vpc_id
      subnet_ids = module.app_vpc.private_subnet_ids
      dns_support = "enable"
      appliance_mode_support = "enable"
    }
    data_vpc = {
      vpc_id = module.data_vpc.vpc_id
      subnet_ids = module.data_vpc.private_subnet_ids
      dns_support = "enable"
    }
  }
  
  # Custom route tables for traffic isolation
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
  
  # Route table associations
  route_table_associations = {
    app_vpc = "app_routes"
    data_vpc = "data_routes"
  }
  
  # Security and monitoring
  enable_flow_logs = true
  flow_log_retention_in_days = 30
  
  tags = {
    Environment = "production"
    Project     = "multi-vpc-connectivity"
    Owner       = "platform-team"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| name | Transit Gateway name | `string` | n/a | yes |
| description | Transit Gateway description | `string` | `null` | no |
| amazon_side_asn | Private ASN for BGP sessions | `number` | `64512` | no |
| auto_accept_shared_attachments | Auto-accept shared attachments | `string` | `"disable"` | no |
| default_route_table_association | Auto-associate with default route table | `string` | `"enable"` | no |
| default_route_table_propagation | Auto-propagate to default route table | `string` | `"enable"` | no |
| dns_support | Enable DNS support | `string` | `"enable"` | no |
| vpn_ecmp_support | Enable VPN ECMP support | `string` | `"enable"` | no |
| multicast_support | Enable multicast support | `string` | `"disable"` | no |
| vpc_attachments | VPC attachment configurations | `map(object)` | `{}` | no |
| route_tables | Custom route table configurations | `map(object)` | `{}` | no |
| route_table_associations | Route table association mappings | `map(string)` | `{}` | no |
| routes | Route configurations | `map(object)` | `{}` | no |
| peering_attachments | Peering attachment configurations | `map(object)` | `{}` | no |
| tags | Resource tags | `map(string)` | `{}` | no |
| enable_flow_logs | Enable VPC Flow Logs | `bool` | `false` | no |
| flow_log_retention_in_days | Flow log retention period | `number` | `30` | no |

## Outputs

| Name | Description |
|------|-------------|
| transit_gateway_id | Transit Gateway ID |
| transit_gateway_arn | Transit Gateway ARN |
| transit_gateway_owner_id | Transit Gateway owner account ID |
| transit_gateway_association_default_route_table_id | Default association route table ID |
| transit_gateway_propagation_default_route_table_id | Default propagation route table ID |
| transit_gateway_amazon_side_asn | Amazon side ASN |
| vpc_attachment_ids | VPC attachment IDs |
| vpc_attachment_arns | VPC attachment ARNs |
| route_table_ids | Route table IDs |
| route_table_arns | Route table ARNs |
| peering_attachment_ids | Peering attachment IDs |
| peering_attachment_arns | Peering attachment ARNs |
| all_transit_gateway_attachment_ids | All attachment IDs |
| all_transit_gateway_attachment_arns | All attachment ARNs |
| transit_gateway_tags | Transit Gateway tags |
| route_count | Number of routes |
| vpc_attachment_count | Number of VPC attachments |
| route_table_count | Number of custom route tables |
| peering_attachment_count | Number of peering attachments |

## Examples

- [Basic Usage](examples/basic/) - Simple Transit Gateway deployment
- [Advanced Usage](examples/advanced/) - Multi-VPC setup with custom routing

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.