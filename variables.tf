# VPC Configuration
variable "vpc_label" {
  description = "The label for the VPC"
  type        = string
  default     = "red5-vpc"
}

variable "vpc_region" {
  description = "The region for the VPC"
  type        = string
  default     = "us-lax"
}

variable "vpc_description" {
  description = "The description for the VPC"
  type        = string
  default     = "Red5Pro Test VPC"
}

# Subnet Configuration
variable "subnet_label" {
  description = "The label for the VPC subnet"
  type        = string
  default     = "red5pro-autoscaling-subnet"
}

variable "subnet_ipv4" {
  description = "The IPv4 CIDR block for the subnet"
  type        = string
  default     = "10.0.0.0/24"
}

# Firewall Configuration for Stream Manager - Standalone
variable "sm_standalone_firewall_label" {
  description = "The label for the stream manager standalone firewall"
  type        = string
  default     = "red5pro-autoscaling-sm-sg"
}

variable "sm_standalone_firewall_inbound_rules" {
  description = "The inbound firewall rules for stream manager"
  type = list(object({
    label    = string
    action   = string
    protocol = string
    ports    = string
    ipv4     = list(string)
    ipv6     = list(string)
  }))
  default = [
    {
      label    = "allow-http"
      action   = "ACCEPT"
      protocol = "TCP"
      ports    = "80"
      ipv4     = ["0.0.0.0/0"]
      ipv6     = ["::/0"]
    },
    {
      label    = "allow-https"
      action   = "ACCEPT"
      protocol = "TCP"
      ports    = "443"
      ipv4     = ["0.0.0.0/0"]
      ipv6     = ["::/0"]
    },
    {
      label    = "kafka-rule"
      action   = "ACCEPT"
      protocol = "TCP"
      ports    = "9092"
      ipv4     = ["0.0.0.0/0"]
      ipv6     = ["::/0"]
    }
  ]
}

# Firewall Configuration for Stream Manager
variable "sm_firewall_label" {
  description = "The label for the stream manager firewall"
  type        = string
  default     = "red5pro-autoscaling-sm-sg"
}

variable "sm_firewall_inbound_rules" {
  description = "The inbound firewall rules for stream manager"
  type = list(object({
    label    = string
    action   = string
    protocol = string
    ports    = string
    ipv4     = list(string)
    ipv6     = list(string)
  }))
  default = [
    {
      label    = "allow-http"
      action   = "ACCEPT"
      protocol = "TCP"
      ports    = "80"
      ipv4     = ["0.0.0.0/0"]
      ipv6     = ["::/0"]
    },
    {
      label    = "allow-https"
      action   = "ACCEPT"
      protocol = "TCP"
      ports    = "443"
      ipv4     = ["0.0.0.0/0"]
      ipv6     = ["::/0"]
    },
    {
      label    = "kafka-rule"
      action   = "ACCEPT"
      protocol = "TCP"
      ports    = "9092"
      ipv4     = ["0.0.0.0/0"]
      ipv6     = ["::/0"]
    }
  ]
}

# Firewall Configuration for Node Instances
variable "node_firewall_label" {
  description = "The label for the node firewall"
  type        = string
  default     = "red5pro-autoscale-node-sg"
}

variable "node_firewall_inbound_rules" {
  description = "The inbound firewall rules for node instances"
  type = list(object({
    label    = string
    action   = string
    protocol = string
    ports    = string
    ipv4     = list(string)
    ipv6     = list(string)
  }))
  default = [
    {
      label    = "http"
      action   = "ACCEPT"
      protocol = "TCP"
      ports    = "80"
      ipv4     = ["0.0.0.0/0"]
      ipv6     = ["::/0"]
    },
    {
      label    = "rtmp"
      action   = "ACCEPT"
      protocol = "TCP"
      ports    = "1935"
      ipv4     = ["0.0.0.0/0"]
      ipv6     = ["::/0"]
    },
    {
      label    = "udp"
      action   = "ACCEPT"
      protocol = "UDP"
      ports    = "40000-65535"
      ipv4     = ["0.0.0.0/0"]
      ipv6     = ["::/0"]
    },
    {
      label    = "kafka-rule-to-check"
      action   = "ACCEPT"
      protocol = "TCP"
      ports    = "9092"
      ipv4     = ["0.0.0.0/0"]
      ipv6     = ["::/0"]
    }
  ]
}

