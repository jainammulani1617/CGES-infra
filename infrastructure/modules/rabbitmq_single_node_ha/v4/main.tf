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

#-------------------------------------------------------------
# <---- RabbitMQ Instances ---->
#-------------------------------------------------------------

resource "aws_security_group" "sg_rabbitmq" {
  name        = "${local.product}-${var.global.environment}-SecurityGroup-RabbitMQ-HA-${var.input.version}"
  description = "Allow inbound traffic from application"
  vpc_id      = var.global.vpc_id

  ingress {
    description = "Allow SSH from bastion"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.global.bastion_ip]
  }

  ingress {
    description = "Allow incoming connection for rabbitmq haproxy"
    from_port   = 5672
    to_port     = 5672
    protocol    = "tcp"
    cidr_blocks = var.global.cidr_blocks
  }

  ingress {
    description = "Allow incoming connection for rabbitmq"
    from_port   = 5673
    to_port     = 5673
    protocol    = "tcp"
    cidr_blocks = var.global.cidr_blocks
  }

  ingress {
    description = "Allow incoming connection for haproxy stats"
    from_port   = 7000
    to_port     = 7000
    protocol    = "tcp"
    cidr_blocks = var.global.cidr_blocks
  }

  ingress {
    description = "Allow incomming connection for rabbitmq management portal haproxy"
    from_port   = 15672
    to_port     = 15672
    protocol    = "tcp"
    cidr_blocks = var.global.cidr_blocks
  }

  ingress {
    description = "Allow incomming connection for rabbitmq management portal"
    from_port   = 15673
    to_port     = 15673
    protocol    = "tcp"
    cidr_blocks = var.global.cidr_blocks
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name         = "${local.product}-${var.global.environment}-SecurityGroup-RabbitMQ-HA-${var.input.version}"
    Environment  = var.global.environment
    Module       = local.product
    Team         = var.global.team
  }
}

resource "aws_instance" "ec2_rabbitmq" {
  for_each               = local.rabbitmq.instances
  key_name               = var.global.bastion_name
  ami                    = local.rabbitmq.ami
  instance_type          = each.value.instance_type
  disable_api_termination = var.input.termination_protection
  ebs_optimized          = local.rabbitmq.ebs_optimized
  vpc_security_group_ids = [aws_security_group.sg_rabbitmq.id]
  subnet_id              = each.value.subnet_id
  iam_instance_profile   = var.input.cloudwatch_iam_profile
  root_block_device {
    volume_size = var.input.volume_size
    volume_type = local.rabbitmq.volume_type
    encrypted   = local.rabbitmq.encrypted
  }
  tags = {
    Name         = each.value.name
    Environment  = var.global.environment
    Module       = local.product
    Team         = var.global.team
  }
  connection {
    type        = "ssh"
    user        = var.global.bastion_user
    host        = self.private_ip
    private_key = file(var.global.bastion_key)
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Wait until SSH is ready'"
    ]
  }
  provisioner "file" {
    source      = "${path.root}/${var.input.initial_configuration_path}"
    destination = local.rabbitmq.initial_configuration_path
  }
}

locals {
  depends_on = [
    aws_instance.ec2_rabbitmq
  ]
  params = {
    ips       = join(",", [for v in aws_instance.ec2_rabbitmq : v.private_ip])
    haproxy_cfg = templatefile("${path.module}/haproxy.cfg", {
      primary_ip = aws_instance.ec2_rabbitmq[1].private_ip
      standby_ip = aws_instance.ec2_rabbitmq[2].private_ip
    })
  }
}

resource "null_resource" "create_swap_memory" {
  depends_on = [
    aws_instance.ec2_rabbitmq
  ]
  triggers = {
    file_hash = filesha1("${path.root}/${var.input.linux_configuration_path}")
  }
  provisioner "local-exec" {
    command = "ansible-playbook -i ${local.params.ips}, ${path.root}/${var.input.linux_configuration_path} --extra-vars \"target=${local.params.ips}\""
  }
}

