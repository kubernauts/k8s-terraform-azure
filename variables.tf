variable "azure_tenant_id" {
    default = "your tenant id ?????????????????????????????????"
}

variable "azure_subscription_id" {
    default = "your sub id ????????????????????????????????????"
}
variable "azure_location" {
    default = "westeurope"
}
variable "resource_group_name" {}

variable "resource_name_prefix" {}

variable "admin_public_key" {}
variable "admin_username" {}

variable "api_loadbalancer_frontend_port" {}
variable "api_loadbalancer_backend_port" {}

variable "vnet_cidr" {}

// VM image
variable "vm_image_publisher" {}

variable "vm_image_offer" {}
variable "vm_image_sku" {}
variable "vm_image_version" {}

// Storage
variable "storage_replication_type" {}

variable "storage_account_tier" {}

// Master profile
variable "master_subnet_cidr" {}

variable "master_first_ip" {}
variable "master_count" {}
variable "master_vm_size" {}
variable "master_vm_osdisk_type" {}
variable "master_vm_osdisk_size_in_gb" {}

// Agent pool "services"
variable "service_minions_count" {}

variable "service_minions_subnet_cidr" {}
variable "service_minions_vm_size" {}
variable "service_minions_vm_osdisk_type" {}
variable "service_minions_vm_osdisk_size_in_gb" {}

// Agent pool "backend"
variable "backend_minions_count" {}

variable "backend_minions_subnet_cidr" {}
variable "backend_minions_vm_size" {}
variable "backend_minions_vm_osdisk_type" {}
variable "backend_minions_vm_osdisk_size_in_gb" {}


variable "bastion_minions_subnet_cidr" {}
