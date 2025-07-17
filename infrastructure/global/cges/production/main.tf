terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.67"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = var.global.region
}

module "redis" {
  source = "../../../modules/redis/v1"
  global = var.global
  input = {
    instance_type = "t3a.medium"
    password      = "cygnetaspredisclusterproduction"
    volume_size   = 24
    disable_api_termination = true
    cloudwatch_iam_profile = var.global.cloudwatch_role
  }
}

module "rabbitmq_ha" {
  source = "../../../modules/rabbitmq_single_node_ha/v3"
  global = var.global
  input = {
    product                               = null
    instance_type                         = "r6a.xlarge"
    standby_instance_type                 = "r6a.large"
    termination_protection                = false
    initial_configuration_path            = "rabbitmq/initial_configuration.json"
    linux_configuration_path              = "../../../common/linux/create_swap_memory.yaml"
    install_cloudwatch_agent_path         = "../../../common/cloudwatchagent/install_cloudwatch_agent.yaml"
    volume_size                           = 50
    cloudwatch_iam_profile                = var.global.cloudwatch_role
    plugin_version = {
      delayed_message_exchange  = "3.13.0"
    }
  }
}

output "redis_output" {
  depends_on = [
    module.redis
  ]
  value = module.redis
}

output "rabbitmq_ha_output" {
  depends_on = [
    module.rabbitmq_ha
  ]
  value = module.rabbitmq_ha
}