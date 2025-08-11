# VPC Creation
resource "linode_vpc" "red5_vpc" {
  count         = var.vpc_use_existing ? 0 : 1
  label         = "${var.name}-vpc"
  region        = var.linode_region
  description   = "${var.name} VPC"
}

# Subnet Creation
resource "linode_vpc_subnet" "red5_subnet" {
  count        = var.vpc_use_existing ? 0 : 1
  vpc_id       = linode_vpc.red5_vpc[0].id
  label        = "${var.name}-subnet"
  ipv4         = var.subnet_cidr
}

data "linode_vpcs" "existing_vpc" {
  count = var.vpc_use_existing ? 1 : 0
  filter {
      name = "label"
      match_by = "exact"
      values = ["${var.vpc_name_existing}"]
  }
  lifecycle {
    postcondition {
      condition = self.vpcs[0].region == var.linode_region
      error_message = "ERROR! VPC name ${var.vpc_name_existing} does not exist in region ${var.linode_region}"
    }
  }
}

data "linode_vpc_subnets" "existing_subnet" {
  count  = var.vpc_use_existing ? 1 : 0
  vpc_id = data.linode_vpcs.existing_vpc[0].vpcs[0].id
  filter {
    name = "label"
    match_by = "exact"
    values = ["${var.subnet_name_existing}"]
  }
}

# Firewall - Red5Pro Standalone
resource "linode_firewall" "standalone_firewall" {
  count = local.standalone ? 1 : 0
  label = "${var.name}-standalone-fw"

  dynamic "inbound" {
    for_each = var.standalone_firewall_inbound_rules
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
  label   = "${var.name}-sm-fw"

  dynamic "inbound" {
    for_each = var.sm_inbound_rules
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
  label   = "${var.name}-node-fw"

  dynamic "inbound" {
    for_each = var.node_inbound_rules
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
  label = "${var.name}-kafka-fw"

  dynamic "inbound" {
    for_each = var.kafka_inbound_rules
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
  label = "${var.name}-lb-fw"

  dynamic "inbound" {
    for_each = var.lb_ingbound_rules
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