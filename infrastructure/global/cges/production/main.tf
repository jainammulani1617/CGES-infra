terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 6.26.0"
    }
  }

  required_version = ">= 1.2.0"
}

provider "oci" {
  region = var.global.region
}

module "redis" {
  source = "../../../modules/redis/v3"
  global = var.global
  input = {
    instance_type = "VM.Standard.E4.Flex"
    password      = "cygnetaspredisclusterproduction"
    volume_size   = 24
    disable_api_termination = true
    cloudwatch_iam_profile = var.global.cloudwatch_role
  }
}

module "rabbitmq_ha" {
  source = "../../../modules/rabbitmq_single_node_ha/v4"
  global = var.global
  input = {
    product                               = null
    instance_type                         = "VM.Standard.E4.Flex"
    standby_instance_type                 = "VM.Standard.E4.Flex"
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