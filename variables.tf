variable "name" {
  description = "Name of the Transit Gateway. Must be unique within the AWS account."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9-]+$", var.name))
    error_message = "Transit Gateway name must contain only alphanumeric characters and hyphens."
  }
}

variable "description" {
  description = "Description of the Transit Gateway."
  type        = string
  default     = null
}

variable "amazon_side_asn" {
  description = "Private Autonomous System Number (ASN) for the Amazon side of a BGP session. The range is 64512 to 65534 for 16-bit ASNs and 4200000000 to 4294967294 for 32-bit ASNs."
  type        = number
  default     = 64512

  validation {
    condition = (
      var.amazon_side_asn >= 64512 && var.amazon_side_asn <= 65534 ||
      var.amazon_side_asn >= 4200000000 && var.amazon_side_asn <= 4294967294
    )
    error_message = "Amazon side ASN must be between 64512-65534 (16-bit) or 4200000000-4294967294 (32-bit)."
  }
}

variable "auto_accept_shared_attachments" {
  description = "Whether resource attachments are automatically accepted. Valid values: disable, enable."
  type        = string
  default     = "disable"

  validation {
    condition     = contains(["disable", "enable"], var.auto_accept_shared_attachments)
    error_message = "Auto accept shared attachments must be either 'disable' or 'enable'."
  }
}

variable "default_route_table_association" {
  description = "Whether resource attachments are automatically associated with the default association route table. Valid values: disable, enable."
  type        = string
  default     = "enable"

  validation {
    condition     = contains(["disable", "enable"], var.default_route_table_association)
    error_message = "Default route table association must be either 'disable' or 'enable'."
  }
}

variable "default_route_table_propagation" {
  description = "Whether resource attachments automatically propagate routes to the default propagation route table. Valid values: disable, enable."
  type        = string
  default     = "enable"

  validation {
    condition     = contains(["disable", "enable"], var.default_route_table_propagation)
    error_message = "Default route table propagation must be either 'disable' or 'enable'."
  }
}

variable "dns_support" {
  description = "Whether DNS support is enabled. Valid values: disable, enable."
  type        = string
  default     = "enable"

  validation {
    condition     = contains(["disable", "enable"], var.dns_support)
    error_message = "DNS support must be either 'disable' or 'enable'."
  }
}

variable "vpn_ecmp_support" {
  description = "Whether VPN Equal Cost Multipath Protocol support is enabled. Valid values: disable, enable."
  type        = string
  default     = "enable"

  validation {
    condition     = contains(["disable", "enable"], var.vpn_ecmp_support)
    error_message = "VPN ECMP support must be either 'disable' or 'enable'."
  }
}

variable "multicast_support" {
  description = "Whether multicast support is enabled. Valid values: disable, enable."
  type        = string
  default     = "disable"

  validation {
    condition     = contains(["disable", "enable"], var.multicast_support)
    error_message = "Multicast support must be either 'disable' or 'enable'."
  }
}

variable "vpc_attachments" {
  description = "Map of VPC attachments to create. Each attachment requires vpc_id and subnet_ids."
  type = map(object({
    vpc_id                    = string
    subnet_ids                = list(string)
    dns_support               = optional(string, "enable")
    ipv6_support              = optional(string, "disable")
    appliance_mode_support    = optional(string, "disable")
    transit_gateway_default_route_table_association = optional(bool, true)
    transit_gateway_default_route_table_propagation  = optional(bool, true)
    tags                      = optional(map(string), {})
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.vpc_attachments : 
      contains(["disable", "enable"], v.dns_support)
    ])
    error_message = "DNS support must be either 'disable' or 'enable' for all VPC attachments."
  }

  validation {
    condition = alltrue([
      for k, v in var.vpc_attachments : 
      contains(["disable", "enable"], v.ipv6_support)
    ])
    error_message = "IPv6 support must be either 'disable' or 'enable' for all VPC attachments."
  }

  validation {
    condition = alltrue([
      for k, v in var.vpc_attachments : 
      contains(["disable", "enable"], v.appliance_mode_support)
    ])
    error_message = "Appliance mode support must be either 'disable' or 'enable' for all VPC attachments."
  }
}

variable "route_tables" {
  description = "Map of custom route tables to create. Each route table requires a name."
  type = map(object({
    name        = string
    description = optional(string, null)
    tags        = optional(map(string), {})
  }))
  default = {}
}

variable "route_table_associations" {
  description = "Map of route table associations. Key is the attachment name, value is the route table name."
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([
      for k, v in var.route_table_associations : 
      contains(keys(var.route_tables), v) || v == "main"
    ])
    error_message = "Route table associations must reference existing route tables or 'main' for the default route table."
  }
}

variable "routes" {
  description = "Map of routes to create in Transit Gateway route tables."
  type = map(object({
    destination_cidr_block         = string
    transit_gateway_attachment_id  = string
    transit_gateway_route_table_id = string
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.routes : 
      can(cidrhost(v.destination_cidr_block, 0))
    ])
    error_message = "All destination CIDR blocks must be valid IPv4 or IPv6 CIDR notation."
  }
}

variable "peering_attachments" {
  description = "Map of Transit Gateway peering attachments to create."
  type = map(object({
    peer_region              = string
    peer_transit_gateway_id  = string
    peer_account_id          = optional(string, null)
    tags                     = optional(map(string), {})
  }))
  default = {}
}

variable "tags" {
  description = "A map of tags to assign to the Transit Gateway and all created resources."
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([
      for k, v in var.tags : 
      length(k) <= 128 && length(v) <= 256
    ])
    error_message = "Tag keys must be 128 characters or less, and tag values must be 256 characters or less."
  }
}

variable "enable_flow_logs" {
  description = "Whether to enable VPC Flow Logs for Transit Gateway attachments."
  type        = bool
  default     = false
}

variable "flow_log_retention_in_days" {
  description = "The number of days to retain VPC Flow Logs. Valid values: 0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653."
  type        = number
  default     = 30

  validation {
    condition = contains([0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.flow_log_retention_in_days)
    error_message = "Flow log retention must be one of the valid values: 0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653."
  }
} 