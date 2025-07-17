locals {
  product = var.input.product == null ? var.global.product : var.input.product
  redis = {
    ami                           = "ami-0f5ee92e2d63afc18"
    volume_type                   = "gp3"
    encrypted                     = true
    ebs_optimized                 = true
    linux_configuration_path      = "/home/ubuntu/create_swap_memory.yaml"
    cloudwatch_agent_config_path  = "/opt/aws/amazon-cloudwatch-agent/bin/config.json"
    instances = {
      0 = {
        name      = "${local.product}-${var.global.environment}-EC2-Redis-001-001"
        subnet_id = var.global.availability_zones[0]
      }
      1 = {
        name      = "${local.product}-${var.global.environment}-EC2-Redis-002-001"
        subnet_id = var.global.availability_zones[1]
      }
      2 = {
        name      = "${local.product}-${var.global.environment}-EC2-Redis-003-001"
        subnet_id = var.global.availability_zones[2]
      }
      3 = {
        name      = "${local.product}-${var.global.environment}-EC2-Redis-003-002"
        subnet_id = var.global.availability_zones[0]
      }
      4 = {
        name      = "${local.product}-${var.global.environment}-EC2-Redis-001-002"
        subnet_id = var.global.availability_zones[1]
      }
      5 = {
        name      = "${local.product}-${var.global.environment}-EC2-Redis-002-002"
        subnet_id = var.global.availability_zones[2]
      }
    }
  }
}
