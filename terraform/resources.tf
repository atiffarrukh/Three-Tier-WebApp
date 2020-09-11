##################################################################################
# DATA
##################################################################################

data "template_file" "subnets" {
  count = var.subnet_count

  template = "$${cidrsubnet(vnet_cidr, 8, current_count)}"

  vars = {
    vnet_cidr     = var.address_space
    current_count = count.index
  }
}

##################################################################################
# RESOURCES
##################################################################################

resource "random_integer" "rand" {
  min = 10000
  max = 99999
}

data "azurerm_shared_image_version" "iis-image" {
  name                = "1.0.0"
  image_name          = "windows-2016-datacenter-bareIIS"
  gallery_name        = "mySharedImageGallery"
  resource_group_name = "general-rg"
}


# shared image 
resource "azurerm_shared_image" "shared-image" {
  name                = "myAppName"
  gallery_name        = "mySharedImageGallery"
  resource_group_name = "general-rg"
  location            = var.location
  os_type             = "Windows"

  identifier {
    publisher = "Pacsquare"
    offer     = "myAppName"
    sku       = "Latest"
  }
}

#resource group
resource "azurerm_resource_group" "myAppName-rg" {
  name     = "${var.resource_group_name}-${terraform.workspace}-rg"
  location = var.location
  tags     = local.common_tags
}

# storage account
resource "azurerm_storage_account" "myAppName-sa" {
  name                     = "myAppNamestrorage${random_integer.rand.result}"
  resource_group_name      = azurerm_resource_group.myAppName-rg.name
  location                 = azurerm_resource_group.myAppName-rg.location
  account_tier             = "Standard"
  account_replication_type = "GRS"

  tags = {
    environment = "staging"
  }
}

#container
resource "azurerm_storage_container" "video-container" {
  name                  = "video-conversation"
  storage_account_name  = azurerm_storage_account.myAppName-sa.name
  container_access_type = "private"
}

#sas
data "azurerm_storage_account_blob_container_sas" "blob-sas" {
  connection_string = azurerm_storage_account.myAppName-sa.primary_connection_string
  container_name    = azurerm_storage_container.video-container.name
  https_only        = true

  start  = "2020-03-21"
  expiry = "2018-03-21"

  permissions {
    read   = true
    add    = true
    create = false
    write  = true
    delete = true
    list   = true
  }

  cache_control = "max-age=5"
  content_type  = "application/json"
}

#vnet
module "vnet" {
  vnet_name           = var.vnet_name
  source              = "Azure/vnet/azurerm"
  resource_group_name = azurerm_resource_group.myAppName-rg.name
  address_space       = [var.address_space]
  subnet_prefixes     = data.template_file.subnets[*].rendered
  subnet_names        = var.subnet_names
  nsg_ids = {
    frontend        = azurerm_network_security_group.default-nsg.id
    frontend-app-gw = azurerm_network_security_group.default-nsg.id
    bastion         = azurerm_network_security_group.bastion-nsg.id
    backend         = azurerm_network_security_group.bastion-nsg.id
    backend-app-gw  = azurerm_network_security_group.bastion-nsg.id
  }
  tags = local.common_tags
}

