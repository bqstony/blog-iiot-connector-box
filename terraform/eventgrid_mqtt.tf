resource "azurerm_resource_group" "iiot_rg" {
  name     = "${var.application_short}-${var.location_short}-iiot-rg"
  location = var.location
}

# ╔══════════════════════════════════════════════════════════╗
# ║                        Event Grid                        ║
# ╚══════════════════════════════════════════════════════════╝
# azurerm not supported
resource "azapi_resource" "evgn" {
  type = "Microsoft.EventGrid/namespaces@2023-12-15-preview"
  name = "${var.application_short}-${var.location_short}-evgn"
  location = var.location
  parent_id = azurerm_resource_group.iiot_rg.id
  identity {
    type = "SystemAssigned"
  }
  body = {
    properties = {
      inboundIpRules = []
      isZoneRedundant = true
      publicNetworkAccess = "Enabled"
      topicsConfiguration = {}
      topicSpacesConfiguration = {
        // Enable MQTT
        state = "Enabled"
        maximumClientSessionsPerAuthenticationName = 1
        maximumSessionExpiryInHours = 4
      }
    }
    sku = {
      capacity = 1
      name = "Standard"
    }
  }
}

# client group that includes the clients that need access to publish or subscribe on the same MQTT topic.
resource "azapi_resource" "device_clientgroup" {
  type = "Microsoft.EventGrid/namespaces/clientGroups@2023-12-15-preview"
  name = "device"
  parent_id = azapi_resource.evgn.id
  body = {
    properties = {
      description = "string"
      // only devices with set attributes type value is edge-device
      query = "attributes.type=\"edge-device\""
    }
  }
}

# client resource for each client that needs to communicate over MQTT.
resource "azapi_resource" "edge01_device_client" {
  type = "Microsoft.EventGrid/namespaces/clients@2023-12-15-preview"
  name = "edge01"
  parent_id = azapi_resource.evgn.id
  body = {
    properties = {
      attributes = {
        # used for clientgroup filter
        "type": "edge-device",
      }
      authenticationName = "edge01"
      clientCertificateAuthentication = {        
        validationScheme = "ThumbprintMatch"
        allowedThumbprints = [
          "6fd8c836972c7dadbf42f85e7ab1b46d0b7c4fa4fd30864e2aad059c53e7b543"
        ]
      }
      description = "edge01 device client"
      state = "Enabled"
    }
  }
}

# topic channel for machine
resource "azapi_resource" "machine_topic" {
  type = "Microsoft.EventGrid/namespaces/topics@2023-12-15-preview"
  name = "machine"
  parent_id = azapi_resource.evgn.id
  body = {
    properties = {
      eventRetentionInDays = 7
      inputSchema = "CloudEventSchemaV1_0"
      publisherType = "Custom"
    }
  }
}

# topic space that includes a topic template that represents the intended topic/topic filter.
resource "azapi_resource" "machines_topicspace" {
  type = "Microsoft.EventGrid/namespaces/topicSpaces@2023-12-15-preview"
  name = "machines"
  parent_id = azapi_resource.evgn.id
  body = {
    properties = {
      description = "the topic space for all machines ISA95 like"
      topicTemplates = [
        "enterprise/site/area/line/#"
      ]
    }
  }
}

# permission binding to grant the client group access to publish or subscribe to the topic space.
resource "azapi_resource" "device_allow_publish_to_machines_topicspace" {
  type = "Microsoft.EventGrid/namespaces/permissionBindings@2023-12-15-preview"
  name = "device-allow-publish-to-machines"
  parent_id = azapi_resource.evgn.id
  body = {
    properties = {
      clientGroupName = azapi_resource.device_clientgroup.name
      description = "allow devices to publish and subscribe to the machines topic space"
      permission = "Publisher"
      topicSpaceName = azapi_resource.machines_topicspace.name
    }
  }
}

resource "azapi_resource" "device_allow_subscribe_to_machines_topicspace" {
  type = "Microsoft.EventGrid/namespaces/permissionBindings@2023-12-15-preview"
  name = "device-allow-subscribe-to-machines"
  parent_id = azapi_resource.evgn.id
  body = {
    properties = {
      clientGroupName = azapi_resource.device_clientgroup.name
      description = "allow devices to publish and subscribe to the machines topic space"
      permission = "Subscriber"
      topicSpaceName = azapi_resource.machines_topicspace.name
    }
  }
}