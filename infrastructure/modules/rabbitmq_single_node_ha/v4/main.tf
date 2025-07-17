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

#-------------------------------------------------------------
# <---- RabbitMQ Instances ---->
#-------------------------------------------------------------

resource "oci_core_network_security_group" "nsg_rabbitmq" {
  compartment_id = var.global.compartment_id
  vcn_id         = var.global.vcn_id
  display_name   = "${local.product}-${var.global.environment}-NSG-RabbitMQ-HA-${var.input.version}"

  freeform_tags = {
    Name         = "${local.product}-${var.global.environment}-NSG-RabbitMQ-HA-${var.input.version}"
    Environment  = var.global.environment
    Module       = local.product
    Team         = var.global.team
  }
}

resource "oci_core_network_security_group_security_rule" "nsg_rabbitmq_ssh" {
  network_security_group_id = oci_core_network_security_group.nsg_rabbitmq.id
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

resource "oci_core_network_security_group_security_rule" "nsg_rabbitmq_5672" {
  for_each = toset(var.global.cidr_blocks)
  
  network_security_group_id = oci_core_network_security_group.nsg_rabbitmq.id
  direction                 = "INGRESS"
  protocol                  = "6"
  description               = "Allow incoming connection for rabbitmq haproxy"

  source      = each.value
  source_type = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 5672
      max = 5672
    }
  }
}

resource "oci_core_network_security_group_security_rule" "nsg_rabbitmq_5673" {
  for_each = toset(var.global.cidr_blocks)
  
  network_security_group_id = oci_core_network_security_group.nsg_rabbitmq.id
  direction                 = "INGRESS"
  protocol                  = "6"
  description               = "Allow incoming connection for rabbitmq"

  source      = each.value
  source_type = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 5673
      max = 5673
    }
  }
}

resource "oci_core_network_security_group_security_rule" "nsg_rabbitmq_7000" {
  for_each = toset(var.global.cidr_blocks)
  
  network_security_group_id = oci_core_network_security_group.nsg_rabbitmq.id
  direction                 = "INGRESS"
  protocol                  = "6"
  description               = "Allow incoming connection for haproxy stats"

  source      = each.value
  source_type = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 7000
      max = 7000
    }
  }
}

resource "oci_core_network_security_group_security_rule" "nsg_rabbitmq_15672" {
  for_each = toset(var.global.cidr_blocks)
  
  network_security_group_id = oci_core_network_security_group.nsg_rabbitmq.id
  direction                 = "INGRESS"
  protocol                  = "6"
  description               = "Allow incoming connection for rabbitmq management portal haproxy"

  source      = each.value
  source_type = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 15672
      max = 15672
    }
  }
}

resource "oci_core_network_security_group_security_rule" "nsg_rabbitmq_15673" {
  for_each = toset(var.global.cidr_blocks)
  
  network_security_group_id = oci_core_network_security_group.nsg_rabbitmq.id
  direction                 = "INGRESS"
  protocol                  = "6"
  description               = "Allow incoming connection for rabbitmq management portal"

  source      = each.value
  source_type = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 15673
      max = 15673
    }
  }
}

resource "oci_core_network_security_group_security_rule" "nsg_rabbitmq_egress" {
  network_security_group_id = oci_core_network_security_group.nsg_rabbitmq.id
  direction                 = "EGRESS"
  protocol                  = "all"
  description               = "Allow all outbound traffic"

  destination      = "0.0.0.0/0"
  destination_type = "CIDR_BLOCK"
}

