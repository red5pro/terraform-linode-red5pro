##############################################################################
# Example: Red5 Pro Stream Manager 2.0 Cluster Deployment
##############################################################################

terraform {
  required_version = ">= 1.7.5"
  
  required_providers {
    linode = {
      source  = "linode/linode"
      version = ">= 2.32.0"
    }
    random = {
      source = "hashicorp/random"
    }
  }
}

provider "linode" {
  token = "<linode token>"
}

module "red5pro" {
  source                = "../../"
  type                  = "cluster"                               # Deployment type: standalone, cluster, autoscale
  name                  = "red5pro-cluster"                       # Name to be used on all the resources as identifier
  linode_region         = "us-lax"                                # Deployment region
  ubuntu_version        = "22.04"                                 # Ubuntu version for Red5 Pro servers  
  path_to_red5pro_build = "./red5pro-server-0.0.0.b0-release.zip" # Absolute path or relative path to Red5 Pro server ZIP file
  linode_api_token      = "<linode token>"                        # Linode API token from Linode Cloud  

  # SSH key configuration
  ssh_key_use_existing               = false                                                # true - use existing SSH key, false - create new SSH key
  ssh_key_name_existing              = "example-key"                                        # SSH key name existing in LINODE
  ssh_key_existing_private_key_path  = "/PATH/TO/SSH/PRIVATE/KEY/example_private_key.pem"   # Path to existing SSH private key

  # Red5 Pro general configuration
  red5pro_license_key = "1111-2222-3333-4444" # Red5 Pro license key (https://account.red5.net/login)
  red5pro_api_enable  = true                  # true - enable Red5 Pro server API, false - disable Red5 Pro server API (https://www.red5.net/docs/development/api/overview/)
  red5pro_api_key     = "example_key"         # Red5 Pro server API key (https://www.red5.net/docs/development/api/overview/)

  # Stream Manager 2.0 instance configuration
  stream_manager_instance_type        = "g6-dedicated-4"      # Linode Instance type for Stream Manager
  stream_manager_auth_user            = "example_user"        # Stream Manager 2.0 authentication user name
  stream_manager_auth_password        = "example_password"    # Stream Manager 2.0 authentication password

  # Kafka standalone instance configuration - (Optional)
  kafka_standalone_instance_create      = false                  # true - create new Kafka standalone instance, false - not create new Kafka standalone instance and use Kafka on the Stream Manager 2.0 instance
  kafka_standalone_instance_type        = "g6-dedicated-4"      # Linode Instance type for Kafka standalone instance

  # Stream Manager 2.0 server HTTPS (SSL) certificate configuration
  https_ssl_certificate = "none" # none - do not use HTTPS/SSL certificate, letsencrypt - create new Let's Encrypt HTTPS/SSL certificate, imported - use existing HTTPS/SSL certificate

  # Example of Let's Encrypt HTTPS/SSL certificate configuration - please uncomment and provide your domain name and email
  # https_ssl_certificate             = "letsencrypt"
  # https_ssl_certificate_domain_name = "red5pro.example.com"
  # https_ssl_certificate_email       = "email@example.com"

  # Example of imported HTTPS/SSL certificate configuration - please uncomment and provide your domain name, certificate and key paths
  # https_ssl_certificate             = "imported"
  # https_ssl_certificate_domain_name = "red5pro.example.com"
  # https_ssl_certificate_cert_path   = "/PATH/TO/SSL/CERT/fullchain.pem"
  # https_ssl_certificate_key_path    = "/PATH/TO/SSL/KEY/privkey.pem"

  # Red5 Pro autoscaling Node image configuration
  node_image_create             = true                  # Default: true for Autoscaling and Cluster, true - create new Red5 Pro Node image, false - do not create new Red5 Pro Node image
  node_image_instance_type      = "g6-dedicated-4"      # Instance type for Red5 Pro Node image
  
  # Extra configuration for Red5 Pro autoscaling nodes
  # Webhooks configuration - (Optional) https://www.red5.net/docs/special/webhooks/overview/
  node_config_webhooks = {
    enable           = false,
    target_nodes     = ["origin", "edge", "transcoder"],
    webhook_endpoint = "https://test.webhook.app/api/v1/broadcast/webhook"
  }
  # Round trip authentication configuration - (Optional) https://www.red5.net/docs/special/authplugin/simple-auth/
  node_config_round_trip_auth = {
    enable                   = false,
    target_nodes             = ["origin", "edge", "transcoder"],
    auth_host                = "round-trip-auth.example.com",
    auth_port                = 443,
    auth_protocol            = "https://",
    auth_endpoint_validate   = "/validateCredentials",
    auth_endpoint_invalidate = "/invalidateCredentials"
  }
  # Restreamer configuration - (Optional) https://www.red5.net/docs/special/restreamer/overview/
  node_config_restreamer = {
    enable               = false,
    target_nodes         = ["origin", "transcoder"],
    restreamer_tsingest  = true,
    restreamer_ipcam     = true,
    restreamer_whip      = true,
    restreamer_srtingest = true
  }
  # Social Pusher configuration - (Optional) https://www.red5.net/docs/development/social-media-plugin/rest-api/
  node_config_social_pusher = {
    enable       = false,
    target_nodes = ["origin", "edge", "transcoder"],
  }

  # Red5 Pro autoscaling Node group - (Optional)
  node_group_create                    = true                      # Linux or Mac OS only. true - create new Node group, false - not create new Node group
  node_group_origins_min               = 1                         # Number of minimum Origins
  node_group_origins_max               = 20                        # Number of maximum Origins
  node_group_origins_instance_type     = "g6-dedicated-2"          # Origins Linode Instance Type
  node_group_origins_volume_size       = 50                        # Volume size in GB for Origins
  node_group_edges_min                 = 1                         # Number of minimum Edges
  node_group_edges_max                 = 40                        # Number of maximum Edges
  node_group_edges_instance_type       = "g6-dedicated-2"          # Edges Linode Instance Type
  node_group_edges_volume_size         = 50                        # Volume size in GB for Edges
  node_group_transcoders_min           = 0                         # Number of minimum Transcoders
  node_group_transcoders_max           = 20                        # Number of maximum Transcoders
  node_group_transcoders_instance_type = "g6-dedicated-2"          # Transcoders Linode Instance Type
  node_group_transcoders_volume_size   = 50                        # Volume size in GB for Transcoders
  node_group_relays_min                = 0                         # Number of minimum Relays
  node_group_relays_max                = 20                        # Number of maximum Relays
  node_group_relays_instance_type      = "g6-dedicated-2"          # Relays Linode Instance Type
  node_group_relays_volume_size        = 50                        # Volume size in GB for Relays
}

output "module_output" {
  value = module.red5pro
}