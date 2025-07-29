# AWS Transit Gateway Terraform Module

A comprehensive Terraform module for creating and managing AWS Transit Gateway resources with support for VPC attachments, VPN connections, peering, and multicast domains.

## Features

- **Transit Gateway**: Create and configure Transit Gateway with customizable settings
- **Route Tables**: Create custom Transit Gateway route tables
- **VPC Attachments**: Attach multiple VPCs to the Transit Gateway
- **VPN Attachments**: Attach VPN connections to the Transit Gateway
- **Connect Attachments**: Create Transit Gateway Connect attachments
- **Peering Attachments**: Set up Transit Gateway peering between regions
- **Multicast Support**: Enable and configure multicast domains
- **Route Management**: Configure routes, associations, and propagations
- **Comprehensive Outputs**: All resource IDs and ARNs for integration

## Usage

### Basic Transit Gateway

```hcl
module "transit_gateway" {
  source = "./tgw"

  tgw_name = "my-transit-gateway"
  description = "Transit Gateway for multi-VPC connectivity"
  
  tags = {
    Environment = "production"
    Project     = "network-hub"
  }
}
```

### Transit Gateway with VPC Attachments

```hcl
module "transit_gateway" {
  source = "./tgw"

  tgw_name = "hub-transit-gateway"
  
  vpc_attachments = [
    {
      name = "vpc-attachment-1"
      vpc_id = "vpc-12345678"
      subnet_ids = ["subnet-12345678", "subnet-87654321"]
      appliance_mode_support = "enable"
      dns_support = "enable"
      ipv6_support = "disable"
      transit_gateway_default_route_table_association = true
      transit_gateway_default_route_table_propagation = true
      tags = {
        VPC = "production-vpc"
      }
    }
  ]
  
  tags = {
    Environment = "production"
  }
}
```

### Transit Gateway with Custom Route Tables

```hcl
module "transit_gateway" {
  source = "./tgw"

  tgw_name = "advanced-transit-gateway"
  create_route_tables = true
  
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
  
  routes = [
    {
      destination_cidr_block = "10.0.0.0/16"
      transit_gateway_attachment_id = "tgw-attach-12345678"
      transit_gateway_route_table_id = "tgw-rtb-12345678"
    }
  ]
  
  tags = {
    Environment = "production"
  }
}
```

### Transit Gateway with Peering

```hcl
module "transit_gateway" {
  source = "./tgw"

  tgw_name = "primary-transit-gateway"
  
  peering_attachments = [
    {
      name = "cross-region-peering"
      peer_region = "us-west-2"
      peer_transit_gateway_id = "tgw-87654321"
      tags = {
        PeerRegion = "us-west-2"
      }
    }
  ]
  
  tags = {
    Environment = "production"
  }
}
```

### Transit Gateway with Multicast Support

