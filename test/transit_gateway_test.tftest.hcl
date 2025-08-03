run "validate_transit_gateway_creation" {
  command = plan

  assert {
    condition     = module.transit_gateway.transit_gateway_id != null
    error_message = "Transit Gateway should be created"
  }

  assert {
    condition     = module.transit_gateway.transit_gateway_arn != null
    error_message = "Transit Gateway ARN should be available"
  }

  assert {
    condition     = module.transit_gateway.vpc_attachment_count == 1
    error_message = "Should have exactly 1 VPC attachment"
  }

  assert {
    condition     = module.transit_gateway.route_table_count == 1
    error_message = "Should have exactly 1 custom route table"
  }
}

run "validate_vpc_attachments" {
  command = plan

  assert {
    condition     = length(module.transit_gateway.vpc_attachment_ids) == 1
    error_message = "Should have exactly 1 VPC attachment ID"
  }

  assert {
    condition     = contains(keys(module.transit_gateway.vpc_attachment_ids), "test_vpc")
    error_message = "Should have VPC attachment with key 'test_vpc'"
  }
}

run "validate_route_tables" {
  command = plan

  assert {
    condition     = length(module.transit_gateway.route_table_ids) == 1
    error_message = "Should have exactly 1 route table ID"
  }

  assert {
    condition     = contains(keys(module.transit_gateway.route_table_ids), "test_routes")
    error_message = "Should have route table with key 'test_routes'"
  }
}

run "validate_route_table_associations" {
  command = plan

  assert {
    condition     = length(module.transit_gateway.route_table_association_ids) == 1
    error_message = "Should have exactly 1 route table association"
  }
} 