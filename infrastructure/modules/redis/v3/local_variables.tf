locals {
  product = var.input.product == null ? var.global.product : var.input.product
  redis = {
    image_id                      = "ocid1.image.oc1..aaaaaaaahlnuhlmtlhap6pikl6stxnlmgfgp5jy5rexbnpmj3xboz4zo45lq"  # Oracle Linux 8
    ocpus                         = 2
    memory_in_gbs                 = 16
    encrypted                     = true
    linux_configuration_path      = "/home/opc/create_swap_memory.yaml"
    cloudwatch_agent_config_path  = "/opt/oracle/oci-monitoring-agent/bin/config.json"
    instances = {
      0 = {
        name                = "${local.product}-${var.global.environment}-Compute-Redis-001-001"
        subnet_id           = var.global.availability_domains[0]
        availability_domain = var.global.availability_domains[0]
      }
      1 = {
        name                = "${local.product}-${var.global.environment}-Compute-Redis-002-001"
        subnet_id           = var.global.availability_domains[1]
        availability_domain = var.global.availability_domains[1]
      }
      2 = {
        name                = "${local.product}-${var.global.environment}-Compute-Redis-003-001"
        subnet_id           = var.global.availability_domains[2]
        availability_domain = var.global.availability_domains[2]
      }
      3 = {
        name                = "${local.product}-${var.global.environment}-Compute-Redis-003-002"
        subnet_id           = var.global.availability_domains[0]
        availability_domain = var.global.availability_domains[0]
      }
      4 = {
        name                = "${local.product}-${var.global.environment}-Compute-Redis-001-002"
        subnet_id           = var.global.availability_domains[1]
        availability_domain = var.global.availability_domains[1]
      }
      5 = {
        name                = "${local.product}-${var.global.environment}-Compute-Redis-002-002"
        subnet_id           = var.global.availability_domains[2]
        availability_domain = var.global.availability_domains[2]
      }
    }
  }
}
