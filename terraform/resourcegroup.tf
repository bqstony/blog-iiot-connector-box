resource "azurerm_resource_group" "iiot_rg" {
  name     = "${var.application_short}-${var.location_short}-iiot-rg"
  location = var.location
}