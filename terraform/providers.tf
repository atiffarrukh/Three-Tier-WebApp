provider "azurerm" {
  version = "2.14.0"
  features {
    virtual_machine_scale_set {
      roll_instances_when_required = true
      }
    }
}