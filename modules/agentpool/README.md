# Example

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