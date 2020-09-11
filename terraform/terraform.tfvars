default_instances_count = {
  mvp         = 1
  development = 2
  production  = 4
}

max_instances_count = {
  mvp         = 2
  development = 4
  production  = 6
}

subnet_count = 5

address_space = "10.0.0.0/16"

vm_name = "myAppName-vm"

subnet_names = ["frontend", "frontend-app-gw", "bastion", "backend", "backend-app-gw"]

vmss_names = ["web-end", "back-end"]

vmss_count = 2

public_ip_names = ["app-gw", "bastion-vm"]

vnet_name = "myAppName-vnet"

admin_username = "pacsquare"