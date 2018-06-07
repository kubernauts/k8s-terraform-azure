variable "name" {
   default = "bastion"
  type = "string"

  description = <<EOF
(mandatory) Will be part of the created resources names.
Example: For the first provisioned VM the name would be "k8s-pool-{name}-0-vm".
EOF
}

variable "resource_group_name" {
  type = "string"

  description = <<EOF
(mandatory) Name of the resource group the infrastructure will be created in.
Notice that the location of all provisioned resources will be set equal to the
location of the passed resource_group_name.
EOF
}

variable "resource_name_prefix" {
  default = "k8s"

  description = <<EOF
(optional) Prefix that gets prepended to any resource created by this module. Default: k8s
Example: Using the default value, the name of the first provisioned master VM would be "k8s-master-0-vm".
EOF
}

variable "storage_account_name" {
  description = <<EOF
(mandatory) Name of the storage account that will hold VHDs for master and minion nodes.
EOF
}

variable "storage_container_name" {
  description = <<EOF
(mandatory) Name of the storage container that will hold VHDs for master and minion nodes.
EOF
}

variable "create_public_ips" {
  description = <<EOF
(optional) If set to true, a public IP address will be provisioned for each provisioned node. Default: true
EOF

  default = true
}

variable "node_count" {
  type = "string"

  description = <<EOF
(optional) The number of nodes created within this agent pool. Default: 3
EOF

  default = "3"
}

variable "subnet_id" {
  type = "string"

  description = <<EOF
(optional) Subnet ID within an existing VNet to deploy master nodes into.
Required to use an existing VNet.
Note this is the complete ID as returned in the "id" field by the Azure client, not just the name of the resource.
Example: "/subscriptions/b520eabf-d6c0-4757-8a5e-0fa7d2fe12b5/resourceGroups/my-k8s-cluster/providers/Microsoft.Network/virtualNetworks/test-pre-vnet/subnets/my-k8s-subnet
EOF
}

variable "nsg_id" {
  type = "string"

  description = <<EOF
(optional) The ID of the external Network Security Group used for masters.
Leave blank to have a new one created.
Note this is the complete ID as returned in the "id" field by the Azure client, not just the name of the resource.
Example: "/subscriptions/b520eabf-d6c0-4757-8a5e-0fa7d2fe12b5/resourceGroups/my-k8s-cluster/providers/Microsoft.Network/networkSecurityGroups/my-master-nsg
EOF

  default = ""
}

variable "vm_size" {
  type = "string"

  description = <<EOF
(Optional) Size of the created virtual machines. Default: Standard_B4ms
If you consider using a storage class that creates a dedicated disk or storage account
per PVC (persistent volume claim), remind that you have to choose a VM size that
provides an adequate number of usable data disk slots.
EOF

  default = "Standard_B4ms"
}

variable "os_image" {
  type = "map"

  description = <<EOF
(optional) OS image that will be installed on the created virtual machines.
Default: {
  publisher = "OpenLogic"
  offer = "CentOS"
  sku = "7.4"
  version = "latest"
}
EOF

  default = {
    publisher = "OpenLogic"
    offer     = "CentOS"
    sku       = "7.4"
    version   = "latest"
  }
}

variable "os_disk_storage_type" {
  type = "string"

  description = <<EOF
(optional) Storage account type for the node(s). Default: Premium_LRS (SSD-backed storage).
Using Premium storage is constrained by the of instance specified in 'vm_size'.
See https://docs.microsoft.com/en-us/azure/storage/storage-premium-storage#supported-vms
EOF

  default = "Premium_LRS"
}

variable "os_disk_size" {
  type = "string"

  description = <<EOF
(optional) Size of the OS disk in gigabytes. Default: 100
EOF

  default = "100"
}

variable "admin_username" {
  type = "string"

  description = <<EOF
(mandatory) Name of the administrator user created on the provisioned machines.
EOF
}

variable "admin_public_key" {
  type = "string"

  description = <<EOF
(mandatory) An SSH public key to install on the provisioned machines.
Required because password authentication is disabled by default.
EOF
}
