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