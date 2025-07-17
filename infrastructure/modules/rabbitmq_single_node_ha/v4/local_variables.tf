locals {
  product = var.input.product == null ? var.global.product : var.input.product
  rabbitmq = {
    image_id                        = "ocid1.image.oc1..aaaaaaaahlnuhlmtlhap6pikl6stxnlmgfgp5jy5rexbnpmj3xboz4zo45lq"  # Oracle Linux 8
    encrypted                       = true
    initial_configuration_path      = "/home/opc/initial_configuration.json"
    cloudwatch_agent_config_path    = "/opt/oracle/oci-monitoring-agent/bin/config.json"
    ocpus = {
      1 = 4
      2 = 2
    }
    memory_in_gbs = {
      1 = 32
      2 = 16
    }
    instances = {
      1 = {
        name                = "${local.product}-${var.global.environment}-Compute-RabbitMQ-HA-001-001-${var.input.version}"
        instance_type       = var.input.instance_type
        subnet_id           = var.global.availability_domains[0]
        availability_domain = var.global.availability_domains[0]
      }
      2 = {
        name                = "${local.product}-${var.global.environment}-Compute-RabbitMQ-HA-002-001-${var.input.version}"
        instance_type       = var.input.standby_instance_type
        subnet_id           = var.global.availability_domains[1]
        availability_domain = var.global.availability_domains[1]
      }
    }
  }
}