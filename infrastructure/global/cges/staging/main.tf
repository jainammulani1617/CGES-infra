terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = var.global.region
}

module "rabbitmq_ha_v4" {
  source = "../../../modules/rabbitmq_single_node_ha/v4"
  global = var.global
  input = {
    product                               = null
    version                               = "v4"
    instance_type                         = "t3a.large"
    standby_instance_type                 = "t3a.small"
    termination_protection                = true
    initial_configuration_path            = "rabbitmq/initial_configuration.json"
    linux_configuration_path              = "../../../common/linux/create_swap_memory.yaml"
    install_cloudwatch_agent_path         = "../../../common/cloudwatchagent/install_cloudwatch_agent.yaml"
    volume_size                           = 50
    cloudwatch_iam_profile                = var.global.cloudwatch_role
    plugin_version = {
      delayed_message_exchange  = "4.1.0"
    }
    instance_ips_for_upgrade              = []
  }
}

module "redis" {
  source = "../../../modules/redis/v3"
  global = var.global
  input = {
    product                       = null
    instance_type                 = "t3a.small"
    password                      = "cygnetaspredisstaging"
    linux_configuration_path      = "../../../common/linux/create_swap_memory.yaml"
    install_cloudwatch_agent_path = "../../../common/cloudwatchagent/install_cloudwatch_agent.yaml"
    volume_size                   = 50
    cloudwatch_iam_profile        = var.global.cloudwatch_role
    termination_protection        = false
  }
}

output "rabbitmq_ha_v4_output" {
  depends_on = [
    module.rabbitmq_ha_v4
  ]
  value = module.rabbitmq_ha_v4
}

output "redis_output" {
  depends_on = [
    module.redis
  ]
  value = module.redis
}