variable "network_security_group_kafka_ingress" {
  description = "List of ports for security group ingress rules for Kafka standalone instance"
  type = list(object({
    label    = string
    action   = string
    protocol = string
    ports    = string
    ipv4     = list(string)
    ipv6     = list(string)
  }))
  default = [
    {
      label    = "kafka-ssh"
      action   = "ACCEPT"
      protocol = "TCP"
      ports    = "22"
      ipv4     = ["0.0.0.0/0"]
      ipv6     = ["::/0"]
    },
    {
      label    = "kafka-rule"
      action   = "ACCEPT"
      protocol = "TCP"
      ports    = "9092"
      ipv4     = ["10.0.0.0/16"]
      ipv6     = ["::/0"]
    }   
  ]
}

# Linode Instances for Firewalls
variable "sm_firewall_linodes" {
  description = "List of linode instances to attach to the stream manager firewall"
  type        = list(string)
  default     = []
}

variable "node_firewall_linodes" {
  description = "List of linode instances to attach to the node firewall"
  type        = list(string)
  default     = []
}

variable "kafka_firewall_label"{
  type        = string
  default     = "kafka-firewall"
}

# Red5 Pro common configurations
variable "name" {
  description = "Name to be used on all the resources as identifier"
  type        = string
  default     = ""
  validation {
    condition     = length(var.name) > 0
    error_message = "The name value must be a valid! Example: example-name"
  }
}

variable "type" {
  description = "Type of deployment: standalone, cluster, autoscale"
  type        = string
  default     = "standalone"
  validation {
    condition     = var.type == "standalone" || var.type == "cluster" || var.type == "autoscale"
    error_message = "The type value must be a valid! Example: autoscale, cluster or autoscale"
  }
}

variable "path_to_red5pro_build" {
  description = "Path to the Red5 Pro build zip file, absolute path or relative path. https://account.red5.net/downloads. Example: /home/ubuntu/terraform-oci-red5pro/red5pro-server-0.0.0.b0-release.zip"
  type        = string
  default     = ""
  validation {
    condition     = fileexists(var.path_to_red5pro_build) == true
    error_message = "The path_to_red5pro_build value must be a valid! Example: /home/ubuntu/terraform-oci-red5pro/red5pro-server-0.0.0.b0-release.zip"
  }
}

variable "red5pro_license_key" {
  description = "Red5 Pro license key (https://www.red5.net/docs/installation/installation/license-key/)"
  type        = string
  default     = ""
}

variable "red5pro_api_enable" {
  description = "Red5 Pro Server API enable/disable (https://www.red5.net/docs/development/api/overview/)"
  type        = bool
  default     = true
}

variable "red5pro_api_key" {
  description = "Red5 Pro Standalone server API key"
  type        = string
  default     = ""
}

variable "ubuntu_version" {
  description = "Ubuntu version"
  type        = string
  default     = "22.04"
  validation {
    condition     = var.ubuntu_version == "22.04"
    error_message = "Please specify the correct ubuntu version, currently only 22.04 is supported"
  }
}

variable "linode_api_token" {
    type    = string
    default = ""
}

variable "sshkey" {
  type    = string
  default = ""
}

# SSH key configuration
variable "ssh_key_use_existing" {
  description = "SSH key pair configuration, true = use existing, false = create new"
  type        = bool
  default     = false
}
variable "ssh_key_existing_private_key_path" {
  description = "SSH private key path existing"
  type        = string
  default     = ""
}
variable "ssh_key_existing_public_key_path" {
  description = "SSH public key path existing"
  type        = string
  default     = ""
}

