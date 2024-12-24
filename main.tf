locals {
  standalone                    = var.type == "standalone" ? true : false
  cluster                       = var.type == "cluster" ? true : false
  autoscale                     = var.type == "autoscale" ? true : false
  cluster_or_autoscale          = local.cluster || local.autoscale ? true : false
  vcn_id                        = linode_vpc.red5vpc.id
  vcn_name                      = linode_vpc.red5vpc.label
  subnet_id                     = linode_vpc_subnet.red5subnet.id
  subnet_name                   = linode_vpc_subnet.red5subnet.label
  stream_manager_ip             = local.standalone ? [tolist(linode_instance.standalone_instance[0].ipv4)[0]] : (local.autoscale ? flatten([tolist(linode_instance.red5pro_sm)[0].ipv4]) : (local.cluster ? flatten([tolist(linode_instance.red5pro_sm)[0].ipv4]) : []))
  ssh_private_key_path          = var.ssh_key_use_existing ? var.ssh_key_existing_private_key_path : local_file.red5pro_ssh_key_pem[0].filename
  ssh_public_key_path           = var.ssh_key_use_existing ? var.ssh_key_existing_public_key_path : local_file.red5pro_ssh_key_pub[0].filename
  ssh_private_key               = var.ssh_key_use_existing ? file(var.ssh_key_existing_private_key_path) : tls_private_key.red5pro_ssh_key[0].private_key_pem
  ssh_public_key                = var.ssh_key_use_existing ? file(var.ssh_key_existing_public_key_path) : tls_private_key.red5pro_ssh_key[0].public_key_openssh
  kafka_standalone_instance     = local.autoscale ? true : local.cluster && var.kafka_standalone_instance_create ? true : false
  kafka_ip                      = local.cluster_or_autoscale ? local.kafka_standalone_instance ? flatten([tolist(linode_instance.red5pro_kafka)[0].private_ip_address]) : flatten([tolist(linode_instance.red5pro_sm)[0].private_ip_address]) : []
  kafka_on_sm_replicas          = local.kafka_standalone_instance ? 0 : 1
  kafka_ssl_keystore_key        = local.cluster_or_autoscale ? nonsensitive(join("\\\\n", split("\n", trimspace(tls_private_key.kafka_server_key[0].private_key_pem_pkcs8)))) : "null"
  kafka_ssl_truststore_cert     = local.cluster_or_autoscale ? nonsensitive(join("\\\\n", split("\n", tls_self_signed_cert.ca_cert[0].cert_pem))) : "null"
  kafka_ssl_keystore_cert_chain = local.cluster_or_autoscale ? nonsensitive(join("\\\\n", split("\n", tls_locally_signed_cert.kafka_server_cert[0].cert_pem))) : "null"
  stream_manager_ssl            = var.https_ssl_certificate
  stream_manager_standalone     = local.autoscale ? false : true
  stream_manager_url            = local.stream_manager_ssl != "none" ? "https://${local.stream_manager_ip[0]}" : "http://${local.stream_manager_ip[0]}"
}

################################################################################
# SSH KEY PAIR
################################################################################

