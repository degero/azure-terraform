variable "resource_group_name" {
  description = "Name of the resource group to deploy into"
  type        = string
}

variable "environment" {
  type = string
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "australiaeast"
}

variable "app_name" {
  type = string
}

variable "admin_username" {
  type        = string
  description = "Administrator user name for virtual machine"
}

variable "vm_os_sku" {
  description = "SKU per region for the Ubuntu image (region => sku)"
  type        = map(string)
  default = {
    australiaeast = "18.04-LTS"
  }
}

variable "tags" {
  type    = map(string)
  default = {}
}


module "naming" {
  source = "Azure/naming/azurerm"
  suffix = [var.app_name, var.environment]
}

# Create a virtual network
resource "azurerm_virtual_network" "vnet" {
  name                = module.naming.virtual_network.name
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# Create subnet
resource "azurerm_subnet" "subnet" {
  name                 = module.naming.subnet.name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create public IP
resource "azurerm_public_ip" "publicip" {
  name                = module.naming.public_ip.name
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  tags                = var.tags
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "nsg" {
  name                = module.naming.public_ip.name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Create network interface
resource "azurerm_network_interface" "nic" {
  name                = module.naming.network_interface.name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  ip_configuration {
    name                          = "myNICConfg"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.publicip.id
  }
}

resource "random_password" "vm_admin" {
  length  = 20
  special = true
}

# Create a Linux virtual machine
resource "azurerm_virtual_machine" "vm" {
  name                  = module.naming.virtual_machine.name
  location              = var.location
  resource_group_name   = var.resource_group_name
  network_interface_ids = [azurerm_network_interface.nic.id]
  vm_size               = "Standard_B1ls"
  tags                  = var.tags

  storage_os_disk {
    name              = module.naming.managed_disk.name
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
  }

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = lookup(var.vm_os_sku, var.location)
    version   = "latest"
  }

  os_profile {
    computer_name  = module.naming.virtual_machine.name
    admin_username = var.admin_username
    admin_password = random_password.vm_admin.result
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }
}

data "azurerm_public_ip" "ip" {
  name                = azurerm_public_ip.publicip.name
  resource_group_name = azurerm_virtual_machine.vm.resource_group_name
  depends_on          = [azurerm_virtual_machine.vm]
}

output "public_ip_address" {
  value = data.azurerm_public_ip.ip.ip_address
}

output "password" {
  value     = random_password.vm_admin.result
  sensitive = true
  ephemeral = true
}