################################################################################################
# Red5 Pro Standalone server configuration
################################################################################################
variable "standalone_red5pro_instance_type" {
  description = "Red5 Pro Standalone server instance type"
  type        = string
  default     = "g6-dedicated-4"
}
variable "standalone_red5pro_region" {
  description = "Red5 Pro Standalone server instance type"
  type        = string
  default     = "us-lax"
}
variable "standalone_red5pro_inspector_enable" {
  description = "Red5 Pro Standalone server Inspector enable/disable (https://www.red5.net/docs/troubleshooting/inspector/overview/)"
  type        = bool
  default     = false
}
variable "standalone_red5pro_restreamer_enable" {
  description = "Red5 Pro Standalone server Restreamer enable/disable (https://www.red5.net/docs/special/restreamer/overview/)"
  type        = bool
  default     = false
}
variable "standalone_red5pro_socialpusher_enable" {
  description = "Red5 Pro Standalone server SocialPusher enable/disable (https://www.red5.net/docs/special/social-media-plugin/rest-api/)"
  type        = bool
  default     = false
}
variable "standalone_red5pro_suppressor_enable" {
  description = "Red5 Pro Standalone server Suppressor enable"
  type        = bool
  default     = false
}
variable "standalone_red5pro_hls_enable" {
  description = "Red5 Pro Standalone server HLS enable/disable (https://www.red5.net/docs/protocols/hls-plugin/overview/)"
  type        = bool
  default     = false
}
variable "standalone_red5pro_round_trip_auth_enable" {
  description = "Round trip authentication on the red5pro server enable/disable - Auth server should be deployed separately (https://www.red5.net/docs/special/round-trip-auth/overview/)"
  type        = bool
  default     = false
}
variable "standalone_red5pro_round_trip_auth_host" {
  description = "Round trip authentication server host"
  type        = string
  default     = ""
}
variable "standalone_red5pro_round_trip_auth_port" {
  description = "Round trip authentication server port"
  type        = number
  default     = 3000
}
variable "standalone_red5pro_round_trip_auth_protocol" {
  description = "Round trip authentication server protocol"
  type        = string
  default     = "http"
}
variable "standalone_red5pro_round_trip_auth_endpoint_validate" {
  description = "Round trip authentication server endpoint for validate"
  type        = string
  default     = "/validateCredentials"
}
variable "standalone_red5pro_round_trip_auth_endpoint_invalidate" {
  description = "Round trip authentication server endpoint for invalidate"
  type        = string
  default     = "/invalidateCredentials"
}

# HTTPS/SSL variables for standalone/cluster/autoscale
variable "https_ssl_certificate" {
  description = "Enable SSL (HTTPS) on the Standalone Red5 Pro server,  Stream Manager 2.0 server or Stream Manager 2.0 Load Balancer"
  type        = string
  default     = "none"
  validation {
    condition     = var.https_ssl_certificate == "none" || var.https_ssl_certificate == "letsencrypt" || var.https_ssl_certificate == "imported"
    error_message = "The https_ssl_certificate value must be a valid! Example: none, letsencrypt, imported"
  }
}
variable "https_ssl_certificate_domain_name" {
  description = "Domain name for SSL certificate (letsencrypt/imported)"
  type        = string
  default     = ""
}
variable "https_ssl_certificate_email" {
  description = "Email for SSL certificate (letsencrypt)"
  type        = string
  default     = ""
}
variable "https_ssl_certificate_cert_path" {
  description = "Path to SSL certificate (imported)"
  type        = string
  default     = ""
}
variable "https_ssl_certificate_key_path" {
  description = "Path to SSL key (imported)"
  type        = string
  default     = ""
}

