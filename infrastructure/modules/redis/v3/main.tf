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

resource "aws_security_group" "sg_redis" {
  name        = "${local.product}-${var.global.environment}-SecurityGroup-Redis"
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
    description = "Allow incoming connection for redis db"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = var.global.cidr_blocks
  }

  ingress {
    description = "Allow internal communication between nodes of redis cluster"
    from_port   = 16379
    to_port     = 16379
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
    Name         = "${local.product}-${var.global.environment}-SecurityGroup-Redis"
    Environment  = var.global.environment
    Module       = local.product
    Team         = var.global.team
  }
}

resource "aws_instance" "ec2_redis" {
  for_each               = local.redis.instances
  key_name               = var.global.bastion_name
  ami                    = local.redis.ami
  instance_type          = var.input.instance_type
  disable_api_termination = var.input.termination_protection
  ebs_optimized          = local.redis.ebs_optimized
  vpc_security_group_ids = [aws_security_group.sg_redis.id]
  subnet_id              = each.value.subnet_id
  iam_instance_profile   = var.input.cloudwatch_iam_profile
  root_block_device {
    volume_size = var.input.volume_size
    volume_type = local.redis.volume_type
    encrypted   = local.redis.encrypted
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
}

locals {
  depends_on = [
    aws_instance.ec2_redis
  ]
  output = {
    ips           = join(",", [for v in aws_instance.ec2_redis : v.private_ip])
    ips_and_ports = join(" ", [for v in aws_instance.ec2_redis : join(":", [v.private_ip, 6379])])
  }
}

resource "null_resource" "create_swap_memory" {
  depends_on = [
    aws_instance.ec2_redis
  ]
  triggers = {
    file_hash = filesha1("${path.root}/${var.input.linux_configuration_path}")
  }
  provisioner "local-exec" {
    command = "ansible-playbook -i ${local.output.ips}, ${path.root}/${var.input.linux_configuration_path} --extra-vars \"target=${local.output.ips}\""
  }
}

resource "null_resource" "install_redis" {
  depends_on = [
    null_resource.create_swap_memory
  ]
  triggers = {
    file_hash = filesha1("${path.module}/install_redis.yaml")
  }
  provisioner "local-exec" {
    command = "ansible-playbook -i ${local.output.ips}, ${path.module}/install_redis.yaml --extra-vars \"target=${local.output.ips} redis_password=${var.input.password}\""
  }
}

resource "null_resource" "create_redis_cluster" {
  depends_on = [
    null_resource.install_redis
  ]
  triggers = {
    file_hash = filesha1("${path.module}/create_redis_cluster.yaml")
  }
  provisioner "local-exec" {
    command = "ansible-playbook -i ${aws_instance.ec2_redis[0].private_ip}, ${path.module}/create_redis_cluster.yaml --extra-vars \"target=${aws_instance.ec2_redis[0].private_ip} redis_cluster_details='${local.output.ips_and_ports}' redis_password=${var.input.password}\""
  }
}

resource "null_resource" "install_cloudwatch_agent" {
  depends_on = [
    null_resource.create_redis_cluster
  ]
  triggers = {
    file_hash = filesha1("${path.root}/${var.input.install_cloudwatch_agent_path}")
  }
  provisioner "local-exec" {
    command = "ansible-playbook -i ${local.output.ips}, ${path.root}/${var.input.install_cloudwatch_agent_path} --extra-vars \"target=${local.output.ips} cloudwatch_agent_config_path=${local.redis.cloudwatch_agent_config_path}\""
  }
}

output "input_variables" {
  depends_on = [
    null_resource.install_cloudwatch_agent
  ]
  value = var.input
}

output "output_variables" {
  depends_on = [
    null_resource.install_cloudwatch_agent
  ]
  value = local.output
}
