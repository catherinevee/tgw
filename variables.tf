# Transit Gateway Configuration
variable "create_tgw" {
  description = "Whether to create the Transit Gateway"
  type        = bool
  default     = true
}

variable "tgw_name" {
  description = "Name of the Transit Gateway"
  type        = string
  default     = "custom-transit-gateway"

  validation {
    condition     = length(var.tgw_name) > 0 && length(var.tgw_name) <= 255
    error_message = "Transit Gateway name must be between 1 and 255 characters."
  }
}

variable "description" {
  description = "Description of the Transit Gateway"
  type        = string
  default     = "Custom Transit Gateway"
}

variable "amazon_side_asn" {
  description = "Private Autonomous System Number (ASN) for the Amazon side of a BGP session"
  type        = number
  default     = 64512

  validation {
    condition     = var.amazon_side_asn >= 64512 && var.amazon_side_asn <= 65534
    error_message = "Amazon side ASN must be between 64512 and 65534."
  }
}

variable "auto_accept_shared_attachments" {
  description = "Whether resource attachments are automatically accepted"
  type        = string
  default     = "disable"

  validation {
    condition     = contains(["enable", "disable"], var.auto_accept_shared_attachments)
    error_message = "Auto accept shared attachments must be either 'enable' or 'disable'."
  }
}

variable "default_route_table_association" {
  description = "Whether resource attachments are automatically associated with the default association route table"
  type        = string
  default     = "enable"

  validation {
    condition     = contains(["enable", "disable"], var.default_route_table_association)
    error_message = "Default route table association must be either 'enable' or 'disable'."
  }
}

variable "default_route_table_propagation" {
  description = "Whether resource attachments automatically propagate routes to the default propagation route table"
  type        = string
  default     = "enable"

  validation {
    condition     = contains(["enable", "disable"], var.default_route_table_propagation)
    error_message = "Default route table propagation must be either 'enable' or 'disable'."
  }
}

variable "dns_support" {
  description = "Whether DNS support is enabled"
  type        = string
  default     = "enable"

  validation {
    condition     = contains(["enable", "disable"], var.dns_support)
    error_message = "DNS support must be either 'enable' or 'disable'."
  }
}

variable "multicast_support" {
  description = "Whether multicast support is enabled"
  type        = string
  default     = "disable"

  validation {
    condition     = contains(["enable", "disable"], var.multicast_support)
    error_message = "Multicast support must be either 'enable' or 'disable'."
  }
}

variable "transit_gateway_cidr_blocks" {
  description = "One or more IPv4 or IPv6 CIDR blocks for the transit gateway"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for cidr in var.transit_gateway_cidr_blocks : can(cidrhost(cidr, 0))
    ])
    error_message = "All transit gateway CIDR blocks must be valid CIDR notation."
  }
}

variable "vpn_ecmp_support" {
  description = "Whether VPN Equal Cost Multipath Protocol support is enabled"
  type        = string
  default     = "enable"

  validation {
    condition     = contains(["enable", "disable"], var.vpn_ecmp_support)
    error_message = "VPN ECMP support must be either 'enable' or 'disable'."
  }
}

# Route Tables Configuration
variable "create_route_tables" {
  description = "Whether to create Transit Gateway route tables"
  type        = bool
  default     = false
}

variable "route_tables" {
  description = "List of Transit Gateway route tables to create"
  type = list(object({
    name = string
    tags = map(string)
  }))
  default = []
}