# SSH key pair generation
resource "tls_private_key" "red5pro_ssh_key" {
  count     = var.ssh_key_use_existing ? 0 : 1
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Save SSH key pair files to local folder
resource "local_file" "red5pro_ssh_key_pem" {
  count           = var.ssh_key_use_existing ? 0 : 1
  filename        = "./ssh-key-${var.name}.pem"
  content         = tls_private_key.red5pro_ssh_key[0].private_key_pem
  file_permission = "0400"
}
resource "local_file" "red5pro_ssh_key_pub" {
  count    = var.ssh_key_use_existing ? 0 : 1
  filename = "./ssh-key-${var.name}.pub"
  content  = tls_private_key.red5pro_ssh_key[0].public_key_openssh
}


################################################################################
# Red5 Pro Standalone Server (Linode Instance)
################################################################################

resource "random_password" "ssl_password_red5pro_standalone" {
  count   = local.standalone && var.https_ssl_certificate != "none" ? 1 : 0
  length  = 16
  special = false
}

resource "linode_instance" "standalone_instance" {
    count           = local.standalone ? 1 : 0
    label           = "${var.name}-standalone-server"
    image           = "linode/ubuntu22.04"
    region          = var.standalone_red5pro_region
    type            = var.standalone_red5pro_instance_type
    authorized_keys = [
      replace(local.ssh_public_key, "\n", "")
    ]

    interface {
        purpose = "public"
    }

    interface {
        purpose   = "vpc"
        subnet_id = local.subnet_id
    }

    tags       = ["test"]

    provisioner "file" {
    source      = "${abspath(path.module)}/red5pro-installer"
    destination = "/home/ubuntu"

    connection {
      host        = tolist(self.ipv4)[0]
      type        = "ssh"
      user        = "root"
      private_key = local.ssh_private_key
    }
  }

    provisioner "file" {
    source      = var.path_to_red5pro_build
    destination = "/home/ubuntu/${basename(var.path_to_red5pro_build)}"

    connection {
      host        = tolist(self.ipv4)[0]
      type        = "ssh"
      user        = "root"
      private_key = local.ssh_private_key
    }
  }

    provisioner "remote-exec" {
    inline = [
      "sudo cloud-init status --wait",
      "export LICENSE_KEY='${var.red5pro_license_key}'",
      "export NODE_API_ENABLE='${var.red5pro_api_enable}'",
      "export NODE_API_KEY='${var.red5pro_api_key}'",
      "export NODE_INSPECTOR_ENABLE='${var.standalone_red5pro_inspector_enable}'",
      "export NODE_RESTREAMER_ENABLE='${var.standalone_red5pro_restreamer_enable}'",
      "export NODE_SOCIALPUSHER_ENABLE='${var.standalone_red5pro_socialpusher_enable}'",
      "export NODE_SUPPRESSOR_ENABLE='${var.standalone_red5pro_suppressor_enable}'",
      "export NODE_HLS_ENABLE='${var.standalone_red5pro_hls_enable}'",
      "export NODE_ROUND_TRIP_AUTH_ENABLE='${var.standalone_red5pro_round_trip_auth_enable}'",
      "export NODE_ROUND_TRIP_AUTH_HOST='${var.standalone_red5pro_round_trip_auth_host}'",
      "export NODE_ROUND_TRIP_AUTH_PORT='${var.standalone_red5pro_round_trip_auth_port}'",
      "export NODE_ROUND_TRIP_AUTH_PROTOCOL='${var.standalone_red5pro_round_trip_auth_protocol}'",
      "export NODE_ROUND_TRIP_AUTH_ENDPOINT_VALIDATE='${var.standalone_red5pro_round_trip_auth_endpoint_validate}'",
      "export NODE_ROUND_TRIP_AUTH_ENDPOINT_INVALIDATE='${var.standalone_red5pro_round_trip_auth_endpoint_invalidate}'",
      "mkdir /home/ubuntu/red5pro-installer",
      "mv /home/ubuntu/* /home/ubuntu/red5pro-installer",
      "cd /home/ubuntu/red5pro-installer/",
      "sudo chmod +x /home/ubuntu/red5pro-installer/*.sh",
      "sudo -E /home/ubuntu/red5pro-installer/r5p_install_server_basic.sh",
      "sudo -E /home/ubuntu/red5pro-installer/r5p_config_node_apps_plugins.sh",
      "sudo systemctl daemon-reload && sudo systemctl start red5pro",
      "sudo mkdir -p /usr/local/red5pro/certs",
      "echo '${try(file(var.https_ssl_certificate_cert_path), "")}' | sudo tee -a /usr/local/red5pro/certs/fullchain.pem",
      "echo '${try(file(var.https_ssl_certificate_key_path), "")}' | sudo tee -a /usr/local/red5pro/certs/privkey.pem",
      "export SSL='${var.https_ssl_certificate}'",
      "export SSL_DOMAIN='${var.https_ssl_certificate_domain_name}'",
      "export SSL_MAIL='${var.https_ssl_certificate_email}'",
      "export SSL_PASSWORD='${try(nonsensitive(random_password.ssl_password_red5pro_standalone[0].result), "")}'",
      "export SSL_CERT_PATH=/usr/local/red5pro/certs",
      "nohup sudo -E /home/ubuntu/red5pro-installer/r5p_ssl_check_install.sh >> /home/ubuntu/red5pro-installer/r5p_ssl_check_install.log &",
      "sleep 2"
    ]
    connection {
      host        = tolist(self.ipv4)[0]
      type        = "ssh"
      user        = "root"
      private_key = local.ssh_private_key
    }
  }
}

################################################################################
# Kafka keys and certificates
################################################################################

# Generate random admin usernames for Kafka cluster
resource "random_string" "kafka_admin_username" {
  count   = local.cluster_or_autoscale ? 1 : 0
  length  = 8
  special = false
  upper   = false
  lower   = true
  numeric = false
}

# Generate random client usernames for Kafka cluster
resource "random_string" "kafka_client_username" {
  count   = local.cluster_or_autoscale ? 1 : 0
  length  = 8
  special = false
  upper   = false
  lower   = true
  numeric = false
}

# Generate random IDs for Kafka cluster
resource "random_id" "kafka_cluster_id" {
  count       = local.cluster_or_autoscale ? 1 : 0
  byte_length = 16
}

# Generate random passwords for Kafka cluster
resource "random_id" "kafka_admin_password" {
  count       = local.cluster_or_autoscale ? 1 : 0
  byte_length = 16
}

# Generate random passwords for Kafka cluster
resource "random_id" "kafka_client_password" {
  count       = local.cluster_or_autoscale ? 1 : 0
  byte_length = 16
}

# Create private key for CA
resource "tls_private_key" "ca_private_key" {
  count     = local.cluster_or_autoscale ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create private key for kafka server certificate 
resource "tls_private_key" "kafka_server_key" {
  count     = local.cluster_or_autoscale ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create self-signed certificate for CA
resource "tls_self_signed_cert" "ca_cert" {
  count           = local.cluster_or_autoscale ? 1 : 0
  private_key_pem = tls_private_key.ca_private_key[0].private_key_pem

  is_ca_certificate = true

  subject {
    country             = "US"
    common_name         = "Infrared5, Inc."
    organization        = "Red5"
    organizational_unit = "Red5 Root Certification Auhtority"
  }

  validity_period_hours = 87600 # 10 years

  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "cert_signing",
    "crl_signing",
  ]
}

# Create CSR for server certificate 
resource "tls_cert_request" "kafka_server_csr" {
  count            = local.cluster_or_autoscale ? 1 : 0
  private_key_pem  = tls_private_key.kafka_server_key[0].private_key_pem
  ip_addresses     = [local.kafka_ip[0]]
  #ip_addresses     = local.kafka_ip != "0.0.0.0" ? [local.kafka_ip] : []
  dns_names        = ["kafka0"]

  subject {
    country             = "US"
    common_name         = "Kafka server"
    organization        = "Infrared5, Inc."
    organizational_unit = "Development"
  }

  depends_on = [linode_instance.red5pro_sm, linode_instance.red5pro_kafka]
}

# Sign kafka server Certificate by Private CA 
resource "tls_locally_signed_cert" "kafka_server_cert" {
  count = local.cluster_or_autoscale ? 1 : 0
  # CSR by the development servers
  cert_request_pem = tls_cert_request.kafka_server_csr[0].cert_request_pem
  # CA Private key 
  ca_private_key_pem = tls_private_key.ca_private_key[0].private_key_pem
  # CA certificate
  ca_cert_pem = tls_self_signed_cert.ca_cert[0].cert_pem

  validity_period_hours = 1 * 365 * 24

  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "server_auth",
    "client_auth",
  ]
}

################################################################################
# Kafka server - (Linode Instance)
################################################################################
resource "linode_instance" "red5pro_kafka" {
  count           = local.kafka_standalone_instance ? 1 : 0
  label           = "${var.name}-kafka"
  image           = "linode/ubuntu22.04"
  region          = var.kafka_red5pro_region
  type            = var.kafka_instance_type
  authorized_keys = [
    replace(local.ssh_public_key, "\n", "")
  ]

  interface {
    purpose = "public"
  }

  interface {
    purpose   = "vpc"
    subnet_id = local.subnet_id
  }

  tags       = ["test"]
  private_ip = true
}

resource "null_resource" "red5pro_kafka" {
  count = local.kafka_standalone_instance ? 1 : 0

  provisioner "file" {
    source      = "${abspath(path.module)}/red5pro-installer"
    destination = "/home/ubuntu"

    connection {
      host        = tolist(tolist(linode_instance.red5pro_kafka)[0].ipv4)[0]
      type        = "ssh"
      user        = "root"
      private_key = local.ssh_private_key
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo cloud-init status --wait",
      "mv /home/ubuntu/* /home/ubuntu/red5pro-installer/",
      "echo 'ssl.keystore.key=${local.kafka_ssl_keystore_key}' | sudo tee -a /home/ubuntu/red5pro-installer/server.properties",
      "echo 'ssl.truststore.certificates=${local.kafka_ssl_truststore_cert}' | sudo tee -a /home/ubuntu/red5pro-installer/server.properties",
      "echo 'ssl.keystore.certificate.chain=${local.kafka_ssl_keystore_cert_chain}' | sudo tee -a /home/ubuntu/red5pro-installer/server.properties",
      "echo 'listener.name.broker.plain.sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username=\"${nonsensitive(random_string.kafka_admin_username[0].result)}\" password=\"${nonsensitive(random_id.kafka_admin_password[0].id)}\" user_${nonsensitive(random_string.kafka_admin_username[0].result)}=\"${nonsensitive(random_id.kafka_admin_password[0].id)}\" user_${nonsensitive(random_string.kafka_client_username[0].result)}=\"${nonsensitive(random_id.kafka_client_password[0].id)}\";' | sudo tee -a /home/ubuntu/red5pro-installer/server.properties",
      "echo 'listener.name.controller.plain.sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username=\"${nonsensitive(random_string.kafka_admin_username[0].result)}\" password=\"${nonsensitive(random_id.kafka_admin_password[0].id)}\" user_${nonsensitive(random_string.kafka_admin_username[0].result)}=\"${nonsensitive(random_id.kafka_admin_password[0].id)}\" user_${nonsensitive(random_string.kafka_client_username[0].result)}=\"${nonsensitive(random_id.kafka_client_password[0].id)}\";' | sudo tee -a /home/ubuntu/red5pro-installer/server.properties",
      "echo 'advertised.listeners=BROKER://${local.kafka_ip[0]}:9092' | sudo tee -a /home/ubuntu/red5pro-installer/server.properties",
      "export KAFKA_ARCHIVE_URL='${var.kafka_standalone_instance_arhive_url}'",
      "export KAFKA_CLUSTER_ID='${random_id.kafka_cluster_id[0].b64_std}'",
      "cd /home/ubuntu/red5pro-installer/",
      "sudo chmod +x /home/ubuntu/red5pro-installer/*.sh",
      "sudo -E /home/ubuntu/red5pro-installer/r5p_kafka_install.sh",
    ]

    connection {
      host        = tolist(linode_instance.red5pro_kafka[0].ipv4)[0]
      type        = "ssh"
      user        = "root"
      private_key = local.ssh_private_key
    }
  }

  depends_on = [tls_cert_request.kafka_server_csr]
}


################################################################################
# Red5 Pro Stream Manager 2.0 - (Linode Instance)
################################################################################

# Generate random password for Red5 Pro Stream Manager 2.0 authentication
resource "random_password" "r5as_auth_secret" {
  count   = local.cluster_or_autoscale ? 1 : 0
  length  = 32
  special = false
}

resource "linode_instance" "red5pro_sm" {
  count           = local.cluster_or_autoscale ? 1 : 0
  label           = local.autoscale ? "${var.name}-sm2-image" : "${var.name}-sm2"
  image           = "linode/ubuntu22.04"
  region          = var.stream_manager_red5pro_region
  type            = var.stream_manager_instance_type
  authorized_keys = [
    replace(local.ssh_public_key, "\n", "")
  ]

  interface {
    purpose = "public"
  }

  interface {
    purpose   = "vpc"
    subnet_id = local.subnet_id
  }

    tags       = ["test"]
    private_ip = true

  provisioner "remote-exec" {
    inline = [
      # Create necessary directories
      "sudo mkdir -p /usr/local/stream-manager/keys",
      "sudo mkdir -p /usr/local/stream-manager/certs",

      # Write certificate and key files
      "sudo echo '${try(file(var.https_ssl_certificate_cert_path), "")}' > /usr/local/stream-manager/certs/cert.pem",
      "sudo echo '${try(file(var.https_ssl_certificate_key_path), "")}' > /usr/local/stream-manager/certs/privkey.pem",

      # Write SSH public key
      "sudo echo -n '${local.ssh_public_key}' > /usr/local/stream-manager/keys/red5pro_ssh_public_key",

      # Create .env file with environment variables
      "cat >> /usr/local/stream-manager/.env <<- EOM",
      "KAFKA_CLUSTER_ID=${random_id.kafka_cluster_id[0].b64_std}",
      "KAFKA_ADMIN_USERNAME=${random_string.kafka_admin_username[0].result}",
      "KAFKA_ADMIN_PASSWORD=${random_id.kafka_admin_password[0].id}",
      "KAFKA_CLIENT_USERNAME=${random_string.kafka_client_username[0].result}",
      "KAFKA_CLIENT_PASSWORD=${random_id.kafka_client_password[0].id}",
      "R5AS_AUTH_SECRET=${random_password.r5as_auth_secret[0].result}",
      "R5AS_AUTH_USER=${var.stream_manager_auth_user}",
      "R5AS_AUTH_PASS=${var.stream_manager_auth_password}",
      "TF_VAR_linode_api_token=${var.linode_api_token}",
      "TF_VAR_linode_root_user_password=${var.linode_root_user_password}",
      "TF_VAR_linode_ssh_key_name=${var.linode_ssh_key_name}",
      "TF_VAR_r5p_license_key=${var.red5pro_license_key}",
      "TRAEFIK_TLS_CHALLENGE=${local.stream_manager_ssl == "letsencrypt" ? "true" : "false"}",
      "TRAEFIK_HOST=${var.https_ssl_certificate_domain_name}",
      "TRAEFIK_SSL_EMAIL=${var.https_ssl_certificate_email}",
      "TRAEFIK_CMD=${local.stream_manager_ssl == "imported" ? "--providers.file.filename=/scripts/traefik.yaml" : ""}",
      "EOM"
    ]
    connection {
      host        = tolist(linode_instance.red5pro_sm[0].ipv4)[0]
      type        = "ssh"
      user        = "root"
      private_key = local.ssh_private_key
    }
  }
}

resource "null_resource" "red5pro_sm" {
  count = local.cluster_or_autoscale ? 1 : 0

  provisioner "file" {
    source      = "${abspath(path.module)}/red5pro-installer"
    destination = "/home/ubuntu"

    connection {
      host        = tolist(linode_instance.red5pro_sm[0].ipv4)[0]
      type        = "ssh"
      user        = "root"
      private_key = local.ssh_private_key
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo cloud-init status --wait",
      "sudo mkdir -p /usr/local/stream-manager",
      "echo 'KAFKA_SSL_KEYSTORE_KEY=${local.kafka_ssl_keystore_key}' | sudo tee -a /usr/local/stream-manager/.env",
      "echo 'KAFKA_SSL_TRUSTSTORE_CERTIFICATES=${local.kafka_ssl_truststore_cert}' | sudo tee -a /usr/local/stream-manager/.env",
      "echo 'KAFKA_SSL_KEYSTORE_CERTIFICATE_CHAIN=${local.kafka_ssl_keystore_cert_chain}' | sudo tee -a /usr/local/stream-manager/.env",
      "echo 'KAFKA_REPLICAS=${local.kafka_on_sm_replicas}' | sudo tee -a /usr/local/stream-manager/.env",
      "echo 'R5AS_CLOUD_PLATFORM_TYPE=${var.R5AS_CLOUD_PLATFORM_TYPE}' | sudo tee -a /usr/local/stream-manager/.env",
      "echo 'KAFKA_IP=${local.kafka_ip != [] ? local.kafka_ip[0] : "default_ip"}' | sudo tee -a /usr/local/stream-manager/.env",
      "echo 'TRAEFIK_IP=${tolist(linode_instance.red5pro_sm[0].ipv4)[0]}' | sudo tee -a /usr/local/stream-manager/.env",
      "echo 'TF_VAR_linode_api_token=${var.linode_api_token}' | sudo tee -a /usr/local/stream-manager/.env",
      "echo 'TF_VAR_linode_root_user_password=${var.linode_root_user_password}' | sudo tee -a /usr/local/stream-manager/.env",
      "echo 'TF_VAR_linode_ssh_key_name=${var.linode_ssh_key_name}' | sudo tee -a /usr/local/stream-manager/.env",
      "export SM_SSL='${local.stream_manager_ssl}'",
      "export SM_STANDALONE='${local.stream_manager_standalone}'",
      "export SM_SSL_DOMAIN='${var.https_ssl_certificate_domain_name}'",
      "mkdir /home/ubuntu/red5pro-installer",
      "mv /home/ubuntu/* /home/ubuntu/red5pro-installer/",
      "cd /home/ubuntu/red5pro-installer/",
      "sudo chmod +x /home/ubuntu/red5pro-installer/*.sh",
      "sudo -E /home/ubuntu/red5pro-installer/r5p_install_sm2_oci.sh",
    ]
    connection {
      host        = tolist(linode_instance.red5pro_sm[0].ipv4)[0]
      type        = "ssh"
      user        = "root"
      private_key = local.ssh_private_key
    }
  }
  depends_on = [tls_cert_request.kafka_server_csr, null_resource.red5pro_kafka]
}

resource "linode_instance" "red5pro_node" {
  count           = local.cluster_or_autoscale && var.node_image_create ? 1 : 0
  label           = "${var.name}-node-image"
  image           = "linode/ubuntu22.04"
  region          = var.node_image_region
  type            = var.node_image_instance_type

  interface {
    purpose = "public"
  }

  interface {
    purpose   = "vpc"
    subnet_id = local.subnet_id
  }

  tags       = ["test"]
  private_ip = true

  authorized_keys = [
    replace(local.ssh_public_key, "\n", "")
  ]


  provisioner "file" {
    source      = "${abspath(path.module)}/red5pro-installer"
    destination = "/home/ubuntu"

    connection {
      host        = tolist(self.ipv4)[0]
      type        = "ssh"
      user        = "root"
      private_key = local.ssh_private_key
    }
  }

  provisioner "file" {
    source      = var.path_to_red5pro_build
    destination = "/home/ubuntu/${basename(var.path_to_red5pro_build)}"

    connection {
      host        = tolist(self.ipv4)[0]
      type        = "ssh"
      user        = "root"
      private_key = local.ssh_private_key
    }
  }

    provisioner "remote-exec" {
    inline = [
      "sudo cloud-init status --wait",
      "export LICENSE_KEY='${var.red5pro_license_key}'",
      "export NODE_API_ENABLE='${var.red5pro_api_enable}'",
      "export NODE_API_KEY='${var.red5pro_api_key}'",
      "mkdir /home/ubuntu/red5pro-installer",
      "mv /home/ubuntu/* /home/ubuntu/red5pro-installer/",
      "cd /home/ubuntu/red5pro-installer/",
      "sudo chmod +x /home/ubuntu/red5pro-installer/*.sh",
      "sudo -E /home/ubuntu/red5pro-installer/r5p_install_server_basic.sh",
      "sudo -E /home/ubuntu/red5pro-installer/r5p_config_node.sh",
    ]
    connection {
      host        = tolist(self.ipv4)[0]
      type        = "ssh"
      user        = "root"
      private_key = local.ssh_private_key
    }
  }
}

####################################################################################################
# Red5 Pro Autoscaling Nodes create images - Origin/Edge/Transcoders/Relay (Linode Custom Images)
####################################################################################################

# Node - Create image (Linode Custom Images)
resource "linode_image" "red5pro_node_image" {
  count       = local.cluster_or_autoscale && var.node_image_create ? 1 : 0
  label       = "${var.name}-node-image-${formatdate("DDMMMYY-hhmm", timestamp())}"
  disk_id     = linode_instance.red5pro_node[0].disk[0].id
  linode_id   = linode_instance.red5pro_node[0].id
  depends_on  = [linode_instance.red5pro_node]
  lifecycle {
    ignore_changes = [label]
  }
}

################################################################################
# Create/Delete node group (Stream Manager API)
################################################################################
resource "time_sleep" "wait_for_delete_nodegroup" {
  count = local.cluster_or_autoscale && var.node_group_create ? 1 : 0
  depends_on = [
    null_resource.red5pro_sm[0],
    null_resource.red5pro_kafka[0],
    linode_instance.red5pro_sm[0],
    linode_instance.red5pro_kafka[0],
  ]
  destroy_duration = "90s"
}

resource "null_resource" "node_group" {
  count = local.cluster_or_autoscale && var.node_group_create ? 1 : 0
  triggers = {
    trigger_name   = "node-group-trigger"
    SM_URL         = "${local.stream_manager_url}"
    R5AS_AUTH_USER = "${var.stream_manager_auth_user}"
    R5AS_AUTH_PASS = "${var.stream_manager_auth_password}"
  }
  provisioner "local-exec" {
    when    = create
    command = "bash ${abspath(path.module)}/red5pro-installer/r5p_create_node_group.sh"
    environment = {
      SM_URL                                   = "${local.stream_manager_url}"
      R5AS_AUTH_USER                           = "${var.stream_manager_auth_user}"
      R5AS_AUTH_PASS                           = "${var.stream_manager_auth_password}"
      NODE_GROUP_REGION                        = "${var.node_image_region}"
      NODE_ENVIRONMENT                         = "${var.name}"
      NODE_SUBNET_NAME                         = "${var.vpc_label}" 
      NODE_SECURITY_GROUP_NAME                 = "${var.node_firewall_label}"
      NODE_IMAGE_NAME                          = "${linode_image.red5pro_node_image[0].label}"
      NODE_CLOUD_PLATFORM                      = "LINODE"
      ORIGINS_MIN                              = "${var.node_group_origins_min}"
      ORIGINS_MAX                              = "${var.node_group_origins_max}"
      ORIGIN_INSTANCE_TYPE                     = "${var.node_image_instance_type}"
      ORIGIN_VOLUME_SIZE                       = "${var.node_group_origins_volume_size}"
      EDGES_MIN                                = "${var.node_group_edges_min}"
      EDGES_MAX                                = "${var.node_group_edges_max}"
      EDGE_INSTANCE_TYPE                       = "${var.node_image_instance_type}"
      EDGE_VOLUME_SIZE                         = "${var.node_group_edges_volume_size}"
      TRANSCODERS_MIN                          = "${var.node_group_transcoders_min}"
      TRANSCODERS_MAX                          = "${var.node_group_transcoders_max}"
      TRANSCODER_INSTANCE_TYPE                 = "${var.node_group_transcoders_instance_type}"
      TRANSCODER_VOLUME_SIZE                   = "${var.node_group_transcoders_volume_size}"
      RELAYS_MIN                               = "${var.node_group_relays_min}"
      RELAYS_MAX                               = "${var.node_group_relays_max}"
      RELAY_INSTANCE_TYPE                      = "${var.node_group_relays_instance_type}"
      RELAY_VOLUME_SIZE                        = "${var.node_group_relays_volume_size}"
      PATH_TO_JSON_TEMPLATES                   = "${abspath(path.module)}/red5pro-installer/nodegroup-json-templates"
      NODE_ROUND_TRIP_AUTH_ENABLE              = "${var.node_config_round_trip_auth.enable}"
      NODE_ROUNT_TRIP_AUTH_TARGET_NODES        = "${join(",", var.node_config_round_trip_auth.target_nodes)}"
      NODE_ROUND_TRIP_AUTH_HOST                = "${var.node_config_round_trip_auth.auth_host}"
      NODE_ROUND_TRIP_AUTH_PORT                = "${var.node_config_round_trip_auth.auth_port}"
      NODE_ROUND_TRIP_AUTH_PROTOCOL            = "${var.node_config_round_trip_auth.auth_protocol}"
      NODE_ROUND_TRIP_AUTH_ENDPOINT_VALIDATE   = "${var.node_config_round_trip_auth.auth_endpoint_validate}"
      NODE_ROUND_TRIP_AUTH_ENDPOINT_INVALIDATE = "${var.node_config_round_trip_auth.auth_endpoint_invalidate}"
      NODE_WEBHOOK_ENABLE                      = "${var.node_config_webhooks.enable}"
      NODE_WEBHOOK_TARGET_NODES                = "${join(",", var.node_config_webhooks.target_nodes)}"
      NODE_WEBHOOK_ENDPOINT                    = "${var.node_config_webhooks.webhook_endpoint}"
      NODE_SOCIAL_PUSHER_ENABLE                = "${var.node_config_social_pusher.enable}"
      NODE_SOCIAL_PUSHER_TARGET_NODES          = "${join(",", var.node_config_social_pusher.target_nodes)}"
      NODE_RESTREAMER_ENABLE                   = "${var.node_config_restreamer.enable}"
      NODE_RESTREAMER_TARGET_NODES             = "${join(",", var.node_config_restreamer.target_nodes)}"
      NODE_RESTREAMER_TSINGEST                 = "${var.node_config_restreamer.restreamer_tsingest}"
      NODE_RESTREAMER_IPCAM                    = "${var.node_config_restreamer.restreamer_ipcam}"
      NODE_RESTREAMER_WHIP                     = "${var.node_config_restreamer.restreamer_whip}"
      NODE_RESTREAMER_SRTINGEST                = "${var.node_config_restreamer.restreamer_srtingest}"
    }
  }

    provisioner "local-exec" {
    when    = destroy
    command = "bash ${abspath(path.module)}/red5pro-installer/r5p_delete_node_group.sh '${self.triggers.SM_URL}' '${self.triggers.R5AS_AUTH_USER}' '${self.triggers.R5AS_AUTH_PASS}'"
  }

  depends_on = [time_sleep.wait_for_delete_nodegroup[0]]

  lifecycle {
    precondition {
      condition     = var.node_image_create == true
      error_message = "ERROR! Node group creation requires the creation of a Node image for the node group. Please set the 'node_image_create' variable to 'true' and re-run the Terraform apply."
    }
  }
}
