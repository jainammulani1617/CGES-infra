variable "input" {
  type = object({
    product                       = string
    version                       = string
    instance_shape = string
    instance_shape_config = object({
      ocpus         = number
      memory_in_gbs = number
    })
    standby_instance_shape = string
    standby_instance_shape_config = object({
      ocpus         = number
      memory_in_gbs = number
    })
    volume_size                   = number
    termination_protection        = bool
    initial_configuration_path    = string
    # cloudwatch_iam_profile        = string
    linux_configuration_path      = string
    install_monitoring_agent_path = string
    plugin_version            = object({
      delayed_message_exchange  = string
    })
    instance_ips_for_upgrade    = list(string)
  })
  description = "Samples values {instance_type=\"c5a.large\", initial_configuration_path=\"global/{product}/{environment}/rabbitmq/initial_configuration.json\",volume_size=8,cloudwatch_iam_profile=\"{cloudwatch_iam_profile}\"}"
}