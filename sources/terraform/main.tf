provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "votre nom de ressource ici"
  location = "East US"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "myVNet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "mySubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "public_ip" {
  name                = "myPublicIP"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "nic" {
  name                = "example-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id
  }
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                = "minikubeVM"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_DS2_v2"
  admin_username      = "azureuser"
  admin_password      = "votre mot de passe ici"
  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  disable_password_authentication = false

  tags = {
    environment = "Testing"
  }
}

resource "azurerm_network_security_group" "nsg" {
  name                = "myNetworkSecurityGroup"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_network_security_rule" "ssh" {
  name                        = "SSH"
  priority                    = 1001
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

resource "azurerm_network_security_rule" "http" {
  name                        = "HTTP"
  priority                    = 1002
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

resource "azurerm_network_security_rule" "minikube" {
  name                        = "Minikube"
  priority                    = 1003
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "30000-32767"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

resource "azurerm_network_interface_security_group_association" "association" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

data "azurerm_public_ip" "vm_public_ip" {
  name                = azurerm_public_ip.public_ip.name
  resource_group_name = azurerm_resource_group.rg.name
  depends_on = [azurerm_linux_virtual_machine.vm]
}

resource "null_resource" "vm_provisioner" {
  depends_on = [azurerm_linux_virtual_machine.vm]

  provisioner "file" {
    source      = "/home/dobe/.ssh/id_rsa"
    destination = "/home/azureuser/.ssh/id_rsa"
    connection {
      type     = "ssh"
      user     = "azureuser"
      password = "votre mot de passe ici"
      host     = data.azurerm_public_ip.vm_public_ip.ip_address
      timeout  = "5m"
    }
  }

  provisioner "file" {
    source      = "/home/dobe/.ssh/id_rsa.pub"
    destination = "/home/azureuser/.ssh/id_rsa.pub"
    connection {
      type     = "ssh"
      user     = "azureuser"
      password = "votre mot de passe ici"
      host     = data.azurerm_public_ip.vm_public_ip.ip_address
      timeout  = "5m"
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update -y",
      "sudo apt-get install -y git",
      "chmod 600 /home/azureuser/.ssh/id_rsa",
      "ssh-keyscan github.com >> /home/azureuser/.ssh/known_hosts",
      "git clone votre github ici /home/azureuser/Projet_Complet_DevOps"
    ]
    connection {
      type     = "ssh"
      user     = "azureuser"
      password = "Mot de passe ici"
      host     = data.azurerm_public_ip.vm_public_ip.ip_address
      timeout  = "5m"
    }
  }
}
