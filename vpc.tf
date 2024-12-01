# VPC Creation
resource "linode_vpc" "red5vpc" {
  label         = var.vpc_label
  region        = var.vpc_region
  description   = var.vpc_description
}

# Subnet Creation
resource "linode_vpc_subnet" "red5subnet" {
  vpc_id       = linode_vpc.red5vpc.id
  label        = var.subnet_label
  ipv4         = var.subnet_ipv4
}

# Stream Manager Firewall
resource "linode_firewall" "sm_firewall" {
  label = var.sm_firewall_label

  dynamic "inbound" {
    for_each = var.sm_firewall_inbound_rules
    content {
      label    = inbound.value.label
      action   = inbound.value.action
      protocol = inbound.value.protocol
      ports    = inbound.value.ports
      ipv4     = inbound.value.ipv4
      ipv6     = inbound.value.ipv6
    }
  }

  inbound_policy  = "ACCEPT"
  outbound_policy = "ACCEPT"
  linodes         =  concat(
    linode_instance.standalone_instance[*].id,
    linode_instance.red5pro_sm[*].id
    )
}

# Node Firewall
resource "linode_firewall" "node_firewall" {
  label = var.node_firewall_label

  dynamic "inbound" {
    for_each = var.node_firewall_inbound_rules
    content {
      label    = inbound.value.label
      action   = inbound.value.action
      protocol = inbound.value.protocol
      ports    = inbound.value.ports
      ipv4     = inbound.value.ipv4
      ipv6     = inbound.value.ipv6
    }
  }

  inbound_policy  = "ACCEPT"
  outbound_policy = "ACCEPT"
    linodes         =  concat(
    linode_instance.red5pro_node[*].id
    )
}

# Kafka Firewall
resource "linode_firewall" "kafka_firewall" {
  label = var.kafka_firewall_label

  # Define the inbound firewall rules for Kafka instances
  dynamic "inbound" {
    for_each = var.network_security_group_kafka_ingress
    content {
      label      = inbound.value.label
      action     = inbound.value.action  
      protocol   = inbound.value.protocol
      ports      = inbound.value.ports  # Directly use the ports from the variable (assuming port_min and port_max are not needed)
      ipv4       = inbound.value.ipv4   # Use the ipv4 CIDR blocks directly from the variable
      ipv6       = inbound.value.ipv6   # Use the ipv6 CIDR blocks directly from the variable
    }
  }

  inbound_policy  = "ACCEPT"
  outbound_policy = "ACCEPT"
  linodes         = concat(
    linode_instance.red5pro_kafka[*].id,
  )
}