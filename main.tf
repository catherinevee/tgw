# Custom Transit Gateway Module using AWS Provider
# Based on HashiCorp AWS Provider resources

# Transit Gateway
resource "aws_ec2_transit_gateway" "main" {
  count = var.create_tgw ? 1 : 0

  description                     = var.description
  amazon_side_asn                 = var.amazon_side_asn
  auto_accept_shared_attachments  = var.auto_accept_shared_attachments
  default_route_table_association = var.default_route_table_association
  default_route_table_propagation = var.default_route_table_propagation
  dns_support                     = var.dns_support
  multicast_support               = var.multicast_support
  transit_gateway_cidr_blocks     = var.transit_gateway_cidr_blocks
  vpn_ecmp_support                = var.vpn_ecmp_support

  tags = merge(
    {
      Name = var.tgw_name
    },
    var.tags
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Transit Gateway Route Tables
resource "aws_ec2_transit_gateway_route_table" "main" {
  count = var.create_tgw && var.create_route_tables ? length(var.route_tables) : 0

  transit_gateway_id = aws_ec2_transit_gateway.main[0].id
  tags = merge(
    {
      Name = var.route_tables[count.index].name
    },
    var.route_tables[count.index].tags,
    var.tags
  )
}

# Transit Gateway VPC Attachments
resource "aws_ec2_transit_gateway_vpc_attachment" "main" {
  count = var.create_tgw ? length(var.vpc_attachments) : 0

  transit_gateway_id = aws_ec2_transit_gateway.main[0].id
  vpc_id             = var.vpc_attachments[count.index].vpc_id
  subnet_ids         = var.vpc_attachments[count.index].subnet_ids

  appliance_mode_support                          = var.vpc_attachments[count.index].appliance_mode_support
  dns_support                                     = var.vpc_attachments[count.index].dns_support
  ipv6_support                                    = var.vpc_attachments[count.index].ipv6_support
  transit_gateway_default_route_table_association = var.vpc_attachments[count.index].transit_gateway_default_route_table_association
  transit_gateway_default_route_table_propagation = var.vpc_attachments[count.index].transit_gateway_default_route_table_propagation

  tags = merge(
    {
      Name = var.vpc_attachments[count.index].name
    },
    var.vpc_attachments[count.index].tags,
    var.tags
  )
}

# Transit Gateway VPN Attachments
resource "aws_ec2_transit_gateway_vpn_attachment" "main" {
  count = var.create_tgw ? length(var.vpn_attachments) : 0

  transit_gateway_id = aws_ec2_transit_gateway.main[0].id
  vpn_connection_id  = var.vpn_attachments[count.index].vpn_connection_id

  tags = merge(
    {
      Name = var.vpn_attachments[count.index].name
    },
    var.vpn_attachments[count.index].tags,
    var.tags
  )
}

# Transit Gateway Connect Attachments
resource "aws_ec2_transit_gateway_connect" "main" {
  count = var.create_tgw ? length(var.connect_attachments) : 0

  transit_gateway_id      = aws_ec2_transit_gateway.main[0].id
  transport_attachment_id = var.connect_attachments[count.index].transport_attachment_id

  tags = merge(
    {
      Name = var.connect_attachments[count.index].name
    },
    var.connect_attachments[count.index].tags,
    var.tags
  )
}

# Transit Gateway Peering Attachments
resource "aws_ec2_transit_gateway_peering_attachment" "main" {
  count = var.create_tgw ? length(var.peering_attachments) : 0

  peer_region             = var.peering_attachments[count.index].peer_region
  peer_transit_gateway_id = var.peering_attachments[count.index].peer_transit_gateway_id
  transit_gateway_id      = aws_ec2_transit_gateway.main[0].id

  tags = merge(
    {
      Name = var.peering_attachments[count.index].name
    },
    var.peering_attachments[count.index].tags,
    var.tags
  )
}

# Transit Gateway Routes
resource "aws_ec2_transit_gateway_route" "main" {
  count = var.create_tgw ? length(var.routes) : 0

  destination_cidr_block         = var.routes[count.index].destination_cidr_block
  transit_gateway_attachment_id  = var.routes[count.index].transit_gateway_attachment_id
  transit_gateway_route_table_id = var.routes[count.index].transit_gateway_route_table_id
}

# Transit Gateway Route Table Associations
resource "aws_ec2_transit_gateway_route_table_association" "main" {
  count = var.create_tgw ? length(var.route_table_associations) : 0

  transit_gateway_attachment_id  = var.route_table_associations[count.index].transit_gateway_attachment_id
  transit_gateway_route_table_id = var.route_table_associations[count.index].transit_gateway_route_table_id
}

# Transit Gateway Route Table Propagations
resource "aws_ec2_transit_gateway_route_table_propagation" "main" {
  count = var.create_tgw ? length(var.route_table_propagations) : 0

  transit_gateway_attachment_id  = var.route_table_propagations[count.index].transit_gateway_attachment_id
  transit_gateway_route_table_id = var.route_table_propagations[count.index].transit_gateway_route_table_id
}

# Transit Gateway Multicast Domain
resource "aws_ec2_transit_gateway_multicast_domain" "main" {
  count = var.create_tgw && var.create_multicast_domain ? 1 : 0

  transit_gateway_id = aws_ec2_transit_gateway.main[0].id
  static_sources_support = var.multicast_domain_static_sources_support

  tags = merge(
    {
      Name = "${var.tgw_name}-multicast-domain"
    },
    var.tags
  )
}

# Transit Gateway Multicast Domain Association
resource "aws_ec2_transit_gateway_multicast_domain_association" "main" {
  count = var.create_tgw && var.create_multicast_domain ? length(var.multicast_domain_associations) : 0

  transit_gateway_attachment_id   = var.multicast_domain_associations[count.index].transit_gateway_attachment_id
  transit_gateway_multicast_domain_id = aws_ec2_transit_gateway_multicast_domain.main[0].id
  subnet_id                       = var.multicast_domain_associations[count.index].subnet_id
}

# Transit Gateway Multicast Group Member
resource "aws_ec2_transit_gateway_multicast_group_member" "main" {
  count = var.create_tgw && var.create_multicast_domain ? length(var.multicast_group_members) : 0

  group_ip_address                    = var.multicast_group_members[count.index].group_ip_address
  network_interface_id                = var.multicast_group_members[count.index].network_interface_id
  transit_gateway_multicast_domain_id = aws_ec2_transit_gateway_multicast_domain.main[0].id
}

# Transit Gateway Multicast Group Source
resource "aws_ec2_transit_gateway_multicast_group_source" "main" {
  count = var.create_tgw && var.create_multicast_domain ? length(var.multicast_group_sources) : 0

  group_ip_address                    = var.multicast_group_sources[count.index].group_ip_address
  network_interface_id                = var.multicast_group_sources[count.index].network_interface_id
  transit_gateway_multicast_domain_id = aws_ec2_transit_gateway_multicast_domain.main[0].id
} 