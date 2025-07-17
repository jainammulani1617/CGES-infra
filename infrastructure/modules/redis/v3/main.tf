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

resource "oci_core_network_security_group" "nsg_redis" {
  compartment_id = var.global.compartment_id
  vcn_id         = var.global.vcn_id
  display_name   = "${local.product}-${var.global.environment}-NSG-Redis"

  freeform_tags = {
    Name         = "${local.product}-${var.global.environment}-NSG-Redis"
    Environment  = var.global.environment
    Module       = local.product
    Team         = var.global.team
  }
}

resource "oci_core_network_security_group_security_rule" "nsg_redis_ssh" {
  network_security_group_id = oci_core_network_security_group.nsg_redis.id
  direction                 = "INGRESS"
  protocol                  = "6"
  description               = "Allow SSH from bastion"

  source      = var.global.bastion_ip
  source_type = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 22
      max = 22
    }
  }
}

resource "oci_core_network_security_group_security_rule" "nsg_redis_6379" {
  for_each = toset(var.global.cidr_blocks)
  
  network_security_group_id = oci_core_network_security_group.nsg_redis.id
  direction                 = "INGRESS"
  protocol                  = "6"
  description               = "Allow incoming connection for redis db"

  source      = each.value
  source_type = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 6379
      max = 6379
    }
  }
}

resource "oci_core_network_security_group_security_rule" "nsg_redis_16379" {
  for_each = toset(var.global.cidr_blocks)
  
  network_security_group_id = oci_core_network_security_group.nsg_redis.id
  direction                 = "INGRESS"
  protocol                  = "6"
  description               = "Allow internal communication between nodes of redis cluster"

  source      = each.value
  source_type = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 16379
      max = 16379
    }
  }
}

resource "oci_core_network_security_group_security_rule" "nsg_redis_egress" {
  network_security_group_id = oci_core_network_security_group.nsg_redis.id
  direction                 = "EGRESS"
  protocol                  = "all"
  description               = "Allow all outbound traffic"

  destination      = "0.0.0.0/0"
  destination_type = "CIDR_BLOCK"
}

resource "oci_core_instance" "compute_redis" {
  for_each            = local.redis.instances
  compartment_id      = var.global.compartment_id
  availability_domain = each.value.availability_domain
  shape               = var.input.instance_type

  shape_config {
    ocpus         = local.redis.ocpus
    memory_in_gbs = local.redis.memory_in_gbs
  }

  create_vnic_details {
    subnet_id                 = each.value.subnet_id
    assign_public_ip          = false
    nsg_ids                   = [oci_core_network_security_group.nsg_redis.id]
    assign_private_dns_record = true
  }

  source_details {
    source_type = "image"
    source_id   = local.redis.image_id
    boot_volume_size_in_gbs = var.input.volume_size
  }

  metadata = {
    ssh_authorized_keys = file(var.global.bastion_key)
  }

  instance_options {
    are_legacy_imds_endpoints_disabled = false
  }

  is_pv_encryption_in_transit_enabled = true

  freeform_tags = {
    Name        = each.value.name
    Environment = var.global.environment
    Module      = local.product
    Team        = var.global.team
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
    oci_core_instance.compute_redis
  ]
  output = {
    ips           = join(",", [for v in oci_core_instance.compute_redis : v.private_ip])
    ips_and_ports = join(" ", [for v in oci_core_instance.compute_redis : join(":", [v.private_ip, 6379])])
  }
}

resource "null_resource" "create_swap_memory" {
  depends_on = [
    oci_core_instance.compute_redis
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
    command = "ansible-playbook -i ${values(oci_core_instance.compute_redis)[0].private_ip}, ${path.module}/create_redis_cluster.yaml --extra-vars \"target=${values(oci_core_instance.compute_redis)[0].private_ip} redis_cluster_details='${local.output.ips_and_ports}' redis_password=${var.input.password}\""
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