# bastion nsg
resource "azurerm_network_security_group" "bastion-nsg" {
  name                = "bastion-nsg"
  location            = var.location
  resource_group_name = azurerm_resource_group.myAppName-rg.name
  tags                = local.common_tags
  security_rule {
    name                       = "allow-ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

#application gateway nsg
resource "azurerm_network_security_group" "default-nsg" {
  name                = "vmss_nsg"
  location            = var.location
  resource_group_name = azurerm_resource_group.myAppName-rg.name
  tags                = local.common_tags
  security_rule {
    name                       = "allow-rdp"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "allow-http"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "allow-https"
    priority                   = 210
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "allow-health-probes"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "65503-65534"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "allow-ansible-connection"
    priority                   = 400
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "5986"
    source_address_prefix      = data.template_file.subnets[2].rendered
    destination_address_prefix = "*"
  }
}

#ip addresses
resource "azurerm_public_ip" "pip" {
  count               = var.public_ip_count
  name                = "${var.public_ip_names[count.index]}-pip"
  location            = var.location
  resource_group_name = azurerm_resource_group.myAppName-rg.name
  allocation_method   = "Dynamic"
  domain_name_label   = count.index == 0 ? "myAppName-${terraform.workspace}" : "myAppName-bastion-${terraform.workspace}"
  tags                = local.common_tags
}

#bastion-vm-nic
resource "azurerm_network_interface" "bastion-vm-nic" {
  name                = "bastion-vm-nic"
  location            = azurerm_resource_group.myAppName-rg.location
  resource_group_name = azurerm_resource_group.myAppName-rg.name
  ip_configuration {
    name                          = "internal"
    subnet_id                     = module.vnet.vnet_subnets[2]
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip[1].id
  }
}

#bastion-host vm
resource "azurerm_linux_virtual_machine" "bastion-vm" {
  name                            = "bation-vm"
  location                        = azurerm_resource_group.myAppName-rg.location
  resource_group_name             = azurerm_resource_group.myAppName-rg.name
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  size                            = "Standard_B1s"
  disable_password_authentication = false
  network_interface_ids           = [azurerm_network_interface.bastion-vm-nic.id]
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
}

#application gateway
locals {
  backend_address_pool_name      = "${module.vnet.vnet_name}-beap"
  frontend_port_name             = "${module.vnet.vnet_name}-feport"
  frontend_ip_configuration_name = "${module.vnet.vnet_name}-feip"
  http_setting_name              = "${module.vnet.vnet_name}-be-htst"
  listener_name                  = "${module.vnet.vnet_name}-httplstn"
  request_routing_rule_name      = "${module.vnet.vnet_name}-rqrt"
  redirect_configuration_name    = "${module.vnet.vnet_name}-rdrcfg"
}

resource "azurerm_application_gateway" "frontend-appgw" {
  name                = "myAppName-frontend-appgateway"
  resource_group_name = azurerm_resource_group.myAppName-rg.name
  location            = azurerm_resource_group.myAppName-rg.location

  sku {
    name     = "Standard_Small"
    tier     = "Standard"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "my-gateway-ip-configuration"
    subnet_id = module.vnet.vnet_subnets[1]
  }

  frontend_port {
    name = local.frontend_port_name
    port = 80
  }

  frontend_ip_configuration {
    name                 = local.frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.pip[0].id
  }

  backend_address_pool {
    name = local.backend_address_pool_name
  }

  backend_http_settings {
    name                  = local.http_setting_name
    cookie_based_affinity = "Disabled"
    path                  = "/"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 1
  }

  http_listener {
    name                           = local.listener_name
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_name
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = local.request_routing_rule_name
    rule_type                  = "Basic"
    http_listener_name         = local.listener_name
    backend_address_pool_name  = local.backend_address_pool_name
    backend_http_settings_name = local.http_setting_name
  }
  tags = local.common_tags
}

# backend app gateway
resource "azurerm_application_gateway" "backend-appgw" {
  name                = "myAppName-backend-appgateway"
  resource_group_name = azurerm_resource_group.myAppName-rg.name
  location            = azurerm_resource_group.myAppName-rg.location

  sku {
    name     = "Standard_Small"
    tier     = "Standard"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "my-gateway-ip-configuration"
    subnet_id = module.vnet.vnet_subnets[4]
  }

  frontend_port {
    name = local.frontend_port_name
    port = 80
  }

  frontend_ip_configuration {
    name                          = local.frontend_ip_configuration_name
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = module.vnet.vnet_subnets[4]
  }

  backend_address_pool {
    name = local.backend_address_pool_name
  }

  backend_http_settings {
    name                  = local.http_setting_name
    cookie_based_affinity = "Disabled"
    path                  = "/"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 1
  }

  http_listener {
    name                           = local.listener_name
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_name
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = local.request_routing_rule_name
    rule_type                  = "Basic"
    http_listener_name         = local.listener_name
    backend_address_pool_name  = local.backend_address_pool_name
    backend_http_settings_name = local.http_setting_name
  }
  tags = local.common_tags
}

#vmss
resource "azurerm_windows_virtual_machine_scale_set" "myAppName-vmss" {
  count                = var.vmss_count
  name                 = "${var.vmss_names[count.index]}-myAppName-vmss"
  computer_name_prefix = "myAppNamevm"
  resource_group_name  = azurerm_resource_group.myAppName-rg.name
  location             = azurerm_resource_group.myAppName-rg.location
  sku                  = "Standard_B1s"
  instances            = var.default_instances_count[terraform.workspace]
  admin_password       = var.admin_password
  admin_username       = var.admin_username

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_id = data.azurerm_shared_image_version.iis-image.id


  network_interface {
    name    = "${var.vm_name}-nic"
    primary = true
    ip_configuration {
      name                                         = "primary"
      application_gateway_backend_address_pool_ids = count.index == 0 ? [azurerm_application_gateway.frontend-appgw.backend_address_pool[0].id] : [azurerm_application_gateway.backend-appgw.backend_address_pool[0].id]
      subnet_id                                    = count.index == 0 ? module.vnet.vnet_subnets[0] : module.vnet.vnet_subnets[3]
      primary                                      = true
    }
  }
  tags = local.common_tags
}

# vmss-rule
resource "azurerm_monitor_autoscale_setting" "vmss-rules" {
  count               = var.vmss_count
  name                = "myAutoscaleSetting"
  resource_group_name = azurerm_resource_group.myAppName-rg.name
  location            = azurerm_resource_group.myAppName-rg.location
  target_resource_id  = azurerm_windows_virtual_machine_scale_set.myAppName-vmss[count.index].id

  profile {
    name = "defaultProfile"

    capacity {
      default = var.default_instances_count[terraform.workspace]
      minimum = var.default_instances_count[terraform.workspace]
      maximum = var.max_instances_count[terraform.workspace]
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_windows_virtual_machine_scale_set.myAppName-vmss[count.index].id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 75
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_windows_virtual_machine_scale_set.myAppName-vmss[count.index].id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 25
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }
  }
  tags = local.common_tags
}

# mysql
resource "azurerm_sql_server" "mysql" {
  name                = "myAppName-sqlserver${random_integer.rand.result}"
  location            = azurerm_resource_group.myAppName-rg.location
  resource_group_name = azurerm_resource_group.myAppName-rg.name
  version                      = "12.0"
  administrator_login          = var.admin_username
  administrator_login_password = var.admin_password

  tags = local.common_tags
}

resource "azurerm_mssql_database" "database" {
  name           = "myAppName-database"
  server_id      = azurerm_sql_server.mysql.id
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  license_type   = "LicenseIncluded"
  max_size_gb    = 4
  read_scale     = true
  sku_name       = "BC_Gen5_2"
  zone_redundant = true

  tags = local.common_tags
}