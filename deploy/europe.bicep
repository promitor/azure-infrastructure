@secure()
param sqlServerPassword string
@minLength(3)
param location string = resourceGroup().location
@minLength(3)
param region string = 'Europe'
@minLength(2)
param geo string = 'eu'
@minLength(3)
param alternativeLocation string = 'northeurope'

// Parameters for naming strategy
@minLength(3)
@maxLength(20)
param projectName string = 'promitor'
@minLength(3)
@maxLength(10)
param environment string = 'dev'

// Create deterministic unique names based on subscription, tenant and environment
var subscriptionId = subscription().subscriptionId
var tenantId = tenant().tenantId
var namingHash = take(uniqueString(subscriptionId, tenantId, environment, projectName), 8)
var baseName = '${projectName}-${environment}'
var resourceNamePrefix = '${baseName}-${geo}-${namingHash}'

// Function to create valid storage account name (only lowercase letters and numbers, 24 chars max)
var cleanName = replace(replace(toLower(resourceNamePrefix), '-', ''), '_', '')
var storageAccountName = take(cleanName, 24)

// Function to create valid key vault and cosmos names (only alphanumeric and hyphens, start with letter)
var globallyUniqueName = take('${baseName}-${namingHash}', 24)
var keyVaultUniqueName = take(replace(toLower('${projectName}${environment}${geo}${uniqueString(subscription().id, resourceGroup().id)}kv'), '-', ''), 24)
var apimUniqueName = '${resourceNamePrefix}-${uniqueString(subscription().id, resourceGroup().id)}-apim'

