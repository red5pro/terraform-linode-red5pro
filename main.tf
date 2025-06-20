locals {
  standalone                    = var.type == "standalone" ? true : false
  cluster                       = var.type == "cluster" ? true : false
  autoscale                     = var.type == "autoscale" ? true : false
  cluster_or_autoscale          = local.cluster || local.autoscale ? true : false
  vcn_id                        = linode_vpc.red5vpc.id
  vcn_name                      = linode_vpc.red5vpc.label
  subnet_id                     = linode_vpc_subnet.red5subnet.id
  subnet_name                   = linode_vpc_subnet.red5subnet.label
  stream_manager_ip             = local.autoscale ? linode_nodebalancer.red5pro_lb[0].ipv4 : local.cluster ? linode_instance.red5pro_sm[0].ip_address : ""
  stream_manager_count          = local.autoscale ? var.stream_manager_count : local.cluster ? 1 : 0
  ssh_private_key_path          = var.ssh_key_use_existing ? var.ssh_key_existing_private_key_path : local_file.red5pro_ssh_key_pem[0].filename
  ssh_private_key               = var.ssh_key_use_existing ? file(var.ssh_key_existing_private_key_path) : tls_private_key.red5pro_ssh_key[0].private_key_pem
  ssh_public_key                = var.ssh_key_use_existing ? data.linode_sshkey.node_ssh_key[0].ssh_key : linode_sshkey.node_ssh_key[0].ssh_key
  ssh_key_name                  = var.ssh_key_use_existing ? data.linode_sshkey.node_ssh_key[0].label : linode_sshkey.node_ssh_key[0].label
  kafka_standalone_instance     = local.autoscale ? true : local.cluster && var.kafka_standalone_instance_create ? true : false
  kafka_ip                      = local.cluster_or_autoscale ? local.kafka_standalone_instance ? linode_instance.red5pro_kafka[0].interface[1].ipv4[0].vpc : linode_instance.red5pro_sm[0].interface[1].ipv4[0].vpc : "null"
  kafka_on_sm_replicas          = local.kafka_standalone_instance ? 0 : 1
  kafka_ssl_keystore_key        = local.cluster_or_autoscale ? nonsensitive(join("\\\\n", split("\n", trimspace(tls_private_key.kafka_server_key[0].private_key_pem_pkcs8)))) : "null"
  kafka_ssl_truststore_cert     = local.cluster_or_autoscale ? nonsensitive(join("\\\\n", split("\n", tls_self_signed_cert.ca_cert[0].cert_pem))) : "null"
  kafka_ssl_keystore_cert_chain = local.cluster_or_autoscale ? nonsensitive(join("\\\\n", split("\n", tls_locally_signed_cert.kafka_server_cert[0].cert_pem))) : "null"
  stream_manager_ssl            = local.autoscale ? "none" : var.https_ssl_certificate
  stream_manager_url            = local.stream_manager_ssl != "none" ? "https://${local.stream_manager_ip}" : "http://${local.stream_manager_ip}"
  r5as_traefik_host             = local.autoscale ? local.stream_manager_ip : var.https_ssl_certificate_domain_name
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

resource "linode_sshkey" "node_ssh_key" {
  count    = var.ssh_key_use_existing ? 0 : 1
  label    = "ssh-key-${var.name}"
  ssh_key  = replace(tls_private_key.red5pro_ssh_key[0].public_key_openssh, "\n", "")
}

data "linode_sshkey" "node_ssh_key" {
  count    = var.ssh_key_use_existing ? 1 : 0
  label    = var.ssh_key_name_existing
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
    image           = "linode/ubuntu${var.ubuntu_version}"
    region          = var.linode_region
    type            = var.standalone_red5pro_instance_type
    authorized_keys = [replace(local.ssh_public_key, "\n", "")]

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
    destination = "/root"

    connection {
      host        = self.ip_address
      type        = "ssh"
      user        = "root"
      private_key = local.ssh_private_key
    }
  }

    provisioner "file" {
    source      = var.path_to_red5pro_build
    destination = "/root/red5pro-installer/${basename(var.path_to_red5pro_build)}"

    connection {
      host        = self.ip_address
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
      "cd /root/red5pro-installer/",
      "sudo chmod +x /root/red5pro-installer/*.sh",
      "sudo -E /root/red5pro-installer/r5p_install_server_basic.sh",
      "sudo -E /root/red5pro-installer/r5p_config_node_apps_plugins.sh",
      "sudo systemctl daemon-reload && sudo systemctl start red5pro",
      "sudo mkdir -p /usr/local/red5pro/certs",
      "echo '${try(file(var.https_ssl_certificate_cert_path), "")}' | sudo tee -a /usr/local/red5pro/certs/fullchain.pem",
      "echo '${try(file(var.https_ssl_certificate_key_path), "")}' | sudo tee -a /usr/local/red5pro/certs/privkey.pem",
      "export SSL='${var.https_ssl_certificate}'",
      "export SSL_DOMAIN='${var.https_ssl_certificate_domain_name}'",
      "export SSL_MAIL='${var.https_ssl_certificate_email}'",
      "export SSL_PASSWORD='${try(nonsensitive(random_password.ssl_password_red5pro_standalone[0].result), "")}'",
      "export SSL_CERT_PATH=/usr/local/red5pro/certs",
      "nohup sudo -E /root/red5pro-installer/r5p_ssl_check_install.sh >> /root/red5pro-installer/r5p_ssl_check_install.log &",
      "sleep 2"
    ]
    connection {
      host        = self.ip_address
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
  ip_addresses     = [local.kafka_ip]
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
  image           = "linode/ubuntu${var.ubuntu_version}"
  region          = var.linode_region
  type            = var.kafka_standalone_instance_type
  authorized_keys = [replace(local.ssh_public_key, "\n", "")]

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
    destination = "/root"

    connection {
      host        = linode_instance.red5pro_kafka[0].ip_address
      type        = "ssh"
      user        = "root"
      private_key = local.ssh_private_key
    }
  }

  provisioner "remote-exec" {
    inline = [     
      "sudo cloud-init status --wait",
      "echo 'ssl.keystore.key=${local.kafka_ssl_keystore_key}' | sudo tee -a /root/red5pro-installer/server.properties",
      "echo 'ssl.truststore.certificates=${local.kafka_ssl_truststore_cert}' | sudo tee -a /root/red5pro-installer/server.properties",
      "echo 'ssl.keystore.certificate.chain=${local.kafka_ssl_keystore_cert_chain}' | sudo tee -a /root/red5pro-installer/server.properties",
      "echo 'listener.name.broker.plain.sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username=\"${nonsensitive(random_string.kafka_admin_username[0].result)}\" password=\"${nonsensitive(random_id.kafka_admin_password[0].id)}\" user_${nonsensitive(random_string.kafka_admin_username[0].result)}=\"${nonsensitive(random_id.kafka_admin_password[0].id)}\" user_${nonsensitive(random_string.kafka_client_username[0].result)}=\"${nonsensitive(random_id.kafka_client_password[0].id)}\";' | sudo tee -a /root/red5pro-installer/server.properties",
      "echo 'listener.name.controller.plain.sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username=\"${nonsensitive(random_string.kafka_admin_username[0].result)}\" password=\"${nonsensitive(random_id.kafka_admin_password[0].id)}\" user_${nonsensitive(random_string.kafka_admin_username[0].result)}=\"${nonsensitive(random_id.kafka_admin_password[0].id)}\" user_${nonsensitive(random_string.kafka_client_username[0].result)}=\"${nonsensitive(random_id.kafka_client_password[0].id)}\";' | sudo tee -a /root/red5pro-installer/server.properties",
      "echo 'advertised.listeners=BROKER://${local.kafka_ip}:9092' | sudo tee -a /root/red5pro-installer/server.properties",
      "export KAFKA_ARCHIVE_URL='${var.kafka_standalone_instance_arhive_url}'",
      "export KAFKA_CLUSTER_ID='${random_id.kafka_cluster_id[0].b64_std}'",
      "cd /root/red5pro-installer/",
      "sudo chmod +x /root/red5pro-installer/*.sh",
      "sudo -E /root/red5pro-installer/r5p_kafka_install.sh",
    ]

    connection {
      host        = linode_instance.red5pro_kafka[0].ip_address
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
  count           = local.stream_manager_count
  label           = local.stream_manager_count == 1 ? "${var.name}-sm2" : "${var.name}-sm2-${count.index+1}"
  image           = "linode/ubuntu${var.ubuntu_version}"
  region          = var.linode_region
  type            = var.stream_manager_instance_type
  authorized_keys = [replace(local.ssh_public_key, "\n", "")]

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
      "R5AS_PROXY_USER=${var.stream_manager_proxy_user}",
      "R5AS_PROXY_PASS=${var.stream_manager_proxy_password}",
      "R5AS_SPATIAL_USER=${var.stream_manager_spatial_user}",
      "R5AS_SPATIAL_PASS=${var.stream_manager_spatial_password}",
      "AS_VERSION=${var.stream_manager_version}",
      "TF_VAR_linode_api_token=${var.linode_api_token}",
      "TF_VAR_linode_ssh_key_name=${local.ssh_key_name}",
      "TF_VAR_r5p_license_key=${var.red5pro_license_key}",
      "TRAEFIK_TLS_CHALLENGE=${local.stream_manager_ssl == "letsencrypt" ? "true" : "false"}",
      "TRAEFIK_HOST=${local.r5as_traefik_host}",
      "TRAEFIK_SSL_EMAIL=${var.https_ssl_certificate_email}",
      "TRAEFIK_CMD=${local.stream_manager_ssl == "imported" ? "--providers.file.filename=/scripts/traefik.yaml" : ""}",
      "EOM"
    ]
    connection {
      host        = self.ip_address
      type        = "ssh"
      user        = "root"
      private_key = local.ssh_private_key
    }
  }
}

resource "null_resource" "red5pro_sm" {
  count  = local.stream_manager_count

  provisioner "file" {
    source      = "${abspath(path.module)}/red5pro-installer"
    destination = "/root"

    connection {
      host        = linode_instance.red5pro_sm[count.index].ip_address
      type        = "ssh"
      user        = "root"
      private_key = local.ssh_private_key
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo cloud-init status --wait",
      "echo 'KAFKA_SSL_KEYSTORE_KEY=${local.kafka_ssl_keystore_key}' | sudo tee -a /usr/local/stream-manager/.env",
      "echo 'KAFKA_SSL_TRUSTSTORE_CERTIFICATES=${local.kafka_ssl_truststore_cert}' | sudo tee -a /usr/local/stream-manager/.env",
      "echo 'KAFKA_SSL_KEYSTORE_CERTIFICATE_CHAIN=${local.kafka_ssl_keystore_cert_chain}' | sudo tee -a /usr/local/stream-manager/.env",
      "echo 'KAFKA_REPLICAS=${local.kafka_on_sm_replicas}' | sudo tee -a /usr/local/stream-manager/.env",
      "echo 'KAFKA_IP=${local.kafka_ip}' | sudo tee -a /usr/local/stream-manager/.env",
      "echo 'TRAEFIK_IP=${linode_instance.red5pro_sm[count.index].ip_address}' | sudo tee -a /usr/local/stream-manager/.env",
      "export SM_SSL='${local.stream_manager_ssl}'",
      "export SM_STANDALONE=true",
      "export SM_SSL_DOMAIN='${var.https_ssl_certificate_domain_name}'",
      "cd /root/red5pro-installer/",
      "sudo chmod +x /root/red5pro-installer/*.sh",
      "sudo -E /root/red5pro-installer/r5p_install_sm2.sh",
    ]
    connection {
      host        = linode_instance.red5pro_sm[count.index].ip_address
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
  image           = "linode/ubuntu${var.ubuntu_version}"
  region          = var.linode_region
  type            = var.node_image_instance_type
  authorized_keys = [replace(local.ssh_public_key, "\n", "")]

  interface {
    purpose = "public"
  }

  interface {
    purpose   = "vpc"
    subnet_id = local.subnet_id
  }

  tags       = ["test"]
  private_ip = true

  provisioner "file" {
    source      = "${abspath(path.module)}/red5pro-installer"
    destination = "/root"

    connection {
      host        = self.ip_address
      type        = "ssh"
      user        = "root"
      private_key = local.ssh_private_key
    }
  }

  provisioner "file" {
    source      = var.path_to_red5pro_build
    destination = "/root/red5pro-installer/${basename(var.path_to_red5pro_build)}"

    connection {
      host        = self.ip_address
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
      "cd /root/red5pro-installer/",
      "sudo chmod +x /root/red5pro-installer/*.sh",
      "sudo -E /root/red5pro-installer/r5p_install_server_basic.sh",
      "sudo -E /root/red5pro-installer/r5p_config_node.sh",
    ]
    connection {
      host        = self.ip_address
      type        = "ssh"
      user        = "root"
      private_key = local.ssh_private_key
    }
  }
}

################################################################################
# Red5 Pro Stream Manager Autoscaling (Linode Node Balancer + Autoscaling)
################################################################################

resource "linode_nodebalancer" "red5pro_lb" {
    count     = local.autoscale ? 1 : 0
    label     = "${var.name}-sm2-lb"
    region    = var.linode_region
}

resource "linode_nodebalancer_config" "red5pro_lbconfig_http"{
    count           = local.autoscale && var.https_ssl_certificate == "none" ? 1 : 0
    nodebalancer_id = linode_nodebalancer.red5pro_lb[0].id
    port            = 80
    protocol        = "http"
    check           = "http"
    check_path      = "/as/v1/admin/healthz"    
    algorithm       = "roundrobin"
}

resource "linode_nodebalancer_config" "red5pro_lbconfig_https"{
    count           = local.autoscale && var.https_ssl_certificate == "imported" ? 1 : 0
    nodebalancer_id = linode_nodebalancer.red5pro_lb[0].id
    port            = 443
    protocol        = "https"
    check           = "http"
    check_path      = "/as/v1/admin/healthz"
    ssl_cert        = file(var.https_ssl_certificate_cert_path)
    ssl_key         = file(var.https_ssl_certificate_key_path)
    algorithm       = "roundrobin"
}

####################################################################################################
# Red5 Pro Autoscaling Node Balacer 
####################################################################################################

resource "linode_nodebalancer_node" "red5pro_sm_backend-nodes-http" {
  count           = local.autoscale && var.stream_manager_count > 0 && var.https_ssl_certificate == "none" ? var.stream_manager_count : 0
  label           = "backend-node-${count.index + 1}"
  nodebalancer_id = linode_nodebalancer.red5pro_lb[0].id
  config_id       = linode_nodebalancer_config.red5pro_lbconfig_http[0].id
  address         = "${element(linode_instance.red5pro_sm[*].private_ip_address, count.index)}:80"
  mode            = "accept"
  depends_on      = [linode_instance.red5pro_sm]
}

resource "linode_nodebalancer_node" "red5pro_sm_backend-nodes-https" {
  count           = local.autoscale && var.stream_manager_count > 0 && var.https_ssl_certificate == "imported" ? var.stream_manager_count : 0
  label           = "backend-node-${count.index + 1}"
  nodebalancer_id = linode_nodebalancer.red5pro_lb[0].id
  config_id       = linode_nodebalancer_config.red5pro_lbconfig_https[0].id
  address         = "${element(linode_instance.red5pro_sm[*].private_ip_address, count.index)}:80"
  mode            = "accept"
  depends_on      = [linode_instance.red5pro_sm]
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
    SM_IP          = "${local.stream_manager_ip}"
    R5AS_AUTH_USER = "${var.stream_manager_auth_user}"
    R5AS_AUTH_PASS = "${var.stream_manager_auth_password}"
  }
  provisioner "local-exec" {
    when    = create
    command = "bash ${abspath(path.module)}/red5pro-installer/r5p_create_node_group.sh"
    environment = {
      SM_IP                                          = "${local.stream_manager_ip}"
      NODE_GROUP_NAME                                = "${substr(var.name, 0, 16)}"
      R5AS_AUTH_USER                                 = "${var.stream_manager_auth_user}"
      R5AS_AUTH_PASS                                 = "${var.stream_manager_auth_password}"
      NODE_GROUP_CLOUD_PLATFORM                      = "LINODE"
      NODE_GROUP_REGIONS                             = "${var.linode_region}"
      NODE_GROUP_ENVIRONMENT                         = "${var.name}"
      NODE_GROUP_VPC_NAME                            = "${var.vpc_label}"
      NODE_GROUP_SECURITY_GROUP_NAME                 = "${var.node_firewall_label}"
      NODE_GROUP_IMAGE_NAME                          = "${linode_image.red5pro_node_image[0].label}"
      NODE_GROUP_ORIGINS_MIN                         = "${var.node_group_origins_min}"
      NODE_GROUP_ORIGINS_MAX                         = "${var.node_group_origins_max}"
      NODE_GROUP_ORIGIN_INSTANCE_TYPE                = "${var.node_group_origins_instance_type}"
      NODE_GROUP_ORIGIN_VOLUME_SIZE                  = "${var.node_group_origins_volume_size}"
      NODE_GROUP_ORIGINS_CONNECTION_LIMIT            = "${var.node_group_origins_connection_limit}"
      NODE_GROUP_EDGES_MIN                           = "${var.node_group_edges_min}"
      NODE_GROUP_EDGES_MAX                           = "${var.node_group_edges_max}"
      NODE_GROUP_EDGE_INSTANCE_TYPE                  = "${var.node_group_edges_instance_type}"
      NODE_GROUP_EDGE_VOLUME_SIZE                    = "${var.node_group_edges_volume_size}"
      NODE_GROUP_EDGES_CONNECTION_LIMIT              = "${var.node_group_edges_connection_limit}"
      NODE_GROUP_TRANSCODERS_MIN                     = "${var.node_group_transcoders_min}"
      NODE_GROUP_TRANSCODERS_MAX                     = "${var.node_group_transcoders_max}"
      NODE_GROUP_TRANSCODER_INSTANCE_TYPE            = "${var.node_group_transcoders_instance_type}"
      NODE_GROUP_TRANSCODER_VOLUME_SIZE              = "${var.node_group_transcoders_volume_size}"
      NODE_GROUP_TRANSCODERS_CONNECTION_LIMIT        = "${var.node_group_transcoders_connection_limit}"
      NODE_GROUP_RELAYS_MIN                          = "${var.node_group_relays_min}"
      NODE_GROUP_RELAYS_MAX                          = "${var.node_group_relays_max}"
      NODE_GROUP_RELAY_INSTANCE_TYPE                 = "${var.node_group_relays_instance_type}"
      NODE_GROUP_RELAY_VOLUME_SIZE                   = "${var.node_group_relays_volume_size}"
      NODE_GROUP_ROUND_TRIP_AUTH_ENABLE              = "${var.node_config_round_trip_auth.enable}"
      NODE_GROUP_ROUNT_TRIP_AUTH_TARGET_NODES        = "${join(",", var.node_config_round_trip_auth.target_nodes)}"
      NODE_GROUP_ROUND_TRIP_AUTH_HOST                = "${var.node_config_round_trip_auth.auth_host}"
      NODE_GROUP_ROUND_TRIP_AUTH_PORT                = "${var.node_config_round_trip_auth.auth_port}"
      NODE_GROUP_ROUND_TRIP_AUTH_PROTOCOL            = "${var.node_config_round_trip_auth.auth_protocol}"
      NODE_GROUP_ROUND_TRIP_AUTH_ENDPOINT_VALIDATE   = "${var.node_config_round_trip_auth.auth_endpoint_validate}"
      NODE_GROUP_ROUND_TRIP_AUTH_ENDPOINT_INVALIDATE = "${var.node_config_round_trip_auth.auth_endpoint_invalidate}"
      NODE_GROUP_WEBHOOK_ENABLE                      = "${var.node_config_webhooks.enable}"
      NODE_GROUP_WEBHOOK_TARGET_NODES                = "${join(",", var.node_config_webhooks.target_nodes)}"
      NODE_GROUP_WEBHOOK_ENDPOINT                    = "${var.node_config_webhooks.webhook_endpoint}"
      NODE_GROUP_SOCIAL_PUSHER_ENABLE                = "${var.node_config_social_pusher.enable}"
      NODE_GROUP_SOCIAL_PUSHER_TARGET_NODES          = "${join(",", var.node_config_social_pusher.target_nodes)}"
      NODE_GROUP_RESTREAMER_ENABLE                   = "${var.node_config_restreamer.enable}"
      NODE_GROUP_RESTREAMER_TARGET_NODES             = "${join(",", var.node_config_restreamer.target_nodes)}"
      NODE_GROUP_RESTREAMER_TSINGEST                 = "${var.node_config_restreamer.restreamer_tsingest}"
      NODE_GROUP_RESTREAMER_IPCAM                    = "${var.node_config_restreamer.restreamer_ipcam}"
      NODE_GROUP_RESTREAMER_WHIP                     = "${var.node_config_restreamer.restreamer_whip}"
      NODE_GROUP_RESTREAMER_SRTINGEST                = "${var.node_config_restreamer.restreamer_srtingest}"
    }
  }

    provisioner "local-exec" {
    when    = destroy
    command = "bash ${abspath(path.module)}/red5pro-installer/r5p_delete_node_group.sh '${self.triggers.SM_IP}' '${self.triggers.R5AS_AUTH_USER}' '${self.triggers.R5AS_AUTH_PASS}'"
  }

  depends_on = [time_sleep.wait_for_delete_nodegroup[0]]

  lifecycle {
    precondition {
      condition     = var.node_image_create == true
      error_message = "ERROR! Node group creation requires the creation of a Node image for the node group. Please set the 'node_image_create' variable to 'true' and re-run the Terraform apply."
    }
  }
}