resource "null_resource" "install_rabbitmq" {
  for_each = length(var.input.instance_ips_for_upgrade) == 0 ? { "run" = "true" } : {}
  
  depends_on = [
    null_resource.create_swap_memory
  ]
  triggers = {
    file_hash = filesha1("${path.module}/install_rabbitmq.yaml")
  }
  provisioner "local-exec" {
    command = "ansible-playbook -i ${local.params.ips}, ${path.module}/install_rabbitmq.yaml --extra-vars \"target=${local.params.ips} initial_configuration_path=${local.rabbitmq.initial_configuration_path} delayed_message_exchange_version=${var.input.plugin_version.delayed_message_exchange}\""
  }
}

resource "null_resource" "configure_rabbitmq" {
  depends_on = [
    null_resource.install_rabbitmq
  ]
  triggers = {
    file_hash = filesha1("${path.module}/configure_rabbitmq.yaml")
  }
  provisioner "local-exec" {
    command = "ansible-playbook -i ${local.params.ips}, ${path.module}/configure_rabbitmq.yaml --extra-vars \"target=${local.params.ips} \""
  }
}

resource "null_resource" "install_cloudwatch_agent" {
  depends_on = [
    null_resource.configure_rabbitmq
  ]
  triggers = {
    file_hash = filesha1("${path.root}/${var.input.install_cloudwatch_agent_path}")
  }
  provisioner "local-exec" {
    command = "ansible-playbook -i ${local.params.ips}, ${path.root}/${var.input.install_cloudwatch_agent_path} --extra-vars \"target=${local.params.ips} cloudwatch_agent_config_path=${local.rabbitmq.cloudwatch_agent_config_path}\""
  }
}

resource "local_file" "prepare_haproxy_cfg_output" {
  depends_on = [
    null_resource.install_cloudwatch_agent
  ]

  content = local.params.haproxy_cfg
  filename = "${path.root}/values-haproxy-cfg-output.yaml"
}

resource "null_resource" "install_haproxy" {
  depends_on = [
    local_file.prepare_haproxy_cfg_output
  ]
  triggers = {
    policy_sha1 = sha1(local.params.haproxy_cfg)
  }
  provisioner "local-exec" {
    command = "ansible-playbook -i ${local.params.ips}, ${path.module}/install_haproxy.yaml --extra-vars \"target=${local.params.ips} haproxy_source_cfg_file=${path.cwd}/values-haproxy-cfg-output.yaml\""
  }
}

resource "null_resource" "uninstall_rabbitmq" {
  for_each = toset(var.input.instance_ips_for_upgrade)

  depends_on = [
    null_resource.create_swap_memory
  ]
  triggers = {
    file_hash = filesha1("${path.module}/uninstall_rabbitmq.yaml")
  }
  provisioner "local-exec" {
    command = "ansible-playbook -i ${each.value}, ${path.module}/uninstall_rabbitmq.yaml --extra-vars \"target=${each.value} \""
  }
}

resource "null_resource" "reinstall_rabbitmq" {
  for_each = toset(var.input.instance_ips_for_upgrade)

  depends_on = [
    null_resource.uninstall_rabbitmq
  ]
  triggers = {
    file_hash = filesha1("${path.module}/uninstall_rabbitmq.yaml")
  }
  provisioner "local-exec" {
    command = "ansible-playbook -i ${each.value}, ${path.module}/install_rabbitmq.yaml --extra-vars \"target=${each.value} initial_configuration_path=${local.rabbitmq.initial_configuration_path} delayed_message_exchange_version=${var.input.plugin_version.delayed_message_exchange}\""
  }
}

resource "null_resource" "reconfigure_rabbitmq" {
  for_each = toset(var.input.instance_ips_for_upgrade)

  depends_on = [
    null_resource.reinstall_rabbitmq
  ]
  triggers = {
    file_hash = filesha1("${path.module}/uninstall_rabbitmq.yaml")
  }
  provisioner "local-exec" {
    command = "ansible-playbook -i ${each.value}, ${path.module}/configure_rabbitmq.yaml --extra-vars \"target=${each.value} \""
  }
}

