output "sas_url_query_string" {
  value = data.azurerm_storage_account_blob_container_sas.blob-sas.sas
}

output "resource_group_name" {
  value = azurerm_resource_group.myAppName-rg.name
}

output "app_gw_ip" {
  value = azurerm_public_ip.pip[0].ip_address
}

output "bation-vm-ip" {
  value = azurerm_public_ip.pip[1].ip_address
}