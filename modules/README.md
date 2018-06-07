# Kubernetes Terraform module

This module and its submodules `agentpool`, `master` and `bastion` provisions 
all the necessary infrastructure for running a Kubernetes cluster deployed with Kubespray. 

## Module: kubernetes/master

The `kubernetes/master`-module provisions the following infrastructure:

- An Availability set for master VMs
- An Azure Load Balancer (L3) for Kubernetes API access.
  Includes a backend address pool where the provisioned VMs/NICs will automatically
  register themselves.
- (If configured) a public IP address attached to the load balancer.
- Configured amount of virtual machines and one network interface per machine

### Usage example

The following configuration provisions three Kubernetes master VMs running Centos 7.4:

```
module "kubernetes-master" {
  source = "modules/kubernetes/master"

  resource_group_name = "${azurerm_resource_group.k8s.name}"
  resource_name_prefix = "${var.resource_name_prefix}"

  node_count = "${var.master_count}"

  subnet_id = "${azurerm_subnet.k8s-master-subnet.id}"
  nsg_id = "${azurerm_network_security_group.k8s-nsg.id}"
  create_public_ips = true
  dns_prefix = "${azurerm_resource_group.k8s.name}"

  vm_size = "${var.master_vm_size}"

  os_image = {
	publisher = "${var.master_vm_image_publisher}"
	offer = "${var.master_vm_image_offer}"
	sku = "${var.master_vm_image_sku}"
	version = "${var.master_vm_image_version}"
  }

  os_disk_storage_type = "${var.master_vm_osdisk_type}"
  os_disk_size = "${var.master_vm_osdisk_size_in_gb}"

  admin_username = "${var.admin_username}"
  admin_public_key = "${var.admin_public_key}"

  kube_api_ssl_port = 6443
}
```

## Module: kubernetes/agentpool

### Usage example

```
module "kubernetes-agentpool-services" {
  source = "../modules/kubernetes/agentpool"

  name = "services"

  resource_group_name = "${azurerm_resource_group.k8s.name}"
  resource_name_prefix = "k8s"

  node_count = 3

  subnet_id = "${azurerm_subnet.k8s-services-subnet.id}"
  nsg_id = "${azurerm_network_security_group.k8s-nsg.id}"
  create_public_ips = true

  vm_size = "Standard_A8_v2"

  os_image = {
	publisher = "OpenLogic"
	offer = "CentOS"
	sku = "7.4"
	version = "latest"
  }

  os_disk_storage_type = "Premium_LRS"
  os_disk_size = 250

  admin_username = "${var.admin_username}"
  admin_public_key = "${var.admin_public_key}"
}
```

## Module: kubernetes/bastion