#-------------------------------------------------------------
# <---- RabbitMQ NLB ---->
#-------------------------------------------------------------

resource "aws_lb_target_group" "nlb_tg_rabbitmq" {
  depends_on = [
    null_resource.install_haproxy
  ]

  name        = "${local.product}-${var.global.environment}-TG-RabbitMQ-HA-${var.input.version}"
  port        = 5672
  protocol    = "TCP"
  vpc_id      = var.global.vpc_id
  
  health_check {
    interval            = 5
    protocol            = "TCP"
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name         = "${local.product}-${var.global.environment}-TG-RabbitMQ-HA-${var.input.version}"
    Environment  = var.global.environment
    Module       = local.product
    Team         = var.global.team
  }
}

resource "aws_lb_target_group_attachment" "nlb_tg_attachment_rabbitmq" {
  depends_on = [
    aws_lb_target_group.nlb_tg_rabbitmq
  ]

  for_each         = aws_instance.ec2_rabbitmq
  target_group_arn = aws_lb_target_group.nlb_tg_rabbitmq.arn
  target_id        = each.value.id
}

resource "aws_lb_target_group" "nlb_tg_rabbitmq_management" {
  depends_on = [
    aws_lb_target_group_attachment.nlb_tg_attachment_rabbitmq
  ]

  name        = "${local.product}-${var.global.environment}-TG-RabbitMQ-HA-MGMT-${var.input.version}"
  port        = 15672
  protocol    = "TCP"
  vpc_id      = var.global.vpc_id
  
  health_check {
    interval            = 5
    protocol            = "TCP"
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name         = "${local.product}-${var.global.environment}-TG-RabbitMQ-HA-MGMT-${var.input.version}"
    Environment  = var.global.environment
    Module       = local.product
    Team         = var.global.team
  }
}

resource "aws_lb_target_group_attachment" "nlb_tg_attachment_rabbitmq_management" {
  depends_on = [
    aws_lb_target_group.nlb_tg_rabbitmq_management
  ]

  for_each         = aws_instance.ec2_rabbitmq
  target_group_arn = aws_lb_target_group.nlb_tg_rabbitmq_management.arn
  target_id        = each.value.id
}

resource "aws_lb" "nlb_rabbitmq" {
  depends_on = [
    aws_lb_target_group_attachment.nlb_tg_attachment_rabbitmq_management
  ]

  name               = "${local.product}-${var.global.environment}-NLB-RabbitMQ-HA-${var.input.version}"
  internal           = true
  load_balancer_type = "network"
  subnets            = var.global.availability_zones
  enable_deletion_protection = var.input.termination_protection

  tags = {
    Name         = "${local.product}-${var.global.environment}-NLB-RabbitMQ-HA-${var.input.version}"
    Environment  = var.global.environment
    Module       = local.product
    Team         = var.global.team
  }
}

resource "aws_lb_listener" "nlb_listener_rabbitmq" {
  depends_on = [
    aws_lb.nlb_rabbitmq
  ]

  load_balancer_arn = aws_lb.nlb_rabbitmq.arn
  port              = 5672
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nlb_tg_rabbitmq.arn
  }
}

resource "aws_lb_listener" "nlb_listener_rabbitmq_management" {
  depends_on = [
    aws_lb_listener.nlb_listener_rabbitmq
  ]

  load_balancer_arn = aws_lb.nlb_rabbitmq.arn
  port              = 15672
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nlb_tg_rabbitmq_management.arn
  }
}

locals {
  output = {
    nlb_dns_name = aws_lb.nlb_rabbitmq.dns_name
    ips          = local.params.ips
    haproxy_cfg  = local.params.haproxy_cfg
  }
}

output "input_variables" {
  depends_on = [
    aws_lb_listener.nlb_listener_rabbitmq
  ]
  value = var.input
}

output "output_variables" {
  depends_on = [
    aws_lb_listener.nlb_listener_rabbitmq
  ]
  value = local.output
}