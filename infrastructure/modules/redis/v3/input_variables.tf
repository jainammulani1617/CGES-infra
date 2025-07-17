variable "input" {
  type = object({
    product                       = string
    instance_type                 = string
    password                      = string
    volume_size                   = number
    termination_protection        = bool
    cloudwatch_iam_profile        = string
    linux_configuration_path      = string
    install_cloudwatch_agent_path = string
  })
  description = "Samples values {instance_type=\"t3a.medium\",password=\"cygnet{product}\",volume_size=8,cloudwatch_iam_profile=\"{cloudwatch_iam_profile}\"}"
}
