param location string = resourceGroup().location
param resourceNamePrefix string = 'promitor-testing-resource-${geo}'
param resourceShortNamePrefix string = 'promitortestingresource${geo}'
param region string = 'Europe'
param geo string = 'eu'

param appPlanName string = '${resourceNamePrefix}-app-plan'
param appPlanResourceId string = resourceId('Microsoft.Web/serverFarms', appPlanName)

resource automationAccount 'Microsoft.Automation/automationAccounts@2020-01-13-preview' = {
  name: '${resourceNamePrefix}-automation-1'
  location: location
  properties: {
    sku: {
      name: 'Basic'
    }
    encryption: {
      keySource: 'Microsoft.Automation'
      identity: {}
    }
  }
}

resource workflows 'Microsoft.Logic/workflows@2019-05-01' = [for i in range(1,3): {
  name: '${resourceNamePrefix}-workflow-${geo}-${i}'
  location: location
  tags: {
    region: region
    app: 'promitor-resource-discovery-tests'
  }
  properties: {
    state: 'Enabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {}
      triggers: {}
      actions: {}
      outputs: {}
    }
    parameters: {}
  }
}]

resource applicationInsights 'microsoft.insights/components@2020-02-02' = {
  name: '${resourceNamePrefix}-telemetry'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
  }
}

resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2021-06-01-preview' = {
  name: '${resourceNamePrefix}-messaging'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
  properties: {
    disableLocalAuth: false
    zoneRedundant: false
  }
}

resource storageAccounts_promitor_name_resource 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: '${resourceShortNamePrefix}telemetry'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    accessTier: 'Hot'
  }
}

resource serviceBusQueue 'Microsoft.ServiceBus/namespaces/queues@2021-06-01-preview' = [for i in range(1,15): {
  parent: serviceBusNamespace
  name: 'queue-${i}'
  properties: {
    maxDeliveryCount: 1
  }
}]

resource serviceBusTopic 'Microsoft.ServiceBus/namespaces/topics@2021-06-01-preview' = {
  parent: serviceBusNamespace
  name: 'topic-1'
  properties: {
  }
}

resource sqlServer 'Microsoft.Sql/servers@2021-02-01-preview' = {
  name: '${resourceNamePrefix}-sql-server'
  location: location
  properties: {
    administratorLogin: 'tom'
    version: '12.0'
    restrictOutboundNetworkAccess: 'Disabled'
  }
}

resource sqlDatabase 'Microsoft.Sql/servers/databases@2021-02-01-preview' = [for i in range(1,3): {
  parent: sqlServer
  name: '${sqlServer}-db-${i}'
  location: location
  sku: {
    name: 'Basic'
    tier: 'Basic'
    capacity: 5
  }
  properties: {
    zoneRedundant: false
  }
}]

resource apiManagement 'Microsoft.ApiManagement/service@2021-01-01-preview' = {
  name: '${resourceNamePrefix}-api-gateway'
  location: location
  sku: {
    name: 'Consumption'
    capacity: 0
  }
  properties: {
    publisherEmail: 'tomkerkhove.opensource@gmail.com'
    publisherName: 'Promitor'
  }
}

resource cdn 'Microsoft.Cdn/profiles@2020-09-01' = {
  name: '${resourceNamePrefix}-cdn'
  location: 'Global'
  sku: {
    name: 'Standard_Microsoft'
  }
  properties: {}
}

resource iotHub 'Microsoft.Devices/IotHubs@2021-07-01' = {
  name: '${resourceNamePrefix}-iot-gateway'
  location: location
  sku: {
    name: 'F1'
    capacity: 1
  }
  properties: {}
}

resource eventGridDomain 'Microsoft.EventGrid/domains@2021-06-01-preview' = {
  name: '${resourceNamePrefix}-event-domains'
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    inputSchema: 'CloudEventSchemaV1_0'
    publicNetworkAccess: 'Enabled'
  }
}

