
provider "azurerm" {
  version         = ">= 1.3.0"

  subscription_id = "${var.azure_subscription_id}"
  tenant_id       = "${var.azure_tenant_id}"
}

# -----------------------------------------------------------------
# CREATE RESOURCE GROUP
# -----------------------------------------------------------------
resource "azurerm_resource_group" "kubernauts" {
  name     = "${var.resource_group_name}"
  location = "${var.azure_location}"

  tags {
    Contact = "kubernauts.io"
  }
}

# -----------------------------------------------------------------
# SETUP VIRTUAL NETWORKS WITH SUBNETS FOR MINIONS AND MASTERS
# -----------------------------------------------------------------
resource "azurerm_virtual_network" "k8s-vnet" {
  name                = "${var.resource_name_prefix}-vnet"
  resource_group_name = "${azurerm_resource_group.kubernauts.name}"
  location            = "${var.azure_location}"

  address_space       = [
    "${var.vnet_cidr}",
  ]
}

resource "azurerm_subnet" "k8s-master-subnet" {
  name                 = "${var.resource_name_prefix}-master-subnet"
  resource_group_name  = "${azurerm_resource_group.kubernauts.name}"

  virtual_network_name = "${azurerm_virtual_network.k8s-vnet.name}"
  address_prefix       = "${var.master_subnet_cidr}"
  route_table_id       = "${azurerm_route_table.k8s-routetable.id}"
}

resource "azurerm_subnet" "k8s-services-subnet" {
  name                 = "${var.resource_name_prefix}-services-subnet"
  resource_group_name  = "${azurerm_resource_group.kubernauts.name}"

  virtual_network_name = "${azurerm_virtual_network.k8s-vnet.name}"
  address_prefix       = "${var.service_minions_subnet_cidr}"
  route_table_id       = "${azurerm_route_table.k8s-routetable.id}"
}

resource "azurerm_subnet" "k8s-backend-subnet" {
  name                 = "${var.resource_name_prefix}-backend-subnet"
  resource_group_name  = "${azurerm_resource_group.kubernauts.name}"

  virtual_network_name = "${azurerm_virtual_network.k8s-vnet.name}"
  address_prefix       = "${var.backend_minions_subnet_cidr}"
  route_table_id       = "${azurerm_route_table.k8s-routetable.id}"
}

resource "azurerm_subnet" "k8s-bastion-subnet" {
  name                 = "${var.resource_name_prefix}-bastion-subnet"
  resource_group_name  = "${azurerm_resource_group.kubernauts.name}"

  virtual_network_name = "${azurerm_virtual_network.k8s-vnet.name}"
  address_prefix       = "${var.bastion_minions_subnet_cidr}"
  route_table_id       = "${azurerm_route_table.k8s-routetable.id}"
}

resource "azurerm_route_table" "k8s-routetable" {
  name                = "${var.resource_name_prefix}-routetable"
  resource_group_name = "${azurerm_resource_group.kubernauts.name}"
  location            = "${var.azure_location}"
}

resource "azurerm_network_security_group" "k8s-nsg" {
  name                = "${var.resource_name_prefix}-nsg"
  resource_group_name = "${azurerm_resource_group.kubernauts.name}"
  location            = "${var.azure_location}"

  security_rule {
    name                       = "pub_inbound_22_tcp_ssh"
    description                = "Allows inbound internet traffic to 22/TCP (SSH daemon)"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
    access                     = "Allow"
    priority                   = 100
    direction                  = "Inbound"
  }

  security_rule {
    name                       = "pub_inbound_tcp_kubeapi"
    description                = "Allows inbound internet traffic to ${var.api_loadbalancer_frontend_port}/TCP (Kubernetes API SSL port)"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "${var.api_loadbalancer_frontend_port}"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
    access                     = "Allow"
    priority                   = 101
    direction                  = "Inbound"
  }
}

# -----------------------------------------------------------------
# CREATE STORAGE ACCOUNT FOR VM OS VHD-FILES
# -----------------------------------------------------------------
resource "random_id" "k8s-storage-account" {
  keepers     = {
    resource_group = "${azurerm_resource_group.kubernauts.id}"
  }

  byte_length = 8
}

resource "azurerm_storage_account" "k8s" {
  name                      = "k8s${lower(random_id.k8s-storage-account.hex)}"
  resource_group_name       = "${azurerm_resource_group.kubernauts.name}"
  location                  = "${azurerm_resource_group.kubernauts.location}"

  account_kind              = "Storage"
  account_tier              = "${var.storage_account_tier}"

  enable_https_traffic_only = true
  enable_blob_encryption    = true
  enable_file_encryption    = true
  account_replication_type  = "${var.storage_replication_type}"
}

resource "azurerm_storage_container" "k8s-vhds" {
  name                 = "vhds"
  resource_group_name  = "${azurerm_resource_group.kubernauts.name}"
  storage_account_name = "${azurerm_storage_account.k8s.name}"
}

# -----------------------------------------------------------------
# CREATE KUBERNETES MASTER NODES
# -----------------------------------------------------------------
module "kubernetes-master" {
  source                         = "modules/master"

