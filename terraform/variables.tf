variable "vnet_name" {}

variable "vm_name" {}

variable "admin_password" {}

variable "admin_username" {}

variable "subnet_count" {}

variable "vmss_names" {
  type = list(string)
}

variable "vmss_count" {
  type = number
}

variable "address_space" {
  type = string
}

variable "default_instances_count" {
  type = map(number)
}

variable "max_instances_count" {
  type = map(number)
}

variable "subnet_names" {
  type = list(string)
}

variable "public_ip_names" {
  type = list(string)
}

variable "resource_group_name" {
  type    = string
  default = "myAppName"
}

variable "public_ip_count" {
  type    = number
  default = 2
}

variable "location" {
  type        = string
  default     = "eastus2"
  description = "Location of resources"
}

variable "instance_count" {
  type        = number
  description = "Number of instances"
  default     = 2
}

variable "billing_code" {
  type        = string
  description = "Code through which it is identified in billing"
  default     = "myAppName"
}

locals {
  env_name = lower(terraform.workspace)

  common_tags = {
    BillingCode = var.billing_code
    Environment = terraform.workspace
  }

  # storage_account_name = "${var.storage_account_name}-${random_integer.rand.result}"
  # resource_group_name  = "${var.resource_group_nmae}-${terraform.workspace}"
}