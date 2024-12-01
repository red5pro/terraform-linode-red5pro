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
  token = var.linode_api_token
}