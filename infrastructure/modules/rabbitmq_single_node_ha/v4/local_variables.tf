locals {
  product = var.input.product == null ? var.global.product : var.input.product
  rabbitmq = {
    image_id                        = "ocid1.image.oc1.ap-singapore-1.aaaaaaaaijbd2tsltpwcgvosleso3zrjqbfuhsw3vqkufr364jjoff7pijmq"  # Oracle Linux 8
    encrypted                       = true
    initial_configuration_path      = "/home/ubuntu/initial_configuration.json"
    cloudwatch_agent_config_path    = "/opt/oracle/oci-monitoring-agent/bin/config.json"
    instances = {
      1 = {
        name                = "${local.product}-${var.global.environment}-CGES-Stag-Instance-RabbitMQ-001-001-${var.input.version}"
        instance_type       = var.input.instance_type
        availability_domain = var.global.private_availability_domains[0]
        shape_config   = var.input.instance_shape_config

      }
      2 = {
        name                = "${local.product}-${var.global.environment}-CGES-Stag-Instance-RabbitMQ-002-001-${var.input.version}"
        instance_type       = var.input.instance_type
        availability_domain = var.global.private_availability_domains[1]
        shape_config   = var.input.instance_shape_config
      }
    }
  }
}