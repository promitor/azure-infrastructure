@secure()
param mariaDbServerPassword string

param location string = resourceGroup().location
param resourceNamePrefix string = 'promitor-testing-resource-${geo}'
param region string = 'USA'
param geo string = 'us'

resource workflow 'Microsoft.Logic/workflows@2019-05-01' = [for i in range(1, 3): {
  name: 'promitor-testing-resource-${geo}-${i}'
  location: location
  tags: {
    region: region
    app: 'promitor-resource-discovery-tests'
    instance: '${resourceNamePrefix}-workflow-${geo}-${i}'
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

resource serverlessAppPlan 'Microsoft.Web/serverfarms@2021-01-15' = {
  name: '${resourceNamePrefix}-serverless-app-plan'
  location: location
  tags: {
    region: region
    app: 'promitor-resource-discovery-tests'
  }
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
  tags: {
    region: region
    app: 'promitor-resource-discovery-tests'
  }
  properties: {
    serverFarmId: serverlessAppPlan.id
    reserved: true
    keyVaultReferenceIdentity: 'SystemAssigned'
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2021-03-01' = {
  name: '${resourceNamePrefix}-vnet'
  location: location
  tags: {
    region: region
    app: 'promitor-resource-discovery-tests'
  }
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'subnet-1'
        properties: {
          addressPrefix: '10.0.0.0/24'
        }
      }
      {
        name: 'subnet-2'
        properties: {
          addressPrefix: '10.0.1.0/24'
        }
      }
    ]
  }
}

resource publicIpAddress 'Microsoft.Network/publicIpAddresses@2020-08-01' = {
  name: '${resourceNamePrefix}-public-IP'
  location: location
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
  }
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  dependsOn: []
}

resource loadBalancer 'Microsoft.Network/loadBalancers@2020-07-01' = {
  name: '${resourceNamePrefix}-load-balancer'
  location: location
  tags: {}
  properties: {
    frontendIPConfigurations: [
      {
        name: 'public-IP'
        properties: {
          publicIPAddress: {
            id: publicIpAddress.id
          }
        }
      }
    ]
    backendAddressPools: []
    probes: []
    loadBalancingRules: []
    inboundNatRules: []
    outboundRules: []
  }
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  dependsOn: [
    publicIpAddress
  ]
}

resource cdn 'Microsoft.Cdn/profiles@2019-04-15' = {
  name: '${resourceNamePrefix}-cdn'
  location: location
  tags: {
    region: region
    app: 'promitor-resource-discovery-tests'
  }
  sku: {
    name: 'Standard_Microsoft'
  }
  properties: {}
}

resource mariaDbServer 'Microsoft.DBforMariaDB/servers@2018-06-01' = {
  name: '${resourceNamePrefix}-mariadb-server'
  location: 'East US'
  tags: {
    region: region
    app: 'promitor-resource-discovery-tests'
  }
  sku: {
    capacity: 1
    family: 'Gen5'
    name: 'B_Gen5_1'
    size: '51200'
    tier: 'Basic'
  }
  properties: {
    storageProfile: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
      storageAutogrow: 'Enabled'
    }
    version: '10.3'
    createMode: 'Default'
    administratorLogin: 'tom'
    administratorLoginPassword: mariaDbServerPassword
  }
}

resource mariaDbDatabase 'Microsoft.DBforMariaDB/servers/databases@2018-06-01' = {
  name: 'example-db-1'
  parent: mariaDbServer
  properties: {
    charset: 'utf8'
    collation: 'utf8_general_ci'
  }
}
