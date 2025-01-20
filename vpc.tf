# VPC Creation
resource "linode_vpc" "red5vpc" {
  label         = var.vpc_label
  region        = var.linode_region
  description   = var.vpc_description
}

# Subnet Creation
resource "linode_vpc_subnet" "red5subnet" {
  vpc_id       = linode_vpc.red5vpc.id
  label        = var.subnet_label
  ipv4         = var.subnet_ipv4
}

# Stream Manager Firewall - Standalone
resource "linode_firewall" "standalone_firewall" {
  count = local.standalone ? 1 : 0
  label = var.sm_standalone_firewall_label

  dynamic "inbound" {
    for_each = var.sm_standalone_firewall_inbound_rules
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
  linodes         =  concat(linode_instance.standalone_instance[*].id)
}

# Stream Manager Firewall - Cluster or autoscale
resource "linode_firewall" "sm_firewall" {
  count   = local.cluster_or_autoscale ? 1 : 0
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
  linodes         =  concat(linode_instance.red5pro_sm[*].id)
}

# Node Firewall
resource "linode_firewall" "node_firewall" {
  count   = local.cluster_or_autoscale ? 1 : 0
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
  linodes         =  concat(linode_instance.red5pro_node[*].id)
}

# Kafka Firewall
resource "linode_firewall" "kafka_firewall" {
  count = var.kafka_standalone_instance_create ? 1 : 0
  label = var.kafka_firewall_label

  # Define the inbound firewall rules for Kafka instances
  dynamic "inbound" {
    for_each = var.network_security_group_kafka_ingress
    content {
      label      = inbound.value.label
      action     = inbound.value.action  
      protocol   = inbound.value.protocol
      ports      = inbound.value.ports 
      ipv4       = inbound.value.ipv4  
      ipv6       = inbound.value.ipv6  
    }
  }

  inbound_policy  = "ACCEPT"
  outbound_policy = "ACCEPT"
  linodes         = concat(linode_instance.red5pro_kafka[*].id)
}

# Node Balancer Firewall
resource "linode_firewall" "nodebalancer_firewall" {
  count = local.autoscale ? 1 : 0
  label = var.node_balancer_label

  # Define the inbound firewall rules for Kafka instances
  dynamic "inbound" {
    for_each = var.node_ingress
    content {
      label      = inbound.value.label
      action     = inbound.value.action  
      protocol   = inbound.value.protocol
      ports      = inbound.value.ports
      ipv4       = inbound.value.ipv4
      ipv6       = inbound.value.ipv6 
    }
  }

  inbound_policy  = "ACCEPT"
  outbound_policy = "ACCEPT"
  nodebalancers   = concat(linode_nodebalancer.red5pro_lb[*].id)
}