# Red5 Pro Cluster Configuration
variable "stream_manager_instance_type" {
  description = "Red5 Pro Stream Manager 2.0 instance type"
  type        = string
  default     = "g6-dedicated-4"
}

variable "stream_manager_red5pro_region" {
  description = "Red5 Pro Stream Manager 2.0 instance type"
  type        = string
  default     = "us-lax"
}

variable "stream_manager_auth_user" {
  description = "value to set the user name for Stream Manager 2.0 authentication"
  type        = string
  default     = ""
}
variable "stream_manager_auth_password" {
  description = "value to set the user password for Stream Manager 2.0 authentication"
  type        = string
  default     = ""
}
variable "stream_manager_autoscaling_desired_capacity" {
  description = "value to set the desired capacity for Stream Manager 2.0 autoscaling"
  type        = number
  default     = 1
}
variable "stream_manager_autoscaling_minimum_capacity" {
  description = "value to set the minimum capacity for Stream Manager 2.0 autoscaling"
  type        = number
  default     = 1
}
variable "stream_manager_autoscaling_maximum_capacity" {
  description = "value to set the maximum capacity for Stream Manager 2.0 autoscaling"
  type        = number
  default     = 2
}

variable "kafka_standalone_instance_create" {
  description = "Create a new Kafka standalone instance true/false"
  type        = bool
  default     = false
}
variable "kafka_standalone_instance_type" {
  description = "Kafka standalone instance type"
  type        = string
  default     = "g6-dedicated-4"
}

variable "kafka_standalone_instance_arhive_url" {
  description = "Kafka standalone instance - archive URL"
  type        = string
  default     = "https://downloads.apache.org/kafka/3.8.0/kafka_2.13-3.8.0.tgz"
}

variable "load_balancer_reserved_ip_use_existing" {
  description = "Use existing Reserved IP for Load Balancer. true = use existing, false = create new"
  type        = bool
  default     = false
}
variable "load_balancer_reserved_ip_existing" {
  description = "Existing Reserved IP for Load Balancer"
  type        = string
  default     = ""
}

variable "kafka_red5pro_region" {
  description = "Region for Kafka Instance"
  type        = string
  default     = "us-lax"
}

variable "kafka_instance_type" {
  description = "Region for Kafka Instance"
  type        = string
  default     = "g6-dedicated-4"
}
variable "linode_root_user_password" {
  description = "Root user password"
  type        = string
  default     = "red5pro@1234567899"
}

variable "R5AS_CLOUD_PLATFORM_TYPE" {
  description = "The cloud platform type"
  type        = string
  default     = "LINODE"
}

# Red5 Pro Node image configuration
variable "node_image_create" {
  description = "Create new Node image true/false."
  type        = bool
  default     = false
}
variable "node_image_instance_type" {
  description = "Node image - instance type"
  type        = string
  default     = "g6-dedicated-2"
}
variable "node_image_region" {
  description = "Node region"
  type        = string
  default     = "us-lax"
}

# Extra configuration for Red5 Pro autoscaling nodes
variable "node_config_webhooks" {
  description = "Webhooks configuration - (Optional) https://www.red5.net/docs/special/webhooks/overview/"
  type = object({
    enable           = bool
    target_nodes     = list(string)
    webhook_endpoint = string
  })
  default = {
    enable           = false
    target_nodes     = []
    webhook_endpoint = ""
  }
}
variable "node_config_round_trip_auth" {
  description = "Round trip authentication configuration - (Optional) https://www.red5.net/docs/special/authplugin/simple-auth/"
  type = object({
    enable                   = bool
    target_nodes             = list(string)
    auth_host                = string
    auth_port                = number
    auth_protocol            = string
    auth_endpoint_validate   = string
    auth_endpoint_invalidate = string
  })
  default = {
    enable                   = false
    target_nodes             = []
    auth_host                = ""
    auth_port                = 443
    auth_protocol            = "https://"
    auth_endpoint_validate   = "/validateCredentials"
    auth_endpoint_invalidate = "/invalidateCredentials"
  }
}

