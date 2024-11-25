# ╔══════════════════════════════════════════════════════════╗
# ║                  Event Hub Namespace                     ║
# ╚══════════════════════════════════════════════════════════╝
// Create the Event Hub Namespace
resource "azurerm_eventhub_namespace" "eventhub_ns" {
  name                  = "${var.application_short}-${var.location_short}-evhns"
  location              = var.location
  resource_group_name   = azurerm_resource_group.iiot_rg.name

  sku                       = "Basic" # "Standard"
  capacity                  = 1
  // Auto-Inflate automatically scales the number of Throughput Units assigned to your Standard Tier Event Hubs Namespace when your traffic exceeds the capacity of the Throughput Units assigned to it. You can specify a limit to which the Namespace will automatically scale.
  auto_inflate_enabled      = false
  // Specifies the maximum number of throughput units when Auto Inflate is Enabled.
  maximum_throughput_units  = 0

  minimum_tls_version           = "1.2"
  // Is SAS authentication enabled for the EventHub Namespace
  local_authentication_enabled  = true
  public_network_access_enabled = true

  # No rules are allowed in the Basic SKU
#   network_rulesets = [
#     {
#       public_network_access_enabled   = false
#       // To Connect eventgrid with system identity, are "Allow trusted Microsoft services to bypass this firewall" required. see: https://learn.microsoft.com/en-us/azure/iot-hub/virtual-network-support#egress-connectivity-from-iot-hub-to-other-azure-resources
#       trusted_service_access_enabled  = true
#       // when trusted_service_access_enabled=true azure set it automaticly to Allow
#       default_action                  = "Allow"
#       ip_rule                         = null
#       virtual_network_rule            = null
#     }
#   ]

  identity {
    // Due to the limitation of the current Azure API, once an EventHub Namespace has been assigned an identity, it cannot be removed. 09.05.2023
    type = "SystemAssigned"
  }
}

# ┌──────────────────────────────────────────────────────────┐
# │                     Event Hub Topics                     │
# └──────────────────────────────────────────────────────────┘
locals {
  eventhub_topic_eventgrid-d2c-messages = "${var.application_short}-${var.location_short}-eventgrid-d2c-messages-evh"
  eventhub_topic_d2c-messages = "${var.application_short}-${var.location_short}-d2c-messages-evh"

  eventhub_topics = [
    {
      name              = local.eventhub_topic_eventgrid-d2c-messages
      description       = "This evenhub for eventgrid messages"
      messageRetention  = 1 # in Basic SKU only 1 day is allowed, for 7 days use Standard
      partitionCount    = 1

      consumergroups  = [
        # # Only 1 consumer group is allowed in the Basic SKU, so use $Default
        # {
        #   name          = "preview_data_consumer_group"
        #   description   = "This consumer group is for the portal real time insights from events with stream analytics query tool"
        # }
      ]

      policies = [
        # We do not use SAS
        # {
        #   name          = "PreviewDataPolicy"
        #   description   = "This policy is for the portal real time insights from events with stream analytics query tool. The Policy name is by convention PreviewDataPolicy!"
        #   send          = true
        #   listen        = true
        #   manage        = true
        # }
      ]
    },
    {
      name              = local.eventhub_topic_d2c-messages
      description       = "This evenhub is for edge devices to cloud messages"
      messageRetention  = 1 # in Basic SKU only 1 day is allowed, for 7 days use Standard
      partitionCount    = 1
      consumergroups  = [ ]
      policies = [
        # For simplicity
        {
          name          = "iiot-rabbitmq-shovel-policy"
          description   = "This policy is for the shovel plugin of rabbitmq v4"
          send          = true
          listen        = true
          manage        = false
        }
      ]
    }
  ]
}

// Create the Event Hub topics
resource "azurerm_eventhub" "eventhub_topics" {
  for_each              = { for evht in local.eventhub_topics: evht.name => evht } // name has to be unique
  name                  = each.value.name
  namespace_name        = azurerm_eventhub_namespace.eventhub_ns.name
  resource_group_name   = azurerm_resource_group.iiot_rg.name

  // Number of days to retain the events for this Event Hub, value should be 1 to 7 days
  message_retention     = each.value.messageRetention
  // Number of partitions created for the Event Hub, allowed values are from 1 to 32 partitions. Create 1 Partition per 1 MB/s
  partition_count       = each.value.partitionCount
}

resource "azurerm_eventhub_consumer_group" "eventhub_consumergroups" {
  for_each  = { for cg in flatten([
    for evht in local.eventhub_topics: [
      for evhtcg in evht.consumergroups : {
        topicName         = evht.name
        consumergroupName = evhtcg.name
        description       = evhtcg.description
      }
    ]
  ]): "${cg.topicName}.${cg.consumergroupName}" => cg }

  name                  = each.value.consumergroupName
  eventhub_name         = azurerm_eventhub.eventhub_topics[each.value.topicName].name
  namespace_name        = azurerm_eventhub.eventhub_topics[each.value.topicName].namespace_name
  resource_group_name   = azurerm_eventhub.eventhub_topics[each.value.topicName].resource_group_name
  user_metadata         = each.value.description
}

resource "azurerm_eventhub_authorization_rule" "eventhub_policies" {
  for_each  = { for pol in flatten([
    for evht in local.eventhub_topics: [
      for evhtpol in evht.policies : {
        topicName   = evht.name
        policyName  = evhtpol.name
        send        = evhtpol.send
        listen      = evhtpol.listen
        manage      = evhtpol.manage
      }
    ]
  ]): "${pol.topicName}.${pol.policyName}" => pol }

  name                  = each.value.policyName
  eventhub_name         = azurerm_eventhub.eventhub_topics[each.value.topicName].name
  namespace_name        = azurerm_eventhub.eventhub_topics[each.value.topicName].namespace_name
  resource_group_name   = azurerm_eventhub.eventhub_topics[each.value.topicName].resource_group_name
  send                  = each.value.send
  listen                = each.value.listen
  manage                = each.value.manage
}
