locals {
  product = var.input.product == null ? var.global.product : var.input.product
  rabbitmq = {
    ami                             = "ami-0e35ddab05955cf57"
    volume_type                     = "gp3"
    encrypted                       = true
    ebs_optimized                   = true
    initial_configuration_path      = "/home/ubuntu/initial_configuration.json"
    cloudwatch_agent_config_path    = "/opt/aws/amazon-cloudwatch-agent/bin/config.json"
    instances = {
      1 = {
        name          = "${local.product}-${var.global.environment}-EC2-RabbitMQ-HA-001-001-${var.input.version}"
        instance_type = var.input.instance_type
        subnet_id     = var.global.availability_zones[0]
      }
      2 = {
        name          = "${local.product}-${var.global.environment}-EC2-RabbitMQ-HA-002-001-${var.input.version}"
        instance_type = var.input.standby_instance_type
        subnet_id     = var.global.availability_zones[1]
      }
    }
  }
}