variable "node_config_social_pusher" {
  description = "Social Pusher configuration - (Optional) https://www.red5.net/docs/development/social-media-plugin/rest-api/"
  type = object({
    enable       = bool
    target_nodes = list(string)
  })
  default = {
    enable       = false
    target_nodes = []
  }
}
variable "node_config_restreamer" {
  description = "Restreamer configuration - (Optional) https://www.red5.net/docs/special/restreamer/overview/"
  type = object({
    enable               = bool
    target_nodes         = list(string)
    restreamer_tsingest  = bool
    restreamer_ipcam     = bool
    restreamer_whip      = bool
    restreamer_srtingest = bool
  })
  default = {
    enable               = false
    target_nodes         = []
    restreamer_tsingest  = false
    restreamer_ipcam     = false
    restreamer_whip      = false
    restreamer_srtingest = false
  }
}

# Red5 Pro autoscaling Node group - (Optional) 
variable "node_group_create" {
  description = "Create new node group. Linux or Mac OS only."
  type        = bool
  default     = false
}
variable "node_group_name" {
  description = "Node group name"
  type        = string
  default     = "test-node-group"
}
variable "node_group_origins_min" {
  description = "Number of minimum Origins"
  type        = number
  default     = 1
}
variable "node_group_origins_max" {
  description = "Number of maximum Origins"
  type        = number
  default     = 20
}
variable "node_group_origins_instance_type" {
  description = "Instance type for Origins"
  type        = string
  default     = "g6-dedicated-2"
}

variable "node_group_edges_min" {
  description = "Number of minimum Edges"
  type        = number
  default     = 1
}
variable "node_group_edges_max" {
  description = "Number of maximum Edges"
  type        = number
  default     = 20
}
variable "node_group_edges_instance_type" {
  description = "Instance type for Edges"
  type        = string
  default     = "g6-dedicated-2"
}
variable "node_group_transcoders_min" {
  description = "Number of minimum Transcoders"
  type        = number
  default     = 1
}
variable "node_group_transcoders_max" {
  description = "Number of maximum Transcoders"
  type        = number
  default     = 20
}
variable "node_group_transcoders_instance_type" {
  description = "Instance type for Transcoders"
  type        = string
  default     = "g6-dedicated-2"
}
variable "node_group_relays_min" {
  description = "Number of minimum Relays"
  type        = number
  default     = 1
}
variable "node_group_relays_max" {
  description = "Number of maximum Relays"
  type        = number
  default     = 20
}
variable "node_group_relays_instance_type" {
  description = "Instance type for Relays"
  type        = string
  default     = "g6-dedicated-2"
}
variable "node_group_origins_volume_size" {
  description = "Volume size in GB for Origins. Minimum 50GB"
  type        = number
  default     = 50
  validation {
    condition     = var.node_group_origins_volume_size >= 50
    error_message = "The node_group_origins_volume_size value must be a valid! Minimum 50"
  }
}
variable "node_group_edges_volume_size" {
  description = "Volume size in GB for Edges. Minimum 50GB"
  type        = number
  default     = 50
  validation {
    condition     = var.node_group_edges_volume_size >= 50
    error_message = "The node_group_edges_volume_size value must be a valid! Minimum 50"
  }
}
variable "node_group_transcoders_volume_size" {
  description = "Volume size in GB for Transcoders. Minimum 50GB"
  type        = number
  default     = 50
  validation {
    condition     = var.node_group_transcoders_volume_size >= 50
    error_message = "The node_group_transcoders_volume_size value must be a valid! Minimum 50"
  }
}
variable "node_group_relays_volume_size" {
  description = "Volume size in GB for Relays. Minimum 50GB"
  type        = number
  default     = 50
  validation {
    condition     = var.node_group_relays_volume_size >= 50
    error_message = "The node_group_relays_volume_size value must be a valid! Minimum 50"
  }
}