```hcl
module "transit_gateway" {
  source = "./tgw"

  tgw_name = "multicast-transit-gateway"
  multicast_support = "enable"
  create_multicast_domain = true
  multicast_domain_static_sources_support = "enable"
  
  multicast_domain_associations = [
    {
      transit_gateway_attachment_id = "tgw-attach-12345678"
      subnet_id = "subnet-12345678"
    }
  ]
  
  multicast_group_members = [
    {
      group_ip_address = "224.0.0.1"
      network_interface_id = "eni-12345678"
    }
  ]
  
  tags = {
    Environment = "production"
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | >= 5.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 5.0 |

## Inputs

### Transit Gateway Configuration

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| create_tgw | Whether to create the Transit Gateway | `bool` | `true` | no |
| tgw_name | Name of the Transit Gateway | `string` | `"custom-transit-gateway"` | no |
| description | Description of the Transit Gateway | `string` | `"Custom Transit Gateway"` | no |
| amazon_side_asn | Private ASN for the Amazon side of BGP sessions | `number` | `64512` | no |
| auto_accept_shared_attachments | Whether resource attachments are automatically accepted | `string` | `"disable"` | no |
| default_route_table_association | Whether attachments are automatically associated with default route table | `string` | `"enable"` | no |
| default_route_table_propagation | Whether attachments automatically propagate routes to default route table | `string` | `"enable"` | no |
| dns_support | Whether DNS support is enabled | `string` | `"enable"` | no |
| multicast_support | Whether multicast support is enabled | `string` | `"disable"` | no |
| transit_gateway_cidr_blocks | IPv4 or IPv6 CIDR blocks for the transit gateway | `list(string)` | `[]` | no |
| vpn_ecmp_support | Whether VPN ECMP support is enabled | `string` | `"enable"` | no |

### Route Tables Configuration

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| create_route_tables | Whether to create Transit Gateway route tables | `bool` | `false` | no |
| route_tables | List of Transit Gateway route tables to create | `list(object)` | `[]` | no |

### VPC Attachments Configuration

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| vpc_attachments | List of VPC attachments to create | `list(object)` | `[]` | no |

### VPN Attachments Configuration

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| vpn_attachments | List of VPN attachments to create | `list(object)` | `[]` | no |

### Connect Attachments Configuration

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| connect_attachments | List of Connect attachments to create | `list(object)` | `[]` | no |

### Peering Attachments Configuration

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| peering_attachments | List of peering attachments to create | `list(object)` | `[]` | no |

### Routes Configuration

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| routes | List of routes to create in Transit Gateway route tables | `list(object)` | `[]` | no |

### Route Table Associations Configuration

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| route_table_associations | List of route table associations to create | `list(object)` | `[]` | no |

### Route Table Propagations Configuration

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| route_table_propagations | List of route table propagations to create | `list(object)` | `[]` | no |

### Multicast Configuration

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| create_multicast_domain | Whether to create a Transit Gateway multicast domain | `bool` | `false` | no |
| multicast_domain_static_sources_support | Whether to enable static sources support for the multicast domain | `string` | `"disable"` | no |
| multicast_domain_associations | List of multicast domain associations to create | `list(object)` | `[]` | no |
| multicast_group_members | List of multicast group members to create | `list(object)` | `[]` | no |
| multicast_group_sources | List of multicast group sources to create | `list(object)` | `[]` | no |

### Tags Configuration

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| tags | A map of tags to assign to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| transit_gateway_id | The ID of the Transit Gateway |
| transit_gateway_arn | The ARN of the Transit Gateway |
| transit_gateway_owner_id | The ID of the AWS account that owns the Transit Gateway |
| transit_gateway_amazon_side_asn | The private ASN for the Amazon side of BGP sessions |
| transit_gateway_association_default_route_table_id | The ID of the default association route table |
| transit_gateway_propagation_default_route_table_id | The ID of the default propagation route table |
| transit_gateway_route_table_ids | List of Transit Gateway route table IDs |
| transit_gateway_route_table_arns | List of Transit Gateway route table ARNs |
| transit_gateway_vpc_attachment_ids | List of Transit Gateway VPC attachment IDs |
| transit_gateway_vpc_attachment_arns | List of Transit Gateway VPC attachment ARNs |
| transit_gateway_vpc_attachment_vpc_owner_ids | List of VPC owner IDs for Transit Gateway VPC attachments |
| transit_gateway_vpn_attachment_ids | List of Transit Gateway VPN attachment IDs |
| transit_gateway_vpn_attachment_arns | List of Transit Gateway VPN attachment ARNs |
| transit_gateway_connect_attachment_ids | List of Transit Gateway Connect attachment IDs |
| transit_gateway_connect_attachment_arns | List of Transit Gateway Connect attachment ARNs |
| transit_gateway_peering_attachment_ids | List of Transit Gateway peering attachment IDs |
| transit_gateway_peering_attachment_arns | List of Transit Gateway peering attachment ARNs |
| transit_gateway_multicast_domain_id | The ID of the Transit Gateway multicast domain |
| transit_gateway_multicast_domain_arn | The ARN of the Transit Gateway multicast domain |
| transit_gateway_route_table_association_ids | List of Transit Gateway route table association IDs |
| transit_gateway_route_table_propagation_ids | List of Transit Gateway route table propagation IDs |
| transit_gateway_multicast_domain_association_ids | List of Transit Gateway multicast domain association IDs |
| transit_gateway_multicast_group_member_ids | List of Transit Gateway multicast group member IDs |
| transit_gateway_multicast_group_source_ids | List of Transit Gateway multicast group source IDs |
| all_transit_gateway_attachment_ids | List of all Transit Gateway attachment IDs (VPC, VPN, Connect, Peering) |
| all_transit_gateway_attachment_arns | List of all Transit Gateway attachment ARNs (VPC, VPN, Connect, Peering) |

## Examples

See the `examples/` directory for complete working examples:

- [Basic Transit Gateway](examples/basic/)
- [Advanced Transit Gateway with Route Tables](examples/advanced/)
- [Transit Gateway with Peering](examples/peering/)

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This module is licensed under the MIT License. See the LICENSE file for details.

## Support

For issues and questions, please open an issue in the GitHub repository.