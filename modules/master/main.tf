data "azurerm_resource_group" "cluster" {
  name = "${var.resource_group_name}"
}

resource "azurerm_availability_set" "k8s-master-avset" {
  name                = "${var.resource_name_prefix}-master-avset"
  resource_group_name = "${data.azurerm_resource_group.cluster.name}"
  location            = "${data.azurerm_resource_group.cluster.location}"

  platform_fault_domain_count  = 3
  platform_update_domain_count = 10
}

// Define a public IP for Kubernetes API server. This IP and the
// corresponding DNS label can be used to communicate with the cluster.
resource "azurerm_public_ip" "k8s-api-publicip" {
  name                = "${var.resource_name_prefix}-api-publicip"
  resource_group_name = "${data.azurerm_resource_group.cluster.name}"
  location            = "${data.azurerm_resource_group.cluster.location}"

  public_ip_address_allocation = "static"
  domain_name_label            = "${var.domain_name_label}"
}

// Load balancer in front of the Kubernetes API.
resource "azurerm_lb" "k8s-api-lb" {
  name                = "${var.resource_name_prefix}-api-lb"
  resource_group_name = "${data.azurerm_resource_group.cluster.name}"
  location            = "${data.azurerm_resource_group.cluster.location}"

  frontend_ip_configuration {
    name                 = "${var.resource_name_prefix}-api-frontend"
    public_ip_address_id = "${azurerm_public_ip.k8s-api-publicip.id}"
  }
}

resource "azurerm_lb_backend_address_pool" "k8s-api-lb-bepool" {
  name                = "${var.resource_name_prefix}-api-backend"
  resource_group_name = "${data.azurerm_resource_group.cluster.name}"

  loadbalancer_id = "${azurerm_lb.k8s-api-lb.id}"
}

resource "azurerm_lb_rule" "k8s-api-lb-rule" {
  name                = "${var.resource_name_prefix}-api"
  resource_group_name = "${data.azurerm_resource_group.cluster.name}"

  backend_address_pool_id        = "${azurerm_lb_backend_address_pool.k8s-api-lb-bepool.id}"
  loadbalancer_id                = "${azurerm_lb.k8s-api-lb.id}"
  probe_id                       = "${azurerm_lb_probe.k8s-api-lb-probe.id}"
  frontend_ip_configuration_name = "${var.resource_name_prefix}-api-frontend"

  protocol                = "Tcp"
  frontend_port           = "${var.api_loadbalancer_frontend_port}"
  backend_port            = "${var.api_loadbalancer_backend_port}"
  enable_floating_ip      = false
  idle_timeout_in_minutes = 5
}

// Load balancer TCP probe that checks if the nodes are available
resource "azurerm_lb_probe" "k8s-api-lb-probe" {
  name                = "${var.resource_name_prefix}-api"
  resource_group_name = "${data.azurerm_resource_group.cluster.name}"

  loadbalancer_id     = "${azurerm_lb.k8s-api-lb.id}"
  port                = "${var.api_loadbalancer_backend_port}"
  interval_in_seconds = 5
  number_of_probes    = 2
}

// Create one public IP for each Kubernetes master node
resource "azurerm_public_ip" "k8s-master-publicip" {
  count = "${var.node_count}"

  name                = "${var.resource_name_prefix}-master-${format("%03d", count.index + 1)}-publicip"
  resource_group_name = "${data.azurerm_resource_group.cluster.name}"
  location            = "${data.azurerm_resource_group.cluster.location}"

  public_ip_address_allocation = "static"
}

// Create one network interface for each Kubernetes master node
resource "azurerm_network_interface" "k8s-master-nic" {
  count = "${var.node_count}"

  name                = "${var.resource_name_prefix}-master-${format("%03d", count.index + 1)}-nic"
  resource_group_name = "${data.azurerm_resource_group.cluster.name}"
  location            = "${data.azurerm_resource_group.cluster.location}"

  network_security_group_id = "${var.nsg_id}"
  enable_ip_forwarding      = true

  ip_configuration {
    name                          = "${var.resource_name_prefix}-master-ipconfig"
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = "${element(azurerm_public_ip.k8s-master-publicip.*.id, count.index)}"
    subnet_id                     = "${var.subnet_id}"

    load_balancer_backend_address_pools_ids = [
      "${azurerm_lb_backend_address_pool.k8s-api-lb-bepool.id}",
    ]
  }
}

data "azurerm_storage_account" "k8s" {
  name                = "${var.storage_account_name}"
  resource_group_name = "${var.resource_group_name}"
}

// Provision the configured number of virtual machines
resource "azurerm_virtual_machine" "k8s-master-vm" {
  count = "${var.node_count}"

  name                = "${var.resource_name_prefix}-master-${format("%03d", count.index + 1)}-vm"
  resource_group_name = "${data.azurerm_resource_group.cluster.name}"
  location            = "${data.azurerm_resource_group.cluster.location}"

  vm_size             = "${var.vm_size}"
  availability_set_id = "${azurerm_availability_set.k8s-master-avset.id}"

  network_interface_ids = [
    "${element(azurerm_network_interface.k8s-master-nic.*.id, count.index)}",
  ]

  storage_image_reference {
    publisher = "${var.os_image["publisher"]}"
    offer     = "${var.os_image["offer"]}"
    sku       = "${var.os_image["sku"]}"
    version   = "${var.os_image["version"]}"
  }

  storage_os_disk {
    name          = "${var.resource_name_prefix}-master-${format("%03d", count.index + 1)}-osdisk"
    vhd_uri       = "${data.azurerm_storage_account.k8s.primary_blob_endpoint}${var.storage_container_name}/master-${format("%03d", count.index + 1)}-osdisk.vhd"
    create_option = "FromImage"
    caching       = "ReadWrite"
    disk_size_gb  = "${var.os_disk_size}"
  }

  os_profile {
    computer_name  = "${var.resource_name_prefix}-master-${format("%03d", count.index + 1)}"
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
    "roles"       = "kube-master,etcd"
    "k8s-cluster" = ""
    "kube-master" = ""
    "etcd"        = ""
  }
}
