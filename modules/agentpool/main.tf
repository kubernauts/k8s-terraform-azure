// Load information about the configured resource group
data "azurerm_resource_group" "cluster" {
  name = "${var.resource_group_name}"
}

// Create an availability set for the provisioned nodes
resource "azurerm_availability_set" "k8s-service-minion-avset" {
  count               = "${var.node_count == 0 ? 0 : 1}"
  name                = "${var.resource_name_prefix}-pool-${var.name}-avset"
  resource_group_name = "${data.azurerm_resource_group.cluster.name}"
  location            = "${data.azurerm_resource_group.cluster.location}"

  platform_fault_domain_count  = 3
  platform_update_domain_count = 10
}

// Create one public IP for each node in the 'service' agent pool
resource "azurerm_public_ip" "k8s-service-minion-publicip" {
  count               = "${var.node_count}"
  name                = "${var.resource_name_prefix}-pool-${var.name}-${format("%03d", count.index + 1)}-publicip"
  resource_group_name = "${data.azurerm_resource_group.cluster.name}"
  location            = "${data.azurerm_resource_group.cluster.location}"

  public_ip_address_allocation = "static"
}

// Create one network interface for each node in the 'service' agent pool
resource "azurerm_network_interface" "k8s-service-minion-nic" {
  count               = "${var.node_count}"
  name                = "${var.resource_name_prefix}-pool-${var.name}-${format("%03d", count.index + 1)}-nic"
  resource_group_name = "${data.azurerm_resource_group.cluster.name}"
  location            = "${data.azurerm_resource_group.cluster.location}"

  network_security_group_id = "${var.nsg_id}"
  enable_ip_forwarding      = true

  ip_configuration {
    name                          = "${var.resource_name_prefix}-pool-${var.name}-ipconfig"
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = "${element(azurerm_public_ip.k8s-service-minion-publicip.*.id, count.index)}"
    subnet_id                     = "${var.subnet_id}"
  }
}

data "azurerm_storage_account" "k8s" {
  name                = "${var.storage_account_name}"
  resource_group_name = "${var.resource_group_name}"
}

resource "azurerm_virtual_machine" "k8s-service-minion-vm" {
  count               = "${var.node_count}"
  name                = "${var.resource_name_prefix}-pool-${var.name}-${format("%03d", count.index + 1)}-vm"
  resource_group_name = "${data.azurerm_resource_group.cluster.name}"
  location            = "${data.azurerm_resource_group.cluster.location}"

  vm_size             = "${var.vm_size}"
  availability_set_id = "${azurerm_availability_set.k8s-service-minion-avset.id}"

  network_interface_ids = [
    "${element(azurerm_network_interface.k8s-service-minion-nic.*.id, count.index)}",
  ]

  storage_image_reference {
    publisher = "${var.os_image["publisher"]}"
    offer     = "${var.os_image["offer"]}"
    sku       = "${var.os_image["sku"]}"
    version   = "${var.os_image["version"]}"
  }

  storage_os_disk {
    name          = "${var.resource_name_prefix}-pool-${var.name}-${format("%03d", count.index + 1)}-osdisk"
    vhd_uri       = "${data.azurerm_storage_account.k8s.primary_blob_endpoint}${var.storage_container_name}/pool-${var.name}-${format("%03d", count.index + 1)}-osdisk.vhd"
    create_option = "FromImage"
    caching       = "ReadWrite"
    disk_size_gb  = "${var.os_disk_size}"
  }

  os_profile {
    computer_name  = "${var.resource_name_prefix}-pool-${var.name}-${format("%03d", count.index + 1)}"
    admin_username = "${var.admin_username}"
  }

  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      path     = "/home/${var.admin_username}/.ssh/authorized_keys"
      key_data = "${var.admin_public_key}"
    }
  }

  tags {
    "roles"       = "kube-node"
    "k8s-cluster" = ""
    "kube-node"   = ""
  }
}