# VPC Attachments Configuration
variable "vpc_attachments" {
  description = "List of VPC attachments to create"
  type = list(object({
    name                                              = string
    vpc_id                                            = string
    subnet_ids                                        = list(string)
    appliance_mode_support                            = string
    dns_support                                       = string
    ipv6_support                                      = string
    transit_gateway_default_route_table_association   = bool
    transit_gateway_default_route_table_propagation   = bool
    tags                                              = map(string)
  }))
  default = []

  validation {
    condition = alltrue([
      for attachment in var.vpc_attachments : contains(["enable", "disable"], attachment.appliance_mode_support)
    ])
    error_message = "Appliance mode support must be either 'enable' or 'disable'."
  }

  validation {
    condition = alltrue([
      for attachment in var.vpc_attachments : contains(["enable", "disable"], attachment.dns_support)
    ])
    error_message = "DNS support must be either 'enable' or 'disable'."
  }

  validation {
    condition = alltrue([
      for attachment in var.vpc_attachments : contains(["enable", "disable"], attachment.ipv6_support)
    ])
    error_message = "IPv6 support must be either 'enable' or 'disable'."
  }
}

# VPN Attachments Configuration
variable "vpn_attachments" {
  description = "List of VPN attachments to create"
  type = list(object({
    name             = string
    vpn_connection_id = string
    tags             = map(string)
  }))
  default = []
}

# Connect Attachments Configuration
variable "connect_attachments" {
  description = "List of Connect attachments to create"
  type = list(object({
    name                  = string
    transport_attachment_id = string
    tags                  = map(string)
  }))
  default = []
}

# Peering Attachments Configuration
variable "peering_attachments" {
  description = "List of peering attachments to create"
  type = list(object({
    name                    = string
    peer_region             = string
    peer_transit_gateway_id = string
    tags                    = map(string)
  }))
  default = []
}

# Routes Configuration
variable "routes" {
  description = "List of routes to create in Transit Gateway route tables"
  type = list(object({
    destination_cidr_block        = string
    transit_gateway_attachment_id = string
    transit_gateway_route_table_id = string
  }))
  default = []

  validation {
    condition = alltrue([
      for route in var.routes : can(cidrhost(route.destination_cidr_block, 0))
    ])
    error_message = "All destination CIDR blocks must be valid CIDR notation."
  }
}

# Route Table Associations Configuration
variable "route_table_associations" {
  description = "List of route table associations to create"
  type = list(object({
    transit_gateway_attachment_id  = string
    transit_gateway_route_table_id = string
  }))
  default = []
}

# Route Table Propagations Configuration
variable "route_table_propagations" {
  description = "List of route table propagations to create"
  type = list(object({
    transit_gateway_attachment_id  = string
    transit_gateway_route_table_id = string
  }))
  default = []
}

# Multicast Configuration
variable "create_multicast_domain" {
  description = "Whether to create a Transit Gateway multicast domain"
  type        = bool
  default     = false
}

variable "multicast_domain_static_sources_support" {
  description = "Whether to enable static sources support for the multicast domain"
  type        = string
  default     = "disable"

  validation {
    condition     = contains(["enable", "disable"], var.multicast_domain_static_sources_support)
    error_message = "Multicast domain static sources support must be either 'enable' or 'disable'."
  }
}

variable "multicast_domain_associations" {
  description = "List of multicast domain associations to create"
  type = list(object({
    transit_gateway_attachment_id = string
    subnet_id                     = string
  }))
  default = []
}

variable "multicast_group_members" {
  description = "List of multicast group members to create"
  type = list(object({
    group_ip_address     = string
    network_interface_id = string
  }))
  default = []

  validation {
    condition = alltrue([
      for member in var.multicast_group_members : can(cidrhost("${member.group_ip_address}/32", 0))
    ])
    error_message = "All group IP addresses must be valid IPv4 addresses."
  }
}

variable "multicast_group_sources" {
  description = "List of multicast group sources to create"
  type = list(object({
    group_ip_address     = string
    network_interface_id = string
  }))
  default = []

  validation {
    condition = alltrue([
      for source in var.multicast_group_sources : can(cidrhost("${source.group_ip_address}/32", 0))
    ])
    error_message = "All group IP addresses must be valid IPv4 addresses."
  }
}

# Tags Configuration
variable "tags" {
  description = "A map of tags to assign to all resources"
  type        = map(string)
  default     = {}

  validation {
    condition     = length(var.tags) <= 50
    error_message = "Maximum of 50 tags allowed per resource."
  }
} 