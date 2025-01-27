# Terraform Module for Deploying Red5 Pro in Linode Cloud - Stream Manager 2.0

[Red5 Pro](https://www.red5.net/) is a real-time video streaming server plaform known for its low-latency streaming capabilities, making it ideal for interactive applications like online gaming, streaming events and video conferencing etc.

This is a reusable Terraform module that provisions infrastructure on [Linode Cloud](https://www.linode.com/).

## Preparation

### Install Terraform

- Visit the [Terraform download page](https://developer.hashicorp.com/terraform/downloads) and ensure you get version 1.7.5 or higher.
- Download the suitable version for your operating system.
- Extract the compressed file and copy the Terraform binary to a location within your system's PATH.
- Configure PATH for **Linux/macOS**:
  - Open a terminal and type the following command:

    ```sh
    sudo mv /path/to/terraform /usr/local/bin
    ```

- Configure PATH for **Windows**:
  - Click 'Start', search for 'Control Panel', and open it.
  - Navigate to `System > Advanced System Settings > Environment Variables`.
  - Under System variables, find 'PATH' and click 'Edit'.
  - Click 'New' and paste the directory location where you extracted the terraform.exe file.
  - Confirm changes by clicking 'OK' and close all open windows.
  - Open a new terminal and verify that Terraform has been successfully installed.

  ```sh
  terraform --version
  ```

### Install jq

- Install **jq** (Linux or Mac OS only) [Download](https://jqlang.github.io/jq/download/)
  - Linux: `apt install jq`
  - MacOS: `brew install jq`
  > It is used in bash scripts to create/delete Stream Manager node group using API

### Red5 Pro artifacts

- Download Red5 Pro server build in your [Red5 Pro Account](https://account.red5.net/downloads). Example: `red5pro-server-0.0.0.b0-release.zip`
- Get Red5 Pro License key in your [Red5 Pro Account](https://account.red5.net/downloads). Example: `1111-2222-3333-4444`

### Install Linode Cloud CLI

- [Installing the CLI](https://techdocs.akamai.com/cloud-computing/docs/install-and-configure-the-cli)

### Prepare Linode Cloud account

- Create LINODE API TOKEN for authentication
- Obtain the necessary credentials and information:
  - LINODE API TOKEN
  - SSH Key Name (if using existing)

## This module supports three variants of Red5 Pro deployments

- **standalone** - Standalone Red5 Pro server
- **cluster** - Stream Manager 2.0 cluster with autoscaling nodes
- **autoscale** - Autoscaling Stream Managers 2.0 with autoscaling nodes

### Standalone Red5 Pro server (standalone) - [Example](https://github.com/red5pro/terraform-linode-red5pro/tree/master/examples/standalone)

In the following example, Terraform module will automates the infrastructure provisioning of the [Red5 Pro standalone server](https://www.red5.net/docs/installation/).

## Terraform Deployed Resources (standalone)

- VPC
- Public subnet
- Firewall
- Firewall for Standalone Red5 Pro server
- SSH key pair (use existing or create a new one)
- Standalone Red5 Pro server instance
- SSL certificate for Standalone Red5 Pro server instance. Options:
  - `none` - Red5 Pro server without HTTPS and SSL certificate. Only HTTP on port `5080`
  - `letsencrypt` - Red5 Pro server with HTTPS and SSL certificate obtained by Let's Encrypt. HTTP on port `5080`, HTTPS on port `443`
  - `imported` - Red5 Pro server with HTTPS and imported SSL certificate. HTTP on port `5080`, HTTPS on port `443`

## Example main.tf (standalone)

```hcl
terraform {
  required_version = ">= 1.7.5"
  
  required_providers {
    linode = {
      source  = "linode/linode"
      version = ">= 2.0"  # You can adjust the version based on the latest
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
  source = "../../" 
  type                  = "standalone"                            # Deployment type: standalone, cluster, autoscale
  name                  = "red5pro-standalone"                    # Name to be used on all the resources as identifier
  linode_region         = "us-lax"                                # Deployment region
  ubuntu_version        = "22.04"                                 # Ubuntu version for Red5 Pro servers
  path_to_red5pro_build = "./red5pro-server-0.0.0.b0-release.zip" # Absolute path or relative path to Red5 Pro server ZIP file

  # SSH key configuration
  ssh_key_use_existing               = false                                                   # true - use existing SSH key, false - create new SSH key
  ssh_key_name_existing              = "example-key"                                           # SSH key name existing in LINODE
  ssh_key_existing_private_key_path  = "/PATH/TO/SSH/PRIVATE/KEY/example_private_key.pem"      # Path to existing SSH private key

  # Red5 Pro general configuration
  red5pro_license_key = "1111-2222-3333-4444" # Red5 Pro license key (https://account.red5.net/login)
  red5pro_api_enable  = true                  # true - enable Red5 Pro server API, false - disable Red5 Pro server API (https://www.red5.net/docs/development/api/overview/)
  red5pro_api_key     = "example_key"         # Red5 Pro server API key (https://www.red5.net/docs/development/api/overview/)

  standalone_red5pro_instance_type   = "g6-dedicated-4"

  # Standalone Red5 Pro server configuration
  standalone_red5pro_inspector_enable                    = false                         # true - enable Red5 Pro server inspector, false - disable Red5 Pro server inspector (https://www.red5.net/docs/troubleshooting/inspector/overview/)
  standalone_red5pro_restreamer_enable                   = false                         # true - enable Red5 Pro server restreamer, false - disable Red5 Pro server restreamer (https://www.red5.net/docs/special/restreamer/overview/)
  standalone_red5pro_socialpusher_enable                 = false                         # true - enable Red5 Pro server socialpusher, false - disable Red5 Pro server socialpusher (https://www.red5.net/docs/special/social-media-plugin/overview/)
  standalone_red5pro_suppressor_enable                   = false                         # true - enable Red5 Pro server suppressor, false - disable Red5 Pro server suppressor
  standalone_red5pro_hls_enable                          = false                         # true - enable Red5 Pro server HLS, false - disable Red5 Pro server HLS (https://www.red5.net/docs/protocols/hls-plugin/hls-vod/)
  standalone_red5pro_round_trip_auth_enable              = false                         # true - enable Red5 Pro server round trip authentication, false - disable Red5 Pro server round trip authentication (https://www.red5.net/docs/special/round-trip-auth/overview/)
  standalone_red5pro_round_trip_auth_host                = "round-trip-auth.example.com" # Round trip authentication server host
  standalone_red5pro_round_trip_auth_port                = 3000                          # Round trip authentication server port
  standalone_red5pro_round_trip_auth_protocol            = "http"                        # Round trip authentication server protocol
  standalone_red5pro_round_trip_auth_endpoint_validate   = "/validateCredentials"        # Round trip authentication server endpoint for validate
  standalone_red5pro_round_trip_auth_endpoint_invalidate = "/invalidateCredentials"      # Round trip authentication server endpoint for invalidate

  # Standalone Red5 Pro server HTTPS (SSL) certificate configuration
   https_ssl_certificate = "none" # none - do not use HTTPS/SSL certificate, letsencrypt - create new Let's Encrypt HTTPS/SSL certificate, imported - use existing HTTPS/SSL certificate

  # Example of Let's Encrypt HTTPS/SSL certificate configuration - please uncomment and provide your domain name and email
  # https_ssl_certificate = "letsencrypt"
  # https_ssl_certificate_domain_name = "red5pro.example.com"
  # https_ssl_certificate_email = "email@example.com"

  # Example of imported HTTPS/SSL certificate configuration - please uncomment and provide your domain name, certificate and key paths
  # https_ssl_certificate             = "imported"
  # https_ssl_certificate_domain_name = "red5pro.example.com"
  # https_ssl_certificate_cert_path   = "/PATH/TO/SSL/CERT/fullchain.pem"
  # https_ssl_certificate_key_path    = "/PATH/TO/SSL/KEY/privkey.pem"
}

output "module_output" {
  value = module.red5pro
}
```

# Stream Manager 2.0 cluster with autoscaling nodes (cluster) - [Example](https://github.com/red5pro/terraform-linode-red5pro/tree/master/examples/cluster)

In the following example, Terraform module will automates the infrastructure provisioning of the Stream Manager 2.0 cluster with Red5 Pro (SM2.0) Autoscaling node group (origins, edges, transcoders, relays)

## Terraform Deployed Resources (cluster)

- VPC
- Public subnet
- Firewall
- Firewall for Stream Manager 2.0
- Firewall for Kafka Instance
- Firewall for Red5 Pro (SM2.0) Autoscaling nodes
- SSH key pair (use existing or create a new one)
- Standalone Kafka instance (optional)
- Stream Manager 2.0 instance. Optionally include a Kafka server on the same instance.
- SSL certificate for Stream Manager 2.0 instance. Options:
  - `none` - Stream Manager 2.0 without HTTPS and SSL certificate. Only HTTP on port `80`
  - `letsencrypt` - Stream Manager 2.0 with HTTPS and SSL certificate obtained by Let's Encrypt. HTTP on port `80`, HTTPS on port `443`
  - `imported` - Stream Manager 2.0 with HTTPS and imported SSL certificate. HTTP on port `80`, HTTPS on port `443`
- Red5 Pro (SM2.0) node instance image (origins, edges, transcoders, relays)
- Red5 Pro (SM2.0) Autoscaling node group (origins, edges, transcoders, relays)

## Example main.tf (cluster) 

```hcl
terraform {
  required_version = ">= 1.7.5"
  
  required_providers {
    linode = {
      source  = "linode/linode"
      version = ">= 2.0"  # You can adjust the version based on the latest
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
  kafka_standalone_instance_create      = true                  # true - create new Kafka standalone instance, false - not create new Kafka standalone instance and use Kafka on the Stream Manager 2.0 instance
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
```


# Autoscaling Stream Managers 2.0 with autoscaling nodes (autoscale) - [Example](https://github.com/red5pro/terraform-linode-red5pro/tree/master/examples/autoscale)

In the following example, Terraform module will automates the infrastructure provisioning of the Autoscale Stream Managers 2.0 with Red5 Pro (SM2.0) Autoscaling node group (origins, edges, transcoders, relays)

## Terraform Deployed Resources (autoscale)

- VPC
- Public subnet
- Firewall
- Firewall for Stream Manager 2.0
- Firewall for Kafka Instance
- Firewall for Red5 Pro (SM2.0) Autoscaling nodes
- SSH key pair (use existing or create a new one)
- Standalone Kafka instance
- Stream Manager 2.0 instance image
- Stream Manager 2.0 instance based on node count
- Node Balancer Configuration
- Attaching Node Balancer for Stream Manager 2.0 instances
- SSL certificate for Noad Balancer. Options:
  - `none` - Load Balancer without HTTPS and SSL certificate. Only HTTP on port `80`
  - `imported` - Load Balancer with HTTPS and imported SSL certificate. HTTP on port `80`, HTTPS on port `443`
- Red5 Pro (SM2.0) node instance image (origins, edges, transcoders, relays)
- Red5 Pro (SM2.0) Autoscaling node group (origins, edges, transcoders, relays)

## Example main.tf (autoscale)

```hcl
terraform {
  required_version = ">= 1.7.5"
  
  required_providers {
    linode = {
      source  = "linode/linode"
      version = ">= 2.0"  # You can adjust the version based on the latest
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
  type                  = "autoscale"                                         # Deployment type: standalone, cluster, autoscale
  name                  = "red5pro-auto"                                      # Name to be used on all the resources as identifier
  linode_region         = "us-lax"                                            # Deployment region
  ubuntu_version        = "22.04"                                             # Ubuntu version for Red5 Pro servers  
  path_to_red5pro_build = "./red5pro-server-0.0.0.b0-release.zip"             # Absolute path or relative path to Red5 Pro server ZIP file
  linode_api_token      = "<linode token>"                                    # Linode API token from Linode Cloud  

  # SSH key configuration
  ssh_key_use_existing               = false                                              # true - use existing SSH key, false - create new SSH key
  ssh_key_name_existing              = "example-key"                                      # SSH key name existing in LINODE
  ssh_key_existing_private_key_path  = "PATH/TO/SSH/PRIVATE/KEY/example_private_key.pem"  # Path to existing SSH private key

  # Red5 Pro general configuration
  red5pro_license_key = "1111-2222-3333-4444" # Red5 Pro license key (https://account.red5.net/login)
  red5pro_api_enable  = true                  # true - enable Red5 Pro server API, false - disable Red5 Pro server API (https://www.red5.net/docs/development/api/overview/)
  red5pro_api_key     = "example_key"         # Red5 Pro server API key (https://www.red5.net/docs/development/api/overview/)

  # Stream Manager 2.0 instance configuration
  stream_manager_instance_type                  = "g6-dedicated-4"      # Linode Instance type for Stream Manager
  stream_manager_auth_user                      = "example_user"        # Stream Manager 2.0 authentication user name
  stream_manager_auth_password                  = "example_password"    # Stream Manager 2.0 authentication passwordssword
  stream_manager_count                          = 1                     # Stream Manager 2.0 instance count

  # Kafka standalone instance configuration
  kafka_standalone_instance_create      = true                  # true - create new Kafka standalone instance, false - not create new Kafka standalone instance and use Kafka on the Stream Manager 2.0 instance
  kafka_standalone_instance_type        = "g6-dedicated-4"      # Linode Instance type for Kafka standalone instance

  # Stream Manager 2.0 Load Balancer HTTPS (SSL) certificate configuration
  https_ssl_certificate = "none"                                # none - do not use HTTPS/SSL certificate, imported - existing HTTPS/SSL certificate

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
```