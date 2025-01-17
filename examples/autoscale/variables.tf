variable "linode_api_token" {
    type    = string
    default = "" 
    validation {
        condition     = var.linode_api_token != ""
        error_message = "The Linode API token cannot be empty. Please provide a valid token."   
    }
}