##############################################################
# Description:
# This template is setting up the dataproviding based on the
# iot infrastructure. The Azure Data Explorer is storing
# and providing this data over a rest api
#
# The following Services are created in the following order:
# 1.   Azure Data Explorer Cluster
# 1.1. Setup access to the Cluster
# 2.   ADX Database - machines-db
# 2.1  Setup access to the Database
# 2.2  Deploy Tables & Functions
# 2.3  Data connections for ingestion
##############################################################

locals {
  # Possible easy to remove the ADX Cluster, it is expensive to run 😜
  withAdxCount      = 0
}

# ╔══════════════════════════════════════════════════════════╗
# ║                            ADX                           ║
# ╚══════════════════════════════════════════════════════════╝

// adx Identity to handle access to other resources
resource "azurerm_user_assigned_identity" "adx_identity" {
  count                 = local.withAdxCount

  name                  = "${var.application_short}${var.location_short}adx-identity"
  location              = var.location
  resource_group_name   = azurerm_resource_group.iiot_rg.name
}

resource "azurerm_kusto_cluster" "adx" {
  count                 = local.withAdxCount

  name                  = "${var.application_short}${var.location_short}adx"
  location              = var.location
  resource_group_name   = azurerm_resource_group.iiot_rg.name

  // SKU Configuration for the dev and int environment
  sku {
    name     = "Dev(No SLA)_Standard_D11_v2"
    capacity = 1
  }

  // Specifies if the cluster's disks are encrypted.
  // Limitations of VM Size see:
  // - https://learn.microsoft.com/en-us/azure/data-explorer/kusto/concepts/sandboxes-in-non-modern-skus#virtual-machine-sizes
  // - https://learn.microsoft.com/en-us/azure/data-explorer/kusto/concepts/sandboxes#vm-sizes-supporting-nested-virtualization
  // Dev VM does not support disk encryption and sandboxes (e.g. Python, R) cannot be enabled simultaneously
  disk_encryption_enabled     = false
  streaming_ingestion_enabled = true
  purge_enabled               = true
  // Support Python=v3.6.5, to use PYTHON_3.10.8 skus which support nested virtualization are required
  #language_extensions         = ["PYTHON"]

  public_network_access_enabled = true
  // The list of ips in the format of CIDR allowed to connect to the cluster over the public endpoint.
  #allowed_ip_ranges             = tbd

  identity {
    type          = "UserAssigned"
    identity_ids  = [
      azurerm_user_assigned_identity.adx_identity[0].id
    ]
  }
}

# ╔══════════════════════════════════════════════════════════╗
# ║             ADX Database - machines-db                   ║
# ╚══════════════════════════════════════════════════════════╝
resource "azurerm_kusto_database" "adx_database_machines-db" {
  count                 = local.withAdxCount

  name                  = "machines-db"
  location              = var.location
  resource_group_name   = azurerm_resource_group.iiot_rg.name
  cluster_name          = azurerm_kusto_cluster.adx[0].name

  hot_cache_period   = "P10D"
  soft_delete_period = "P31D"
}

# ┌──────────────────────────────────────────────────────────┐
# │                 Deploy Tables & Functions                │
# └──────────────────────────────────────────────────────────┘
locals {
  // Random execution does not work because of dependencies in the KQL queries.
  // So there are multible sets of blocks sequentally executed.
  adx_db_machines-db_independent-scripts = [
    "databases/machines-db/0001_database.kql",
    "databases/machines-db/tables/0001_iiot_d2c_stage.kql",
  ]

  adx_db_machines-db_dependent1-scripts = [
  ]
}

// Execute all independent scripts
resource "azurerm_kusto_script" "adx_database_machines-db_script-independent-execute" {
  for_each   = local.withAdxCount == 1 ? toset(local.adx_db_machines-db_independent-scripts) : []

  name                        = replace(each.key, "/", "-")
  database_id                 = azurerm_kusto_database.adx_database_machines-db[0].id
  continue_on_errors_enabled  = false

  script_content  = file("${each.key}")
  force_an_update_when_value_changed = md5(file("${each.key}"))
}

// Execute all dependent scripts Level 1
resource "azurerm_kusto_script" "adx_database_machines-db_script-dependent1-execute" {
  for_each   = local.withAdxCount == 1 ? toset(local.adx_db_machines-db_dependent1-scripts) : []

  name                        = replace(each.key, "/", "-")
  database_id                 = azurerm_kusto_database.adx_database_machines-db[0].id
  continue_on_errors_enabled  = false

  script_content  = file("${each.key}")
  force_an_update_when_value_changed = md5(file("${each.key}"))

  depends_on = [
    azurerm_kusto_script.adx_database_machines-db_script-independent-execute
  ]
}


# ┌──────────────────────────────────────────────────────────┐
# │                     Data connections                     │
# └──────────────────────────────────────────────────────────┘

// Add RBAC Permission to Eventhub ns to Allow acces to the Event Hub to read
resource "azurerm_role_assignment" "adx_eventhub_rbacs" {
  count                 = local.withAdxCount

  scope                 = azurerm_eventhub_namespace.eventhub_ns.id
  // https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#azure-event-hubs-data-receiver
  role_definition_name  = "Azure Event Hubs Data Receiver"
  principal_id          = azurerm_user_assigned_identity.adx_identity[0].principal_id
}

// Setup the d2c-messages EventHub ingestion into the iiot_d2c_stage table
// Be aware of enouth the permission to the ADX Cluster from the user that deploy the terraform
resource "azurerm_kusto_eventhub_data_connection" "adx_database_machines-db_eventhub-connection" {
  count                 = local.withAdxCount

  name                  = "evh-ingestion-d2c-messages"
  location              = var.location
  resource_group_name   = azurerm_resource_group.iiot_rg.name
  cluster_name          = azurerm_kusto_cluster.adx[0].name
  database_name         = azurerm_kusto_database.adx_database_machines-db[0].name

  eventhub_id    = azurerm_eventhub.eventhub_topics[local.eventhub_topic_eventgrid-d2c-messages].id
  consumer_group = "$Default" # Only 1 consumergroup is allowed in Basic SKU / azurerm_eventhub_consumer_group.eventhub_consumergroups["${local.eventhub_topic_eventgrid-d2c-messages}.iiot-adx-ingress"].name

  table_name              = "iiot_d2c_stage"
  mapping_rule_name       = "iiot_d2c_stage_mapping"
    // https://learn.microsoft.com/en-us/azure/data-explorer/ingest-json-formats?tabs=kusto-query-language#the-json-format
  data_format             = "JSON"
  database_routing_type   = "Single"
  // Specifies a list of system properties for the Event Hub.
  // https://learn.microsoft.com/en-us/azure/data-explorer/ingest-data-event-hub-overview#event-system-properties-mapping
  event_system_properties = [
    "x-opt-enqueued-time",          // UTC time when the event was enqueued in eventhub
    "x-opt-partition-key",          // The partition key of the corresponding partition that stored the event
  ]

  // Use the system identity of the ADX cluster to access the EventHub
  identity_id = azurerm_user_assigned_identity.adx_identity[0].id

  depends_on = [
    azurerm_kusto_script.adx_database_machines-db_script-independent-execute,
    azurerm_role_assignment.adx_eventhub_rbacs[0],
  ]
}