  resource_group_name            = "${azurerm_resource_group.kubernauts.name}"
  resource_name_prefix           = "${var.resource_name_prefix}"
  storage_account_name           = "${azurerm_storage_account.k8s.name}"
  storage_container_name         = "${azurerm_storage_container.k8s-vhds.name}"
  domain_name_label              = "scs-${azurerm_resource_group.kubernauts.name}"

  node_count                     = "${var.master_count}"

  subnet_id                      = "${azurerm_subnet.k8s-master-subnet.id}"
  nsg_id                         = "${azurerm_network_security_group.k8s-nsg.id}"
  create_public_ips              = true

  vm_size                        = "${var.master_vm_size}"

  os_image                       = {
    publisher = "${var.vm_image_publisher}"
    offer     = "${var.vm_image_offer}"
    sku       = "${var.vm_image_sku}"
    version   = "${var.vm_image_version}"
  }

  os_disk_storage_type           = "${var.master_vm_osdisk_type}"
  os_disk_size                   = "${var.master_vm_osdisk_size_in_gb}"

  admin_username                 = "${var.admin_username}"
  admin_public_key               = "${var.admin_public_key}"

  api_loadbalancer_frontend_port = "${var.api_loadbalancer_frontend_port}"
  api_loadbalancer_backend_port  = "${var.api_loadbalancer_backend_port}"
}

# -----------------------------------------------------------------
# CREATE KUBERNETES SERVICE AGENTPOOL
# This backend pool is dedicated for running user- or client-facing
# services and applications.
# -----------------------------------------------------------------
module "kubernetes-agentpool-services" {
  source                 = "modules/agentpool"

  name                   = "services"

  resource_group_name    = "${azurerm_resource_group.kubernauts.name}"
  resource_name_prefix   = "${var.resource_name_prefix}"
  storage_account_name   = "${azurerm_storage_account.k8s.name}"
  storage_container_name = "${azurerm_storage_container.k8s-vhds.name}"

  node_count             = "${var.service_minions_count}"

  subnet_id              = "${azurerm_subnet.k8s-services-subnet.id}"
  nsg_id                 = "${azurerm_network_security_group.k8s-nsg.id}"
  create_public_ips      = false

  vm_size                = "${var.service_minions_vm_size}"

  os_image               = {
    publisher = "${var.vm_image_publisher}"
    offer     = "${var.vm_image_offer}"
    sku       = "${var.vm_image_sku}"
    version   = "${var.vm_image_version}"
  }

  os_disk_storage_type   = "${var.service_minions_vm_osdisk_type}"
  os_disk_size           = "${var.service_minions_vm_osdisk_size_in_gb}"

  admin_username         = "${var.admin_username}"
  admin_public_key       = "${var.admin_public_key}"
}

# -----------------------------------------------------------------
# CREATE KUBERNETES BACKEND AGENTPOOL
# This backend pool is dedicated for running backend-services
# like databases, message queues, cronjobs, etc.
# -----------------------------------------------------------------
module "kubernetes-agentpool-backend" {
  source                 = "modules/agentpool"

  name                   = "backend"

  resource_group_name    = "${azurerm_resource_group.kubernauts.name}"
  resource_name_prefix   = "${var.resource_name_prefix}"
  storage_account_name   = "${azurerm_storage_account.k8s.name}"
  storage_container_name = "${azurerm_storage_container.k8s-vhds.name}"

  node_count             = "${var.backend_minions_count}"

  subnet_id              = "${azurerm_subnet.k8s-backend-subnet.id}"
  nsg_id                 = "${azurerm_network_security_group.k8s-nsg.id}"
  create_public_ips      = false

  vm_size                = "${var.backend_minions_vm_size}"

  os_image               = {
    publisher = "${var.vm_image_publisher}"
    offer     = "${var.vm_image_offer}"
    sku       = "${var.vm_image_sku}"
    version   = "${var.vm_image_version}"
  }

  os_disk_storage_type   = "${var.backend_minions_vm_osdisk_type}"
  os_disk_size           = "${var.backend_minions_vm_osdisk_size_in_gb}"

  admin_username         = "${var.admin_username}"
  admin_public_key       = "${var.admin_public_key}"
}

# -----------------------------------------------------------------
# CREATE ANSIBLE BASTION HOST
# -----------------------------------------------------------------
module "bastion" {
  source                 = "modules/bastion"

  name                   = "bastion"

  resource_group_name    = "${azurerm_resource_group.kubernauts.name}"
  resource_name_prefix   = "${var.resource_name_prefix}"
  storage_account_name   = "${azurerm_storage_account.k8s.name}"
  storage_container_name = "${azurerm_storage_container.k8s-vhds.name}"

  node_count             = "1"

  subnet_id              = "${azurerm_subnet.k8s-bastion-subnet.id}"
  nsg_id                 = "${azurerm_network_security_group.k8s-nsg.id}"
  create_public_ips      = true

  vm_size                = "${var.backend_minions_vm_size}"

  os_image               = {
    publisher = "${var.vm_image_publisher}"
    offer     = "${var.vm_image_offer}"
    sku       = "${var.vm_image_sku}"
    version   = "${var.vm_image_version}"
  }

  os_disk_storage_type   = "${var.backend_minions_vm_osdisk_type}"
  os_disk_size           = "${var.backend_minions_vm_osdisk_size_in_gb}"

  admin_username         = "${var.admin_username}"
  admin_public_key       = "${var.admin_public_key}"
}

