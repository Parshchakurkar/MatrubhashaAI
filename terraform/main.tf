resource "azurerm_resource_group" "matrubhashaai-rg" {
  name     = var.resourcegroupname
  location = var.location
}

resource "azurerm_virtual_network" "matrubhashaai-vnet" {
  name                = "matrubhashaai-vnet"
  location            = azurerm_resource_group.matrubhashaai-rg.location
  resource_group_name = azurerm_resource_group.matrubhashaai-rg.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "matrubhashaai-subnet" {
  name                 = "matrubhashaai-subnet"
  resource_group_name  = azurerm_resource_group.matrubhashaai-rg.name
  virtual_network_name = azurerm_virtual_network.matrubhashaai-vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "pip" {
  name                = "matrubhashaai-pip"
  resource_group_name = azurerm_resource_group.matrubhashaai-rg.name
  location            = azurerm_resource_group.matrubhashaai-rg.location
  allocation_method   = "Static"
  depends_on          = [azurerm_resource_group.matrubhashaai-rg]
}
resource "azurerm_network_interface" "matrubhashaai-nic" {
  name                = "matrubhashaai-nic"
  location            = azurerm_resource_group.matrubhashaai-rg.location
  resource_group_name = azurerm_resource_group.matrubhashaai-rg.name
  ip_configuration {
    name                          = "matrubhashaa-ip-config"
    subnet_id                     = azurerm_subnet.matrubhashaai-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id
  }
  depends_on = [azurerm_virtual_network.matrubhashaai-vnet, azurerm_public_ip.pip]
}

#public IP

resource "azurerm_network_security_group" "webserver" {
  name                = "matrubhashaai_webserver"
  location            = azurerm_resource_group.matrubhashaai-rg.location
  resource_group_name = azurerm_resource_group.matrubhashaai-rg.name
  security_rule {
    name                       = "AllowSSH"
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

resource "azurerm_network_interface_security_group_association" "mamatrubhashaaisgs" {
  network_interface_id      = azurerm_network_interface.matrubhashaai-nic.id
  network_security_group_id = azurerm_network_security_group.webserver.id
}

# virtual machine details
resource "azurerm_linux_virtual_machine" "matrubhashaai-vm" {
  admin_username        = "adminuser"
  location              = azurerm_resource_group.matrubhashaai-rg.location
  name                  = "matrubhashaai-vm"
  resource_group_name   = azurerm_resource_group.matrubhashaai-rg.name
  size                  = "Standard_DS1"
  network_interface_ids = [azurerm_network_interface.matrubhashaai-nic.id]
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  #Basic SSH
  admin_ssh_key {
    username   = "adminuser"
    public_key = file("/Users/parsh/.ssh/id_rsa.pub")
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

}

# Configure Agent
resource "azurerm_virtual_machine_extension" "agent_install" {
  name                 = "devops-agent-extension"
  virtual_machine_id   = azurerm_linux_virtual_machine.matrubhashaai-vm.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.1"

  settings           = <<SETTINGS
    {
      "fileUris": [], 
      "commandToExecute": "bash -c '${base64encode(file("${path.module}/createagent.sh"))}'"
    }
    SETTINGS
}