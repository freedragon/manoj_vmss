## VMSS deployment test with MSI enabled in Singapore.  
## AZ:no, PublicLB:yes, MSI:yes, MSI RBAC:yes, Custom Extension:yes, PPG:yes

resource "azurerm_resource_group" "terraformrg" {
  name     = "${var.prefix}-rg"
  location = "${var.location}"

  tags = {
  environment = "Terraform deployment"
  }
}

# Create a Proximity Placement Group
resource "azurerm_proximity_placement_group" "terraformppg" {
  name                = "TerraformPPG"
  location            = "${azurerm_resource_group.terraformrg.location}"
  resource_group_name = "${azurerm_resource_group.terraformrg.name}"

  tags = {
    environment = "Terraform Deployment"
  }
}

resource "azurerm_virtual_network" "terraformvnet" {
  name                = "${var.prefix}-vnet"
  resource_group_name = "${azurerm_resource_group.terraformrg.name}"
  location            = "${azurerm_resource_group.terraformrg.location}"
  address_space       = ["10.0.0.0/16"]
  tags = {
    environment = "Terraform Deployment"
  }
}

resource "azurerm_subnet" "terraformsubnet" {
  name                 = "vmss-subnet"
  virtual_network_name = "${azurerm_virtual_network.terraformvnet.name}"
  resource_group_name  = "${azurerm_resource_group.terraformrg.name}"
  address_prefix       = "10.0.1.0/24"
}

resource "azurerm_public_ip" "PublicLBPIP" {
  name                = "publicip"
  location            = "${azurerm_resource_group.terraformrg.location}"
  resource_group_name = "${azurerm_resource_group.terraformrg.name}"
  allocation_method   = "Dynamic"
  domain_name_label   = "${azurerm_resource_group.terraformrg.name}"
  tags = {
    environment = "Terraform Deployment"
  }
}

resource "azurerm_lb" "terraformnatlb" {
  name                = "terraformnatlb"
  location            = "${azurerm_resource_group.terraformrg.location}"
  resource_group_name = "${azurerm_resource_group.terraformrg.name}"

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = "${azurerm_public_ip.PublicLBPIP.id}"
  }
  tags = {
  environment = "Terraform deployment"
  }
}

resource "azurerm_lb_backend_address_pool" "backendpool" {
  resource_group_name = "${azurerm_resource_group.terraformrg.name}"
  loadbalancer_id     = "${azurerm_lb.terraformnatlb.id}"
  name                = "BackEndAddressPool"
}

resource "azurerm_lb_nat_pool" "lbnatpool" {
  resource_group_name            = "${azurerm_resource_group.terraformrg.name}"
  name                           = "ssh"
  loadbalancer_id                = "${azurerm_lb.terraformnatlb.id}"
  protocol                       = "Tcp"
  frontend_port_start            = 50000
  frontend_port_end              = 50119
  backend_port                   = 22
  frontend_ip_configuration_name = "PublicIPAddress"
}


resource "azurerm_virtual_machine_scale_set" "terraformvmss" {
  name                = "${var.prefix}"
  location            = "${azurerm_resource_group.terraformrg.location}"
  resource_group_name = "${azurerm_resource_group.terraformrg.name}"
  upgrade_policy_mode = "Manual"
  proximity_placement_group_id = "${azurerm_proximity_placement_group.terraformppg.id}"

  sku {
    name     = "Standard_D1_v2"
    tier     = "Standard"
    capacity = 1
  }

  os_profile {
    computer_name_prefix = "${var.prefix}"
    admin_username       = "myadmin"
    admin_password       = "Password1234"
  }
  
  os_profile_linux_config {
    disable_password_authentication = true
            ssh_keys {
            path     = "/home/myadmin/.ssh/authorized_keys"
            key_data = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCczY+8XfyQ3vc6kvCUMM10pTWKAUhsvKV82OUK8qjWMnG5De7zUGJ+KeLY75+zxQAZt7gkwUBudDNTK6HmEyUQ9W/q5KmvEqfa641CwFuksj2umXCkIyFcm0mAhAIxcKah8SwVfSl2zJlp/dqoSCBpzGFXEIYp4OtBiQTAjupAeLPYwKtXdUXzjmMzfhSpY4H4EYJzgzt/eS2thYMgOtvv5kr3/Xbee70STNVyoliSUHhW5EpDOmgD7/TRGAy+OqRUoqtyRMDByfRKHT62r+OcmZUpUiylnVllhmQyLYuLCXDZIqRTVfQv0G2QoCIV7CsJ0XG7bmalbp+D/bdgugsN"
        }
  }

  network_profile {
    name    = "ssh_publiclb_profile"
    primary = true

    ip_configuration {
      name      = "internal"
      subnet_id = "${azurerm_subnet.terraformsubnet.id}"
      primary   = true
      load_balancer_inbound_nat_rules_ids    = ["${azurerm_lb_nat_pool.lbnatpool.id}"]
    }
  }

  storage_profile_os_disk {
    name              = ""
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  storage_profile_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }
  identity {
    type = "SystemAssigned"
  }
  extension {
    name                 = "bootstrap"
    publisher            = "Microsoft.Azure.Extensions"
    type                 = "CustomScript"
    type_handler_version = "2.0"

    settings = <<SETTINGS
    {
        "fileUris": ["https://raw.githubusercontent.com/bedro96/manoj_vmss/master/setup.sh"],
        "commandToExecute": "/bin/bash ./setup.sh"
    }
    SETTINGS
  }
  tags = {
    environment = "Terraform deployment"
  }
  
}

resource "azurerm_role_assignment" "terraformmsirole" {
  scope              = "${azurerm_resource_group.terraformrg.id}"
  role_definition_name = "Contributor"
  principal_id       = "${lookup(azurerm_virtual_machine_scale_set.terraformvmss.identity[0], "principal_id")}"
}

output "public_ip_addr" {
  value = azurerm_public_ip.PublicLBPIP.ip_address
}