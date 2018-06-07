resource_group_name = "kubernauts"
resource_name_prefix = "k8s"

// admin username and public key for connection via SSH
admin_username = "centos"
admin_public_key = "ssh-rsa ..."

// Azure service principal for self-configuration
vnet_cidr = "10.111.48.0/21"

// API server load balancer configuration
api_loadbalancer_frontend_port = 443
api_loadbalancer_backend_port = 6443

// Storage
storage_account_tier = "Standard"
storage_replication_type = "LRS"

// Configure CoreOS VM image
#vm_image_publisher = "CoreOS"
#vm_image_offer = "CoreOS"
#vm_image_sku = "Stable"
#vm_image_version = "latest"

// Configure CentOS VM image
vm_image_publisher = "OpenLogic"
vm_image_offer = "CentOS"
vm_image_sku = "7.4"
vm_image_version = "latest"


// Kubernetes master configuration
master_count = 1
#master_vm_size = "Standard_A4_v2"
master_vm_size = "Standard_B2ms"
master_vm_osdisk_type = "Standard_LRS"
master_vm_osdisk_size_in_gb = "250"
master_subnet_cidr = "10.111.53.0/24"
master_first_ip = "10.111.53.4"

// Kubernetes agent pool "services"
service_minions_count = 1
#service_minions_vm_size = "Standard_A4m_v2"
service_minions_vm_size = "Standard_B2ms"
service_minions_vm_osdisk_type = "Standard_LRS"
service_minions_vm_osdisk_size_in_gb = "250"
service_minions_subnet_cidr = "10.111.48.0/22"

// Kubernetes agent pool "backend"
backend_minions_count = 1
#backend_minions_vm_size = "Standard_A4m_v2"
backend_minions_vm_size = "Standard_B2ms"
backend_minions_vm_osdisk_type = "Standard_LRS"
backend_minions_vm_osdisk_size_in_gb = "100"
backend_minions_subnet_cidr = "10.111.52.0/24"

// Bastion Ansible host CIDR

bastion_minions_subnet_cidr = "10.111.54.0/24"