resource automationAccount 'Microsoft.Automation/automationAccounts@2022-08-08' = {
  name: '${resourceNamePrefix}-auto-1'
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

resource workflowInWestEurope 'Microsoft.Logic/workflows@2019-05-01' = [for i in range(1, 3): {
  name: '${resourceNamePrefix}-wf-${geo}-${i}'
  location: location
  tags: {
    region: region
    app: 'promitor-resource-discovery-tests'
    instance: '${resourceNamePrefix}-wf-${geo}-${i}'
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

resource workflowInNorthEurope 'Microsoft.Logic/workflows@2019-05-01' = [for i in range(4, 3): {
  name: '${resourceNamePrefix}-wf-${geo}-${i}'
  location: alternativeLocation
  tags: {
    region: region
    app: 'promitor-resource-discovery-tests'
    instance: '${resourceNamePrefix}-wf-${geo}-${i}'
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

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: '${resourceNamePrefix}-logs'
  location: location
  properties: {
    retentionInDays: 30
    sku: {
      name: 'PerGB2018'
    }
    features: {
      immediatePurgeDataOn30Days: true
    }
  }
}

resource applicationInsights 'microsoft.insights/components@2020-02-02' = {
  name: '${resourceNamePrefix}-ai'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    IngestionMode: 'LogAnalytics'
    WorkspaceResourceId: logAnalyticsWorkspace.id
    DisableLocalAuth: false
  }
}

resource classicApplicationInsights 'microsoft.insights/components@2020-02-02' = {
  name: '${resourceNamePrefix}-ai-classic'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    RetentionInDays: 30
  }
}

resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2021-11-01' = {
  name: '${resourceNamePrefix}-sbus'
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

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: storageAccountName
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

resource serviceBusQueue 'Microsoft.ServiceBus/namespaces/queues@2021-11-01' = [for i in range(1, 15): {
  parent: serviceBusNamespace
  name: 'queue-${i}'
  properties: {
    maxDeliveryCount: 1
  }
}]

resource serviceBusTopic 'Microsoft.ServiceBus/namespaces/topics@2021-11-01' = {
  parent: serviceBusNamespace
  name: 'topic-1'
  properties: {}
}

resource sqlServer 'Microsoft.Sql/servers@2021-11-01' = {
  name: '${resourceNamePrefix}-sql'
  location: alternativeLocation
  properties: {
    administratorLogin: 'tom'
    administratorLoginPassword: sqlServerPassword
    version: '12.0'
    restrictOutboundNetworkAccess: 'Disabled'
  }
}

resource sqlDatabase 'Microsoft.Sql/servers/databases@2021-11-01' = [for i in range(1, 3): {
  parent: sqlServer
  name: '${resourceNamePrefix}-db-${i}'
  location: alternativeLocation
  sku: {
    name: 'Basic'
    tier: 'Basic'
    capacity: 5
  }
  properties: {
    zoneRedundant: false
  }
}]

resource apiManagement 'Microsoft.ApiManagement/service@2022-08-01' = {
  name: apimUniqueName
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

resource cdn 'Microsoft.Cdn/profiles@2021-06-01' = {
  name: '${resourceNamePrefix}-cdn'
  location: 'Global'
  sku: {
    name: 'Standard_Microsoft'
  }
  properties: {}
}

resource iotHub 'Microsoft.Devices/IotHubs@2021-07-02' = {
  name: '${resourceNamePrefix}-iot'
  location: location
  sku: {
    name: 'F1'
    capacity: 1
  }
  properties: {}
}

resource eventGridDomain 'Microsoft.EventGrid/domains@2022-06-15' = {
  name: '${resourceNamePrefix}-egd'
  location: location
  properties: {
    inputSchema: 'CloudEventSchemaV1_0'
    publicNetworkAccess: 'Enabled'
  }
}

resource appPlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: '${resourceNamePrefix}-plan'
  location: 'northeurope'
  kind: 'linux'
  tags: {}
  properties: {
    reserved: true
  }
  sku: {
    tier: 'Basic'
    name: 'B1'
  }
}

resource autoscalingRules 'microsoft.insights/autoscalesettings@2022-10-01' = {
  name: '${resourceNamePrefix}-autoscale'
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
              metricResourceUri: appPlan.id
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
              metricResourceUri: appPlan.id
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
    name: '${resourceNamePrefix}-autoscale'
    targetResourceUri: appPlan.id
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

resource webApp 'Microsoft.Web/sites@2022-09-01' = {
  name: '${resourceNamePrefix}-web'
  location: 'northeurope'
  tags: {}
  properties: {
    siteConfig: {
      appSettings: [
        {
          name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
          value: 'false'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: applicationInsights.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: applicationInsights.properties.ConnectionString
        }
        {
          name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'APPINSIGHTS_PROFILERFEATURE_VERSION'
          value: '1.0.0'
        }
        {
          name: 'APPINSIGHTS_SNAPSHOTFEATURE_VERSION'
          value: '1.0.0'
        }
      ]
      linuxFxVersion: 'DOCKER|mcr.microsoft.com/appsvc/staticsite:latest'
    }
    serverFarmId: appPlan.id
    clientAffinityEnabled: false
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: keyVaultUniqueName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    accessPolicies: []
  }
}

resource cosmosDbAccount 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' = {
  name: take(replace(toLower('${globallyUniqueName}-cosmos'), '-', ''), 44)
  location: alternativeLocation
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
        locationName: alternativeLocation
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
  }
}

resource cosmosDbDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2023-04-15' = {
  parent: cosmosDbAccount
  name: 'example-db'
  properties: {
    resource: {
      id: 'example-db'
    }
  }
}

resource cosmosDbDocumentationContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2023-04-15' = {
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
}

resource cosmosDbDatabaseThroughput 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/throughputSettings@2023-04-15' = {
  parent: cosmosDbDocumentationContainer
  name: 'default'
  properties: {
    resource: {
      throughput: 400
    }
  }
}

resource containerGroup 'Microsoft.ContainerInstance/containerGroups@2023-05-01' = {
  name: '${resourceNamePrefix}-aci'
  location: location
  properties: {
    containers: [
      {
        name: 'hello-world'
        properties: {
          image: 'mcr.microsoft.com/azuredocs/aci-helloworld'
          ports: [
            {
              port: 8080
              protocol: 'TCP'
            }
          ]
          resources: {
            requests: {
              cpu: 1
              memoryInGB: 1
            }
          }
        }
      }
    ]
    osType: 'Linux'
    restartPolicy: 'Always'
    ipAddress: {
      type: 'Public'
      ports: [
        {
          port: 8080
          protocol: 'TCP'
        }
      ]
    }
  }
}