resource autoscalingRules 'microsoft.insights/autoscalesettings@2015-04-01' = {
  name: '${resourceNamePrefix}-app-plan-autoscaling'
  location: location
  properties: {
    profiles: [
      {
        name: 'Auto created scale condition'
        capacity: {
          minimum: '1'
          maximum: '2'
          default: '1'
        }
        rules: [
          {
            metricTrigger: {
              metricName: 'CpuPercentage'
              metricNamespace: 'microsoft.web/serverfarms'
              metricResourceUri: appPlanResourceId
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT10M'
              timeAggregation: 'Average'
              operator: 'GreaterThan'
              threshold: 70
              dimensions: []
              dividePerInstance: false
            }
            scaleAction: {
              direction: 'Increase'
              type: 'ChangeCount'
              value: '1'
              cooldown: 'PT5M'
            }
          }
          {
            metricTrigger: {
              metricName: 'CpuPercentage'
              metricNamespace: 'microsoft.web/serverfarms'
              metricResourceUri: appPlanResourceId
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT10M'
              timeAggregation: 'Average'
              operator: 'LessThan'
              threshold: 30
              dimensions: []
              dividePerInstance: false
            }
            scaleAction: {
              direction: 'Decrease'
              type: 'ChangeCount'
              value: '1'
              cooldown: 'PT5M'
            }
          }
        ]
      }
    ]
    enabled: false
    name: '${resourceNamePrefix}-app-plan-autoscaling'
    targetResourceUri: appPlanResourceId
    notifications: [
      {
        operation: 'Scale'
        email: {
          sendToSubscriptionAdministrator: false
          sendToSubscriptionCoAdministrators: false
          customEmails: []
        }
        webhooks: []
      }
    ]
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2021-06-01-preview' = {
  name: '${resourceNamePrefix}-secret-store'
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: 'c8819874-9e56-4e3f-b1a8-1c0325138f27'
    accessPolicies: []
  }
}
resource appPlan 'Microsoft.Web/serverfarms@2021-01-15' = {
  name: appPlanName
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
    size: 'Y1'
    family: 'Y'
  }
  kind: 'functionapp'
  properties: {
    reserved: true
  }
}

resource functionApp 'Microsoft.Web/sites@2021-01-15' = {
  name: '${resourceNamePrefix}-serverless-functions'
  location: location
  kind: 'functionapp'
  properties: {
    serverFarmId: appPlan.id
    reserved: true
    keyVaultReferenceIdentity: 'SystemAssigned'
  }
}

resource cosmosDbAccount 'Microsoft.DocumentDB/databaseAccounts@2021-06-15' = {
  name: '${resourceNamePrefix}-cosmos-db'
  location: location
  tags: {
    CosmosAccountType: 'Non-Production'
  }
  kind: 'GlobalDocumentDB'
  identity: {
    type: 'None'
  }
  properties: {
    publicNetworkAccess: 'Enabled'
    enableAutomaticFailover: false
    enableFreeTier: true
    databaseAccountOfferType: 'Standard'
    disableLocalAuth: false
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
      maxIntervalInSeconds: 5
      maxStalenessPrefix: 100
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
  }
}

resource cosmosDbDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2021-06-15' = {
  parent: cosmosDbAccount
  name: 'example-db'
  properties: {
    resource: {
      id: 'example-db'
    }
  }
}

resource cosmosDbEmptyContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2021-06-15' = {
  parent: cosmosDbDatabase
  name: 'empty-container'
  properties: {
    resource: {
      id: 'empty-container'
      partitionKey: {
        paths: [
          '/id'
        ]
        kind: 'Hash'
      }
    }
  }
  dependsOn: [
    cosmosDbAccount
  ]
}

resource cosmosDbDocumentationContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2021-06-15' = {
  parent: cosmosDbDatabase
  name: 'sample-docs'
  properties: {
    resource: {
      id: 'sample-docs'
      partitionKey: {
        paths: [
          '/id'
        ]
        kind: 'Hash'
      }
    }
  }
  dependsOn: [
    cosmosDbAccount
  ]
}

resource cosmosDbDatabaseThroughput 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/throughputSettings@2021-06-15' = {
  parent: cosmosDbDatabase
  name: 'default'
  properties: {
    resource: {
      throughput: 400
    }
  }
  dependsOn: [
    cosmosDbAccount
  ]
}