resource "oci_core_instance" "compute_rabbitmq" {
  for_each            = local.rabbitmq.instances
  compartment_id      = var.global.compartment_id
  availability_domain = each.value.availability_domain
  shape               = each.value.instance_type

  shape_config {
    ocpus         = local.rabbitmq.ocpus[each.key]
    memory_in_gbs = local.rabbitmq.memory_in_gbs[each.key]
  }

  create_vnic_details {
    subnet_id                 = each.value.subnet_id
    assign_public_ip          = false
    nsg_ids                   = [oci_core_network_security_group.nsg_rabbitmq.id]
    assign_private_dns_record = true
  }

  source_details {
    source_type = "image"
    source_id   = local.rabbitmq.image_id
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
  
  provisioner "file" {
    source      = "${path.root}/${var.input.initial_configuration_path}"
    destination = local.rabbitmq.initial_configuration_path
  }
}

locals {
  depends_on = [
    oci_core_instance.compute_rabbitmq
  ]
  params = {
    ips       = join(",", [for v in oci_core_instance.compute_rabbitmq : v.private_ip])
    haproxy_cfg = templatefile("${path.module}/haproxy.cfg", {
      primary_ip = oci_core_instance.compute_rabbitmq[1].private_ip
      standby_ip = oci_core_instance.compute_rabbitmq[2].private_ip
    })
  }
}

resource "null_resource" "create_swap_memory" {
  depends_on = [
    oci_core_instance.compute_rabbitmq
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
# <---- RabbitMQ Load Balancer ---->
#-------------------------------------------------------------

resource "oci_load_balancer" "lb_rabbitmq" {
  depends_on = [
    null_resource.install_haproxy
  ]

  compartment_id = var.global.compartment_id
  display_name   = "${local.product}-${var.global.environment}-LB-RabbitMQ-HA-${var.input.version}"
  shape          = "flexible"
  subnet_ids     = var.global.availability_domains
  is_private     = true

  shape_details {
    maximum_bandwidth_in_mbps = 100
    minimum_bandwidth_in_mbps = 10
  }

  freeform_tags = {
    Name         = "${local.product}-${var.global.environment}-LB-RabbitMQ-HA-${var.input.version}"
    Environment  = var.global.environment
    Module       = local.product
    Team         = var.global.team
  }
}

resource "oci_load_balancer_backend_set" "lb_backend_set_rabbitmq" {
  depends_on = [
    oci_load_balancer.lb_rabbitmq
  ]

  name             = "${local.product}-${var.global.environment}-BS-RabbitMQ-HA-${var.input.version}"
  load_balancer_id = oci_load_balancer.lb_rabbitmq.id
  policy           = "ROUND_ROBIN"

  health_checker {
    port                = 5672
    protocol            = "TCP"
    interval_ms         = 5000
    timeout_in_millis   = 5000
    retries             = 2
  }
}

resource "oci_load_balancer_backend" "lb_backend_rabbitmq" {
  depends_on = [
    oci_load_balancer_backend_set.lb_backend_set_rabbitmq
  ]

  for_each         = oci_core_instance.compute_rabbitmq
  backendset_name  = oci_load_balancer_backend_set.lb_backend_set_rabbitmq.name
  load_balancer_id = oci_load_balancer.lb_rabbitmq.id
  ip_address       = each.value.private_ip
  port             = 5672
  backup           = false
  drain            = false
  offline          = false
  weight           = 1
}

resource "oci_load_balancer_backend_set" "lb_backend_set_rabbitmq_management" {
  depends_on = [
    oci_load_balancer_backend.lb_backend_rabbitmq
  ]

  name             = "${local.product}-${var.global.environment}-BS-RabbitMQ-HA-MGMT-${var.input.version}"
  load_balancer_id = oci_load_balancer.lb_rabbitmq.id
  policy           = "ROUND_ROBIN"

  health_checker {
    port                = 15672
    protocol            = "TCP"
    interval_ms         = 5000
    timeout_in_millis   = 5000
    retries             = 2
  }
}

resource "oci_load_balancer_backend" "lb_backend_rabbitmq_management" {
  depends_on = [
    oci_load_balancer_backend_set.lb_backend_set_rabbitmq_management
  ]

  for_each         = oci_core_instance.compute_rabbitmq
  backendset_name  = oci_load_balancer_backend_set.lb_backend_set_rabbitmq_management.name
  load_balancer_id = oci_load_balancer.lb_rabbitmq.id
  ip_address       = each.value.private_ip
  port             = 15672
  backup           = false
  drain            = false
  offline          = false
  weight           = 1
}

resource "oci_load_balancer_listener" "lb_listener_rabbitmq" {
  depends_on = [
    oci_load_balancer_backend.lb_backend_rabbitmq_management
  ]

  load_balancer_id         = oci_load_balancer.lb_rabbitmq.id
  name                     = "${local.product}-${var.global.environment}-Listener-RabbitMQ-HA-${var.input.version}"
  default_backend_set_name = oci_load_balancer_backend_set.lb_backend_set_rabbitmq.name
  port                     = 5672
  protocol                 = "TCP"
}

resource "oci_load_balancer_listener" "lb_listener_rabbitmq_management" {
  depends_on = [
    oci_load_balancer_listener.lb_listener_rabbitmq
  ]

  load_balancer_id         = oci_load_balancer.lb_rabbitmq.id
  name                     = "${local.product}-${var.global.environment}-Listener-RabbitMQ-HA-MGMT-${var.input.version}"
  default_backend_set_name = oci_load_balancer_backend_set.lb_backend_set_rabbitmq_management.name
  port                     = 15672
  protocol                 = "TCP"
}

locals {
  output = {
    lb_ip_address = oci_load_balancer.lb_rabbitmq.ip_address_details[0].ip_address
    ips           = local.params.ips
    haproxy_cfg   = local.params.haproxy_cfg
  }
}

output "input_variables" {
  depends_on = [
    oci_load_balancer_listener.lb_listener_rabbitmq_management
  ]
  value = var.input
}

output "output_variables" {
  depends_on = [
    oci_load_balancer_listener.lb_listener_rabbitmq_management
  ]
  value = local.output
}