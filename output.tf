output "vpc_name" {
  description = "The ID of the VPC"
  value       = linode_vpc.red5vpc.label
}

output "subnet_name" {
  description = "The ID of the VPC subnet"
  value       = linode_vpc_subnet.red5subnet.label
}

output "ssh_private_key_path" {
  description = "SSH private key path"
  value       = local.ssh_private_key_path
}

output "standalone_red5pro_server_ip" {
  description = "Standalone Red5 Pro Server IP"
  value       = local.standalone ? linode_instance.standalone_instance[0].ip_address : ""
}

output "standalone_red5pro_server_http_url" {
  description = "Standalone Red5 Pro Server HTTP URL"
  value       = local.standalone ? "http://${linode_instance.standalone_instance[0].ip_address}:5080" : ""
}

output "standalone_red5pro_server_https_url" {
  description = "Standalone Red5 Pro Server HTTPS URL"
  value       = local.standalone && var.https_ssl_certificate != "none" ? "https://${var.https_ssl_certificate_domain_name}:443" : ""
}

output "manual_dns_record" {
  description = "Manual DNS Record"
  value       = var.https_ssl_certificate != "none" ? "Please create DNS A record for Stream Manager 2.0: '${var.https_ssl_certificate_domain_name} - ${local.cluster_or_autoscale ? local.stream_manager_ip : tolist(linode_instance.standalone_instance[0].ipv4)[0]}'" : ""
}

output "stream_manager_ip" {
  description = "Stream Manager 2.0 Public IP or Load Balancer Public IP"
  value       = local.cluster_or_autoscale ? local.stream_manager_ip : ""
}

output "stream_manager_url_http" {
  description = "Stream Manager HTTP URL"
  value       = local.cluster_or_autoscale ? "http://${local.stream_manager_ip}:80" : ""
}

output "stream_manager_url_https" {
  description = "Stream Manager HTTPS URL"
  value       = local.cluster_or_autoscale ? var.https_ssl_certificate != "none" ? "https://${var.https_ssl_certificate_domain_name}:443" : "" : ""
}
output "stream_manager_red5pro_node_image" {
  description = "Stream Manager 2.0 Red5 Pro Node Image (OCI Custom Image)"
  value       = try(linode_image.red5pro_node_image[0].label, "")
}