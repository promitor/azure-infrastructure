param location string = resourceGroup().location
param alternativeLocation string = 'eastus2'
param region string = 'USA'
param geo string = 'us'

// Parameters for naming strategy
param projectName string = 'promitor'
param environment string = 'dev'

// Create deterministic unique names based on subscription, tenant and environment
var subscriptionId = subscription().subscriptionId
var tenantId = tenant().tenantId
var namingHash = take(uniqueString(subscriptionId, tenantId, environment, projectName), 8)
var baseName = '${projectName}-${environment}'
var resourceNamePrefix = '${baseName}-${geo}-${namingHash}'

resource workflow 'Microsoft.Logic/workflows@2019-05-01' = [for i in range(1, 3): {
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

resource serverlessAppPlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: '${resourceNamePrefix}-serverless-app-plan'
  location: alternativeLocation
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

resource functionApp 'Microsoft.Web/sites@2022-09-01' = {
  name: '${resourceNamePrefix}-serverless-functions'
  location: alternativeLocation
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

resource vnet 'Microsoft.Network/virtualNetworks@2022-11-01' = {
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

resource publicIpAddress 'Microsoft.Network/publicIpAddresses@2022-11-01' = {
  name: '${resourceNamePrefix}-public-ip'
  location: location
  properties: {
    dnsSettings: {
      domainNameLabel: '${resourceNamePrefix}-public-ip'
    }
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
  }
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
}

resource loadBalancer 'Microsoft.Network/loadBalancers@2022-11-01' = {
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
}

resource trafficManager 'Microsoft.Network/trafficmanagerprofiles@2018-08-01' = {
  name: '${resourceNamePrefix}-traffic-manager'
  location: 'global'
  properties: {
    profileStatus: 'Enabled'
    trafficRoutingMethod: 'Priority'
    dnsConfig: {
      relativeName: '${resourceNamePrefix}-traffic-router'
      ttl: 300
    }
    monitorConfig: {
      protocol: 'HTTPS'
      port: 443
      path: '/'
      expectedStatusCodeRanges: [
        {
          min: 200
          max: 202
        }
        {
          min: 301
          max: 302
        }
      ]
    }
    endpoints: [
      {
        type: 'Microsoft.Network/trafficManagerProfiles/externalEndpoints'
        name: 'public-ip'
        properties: {
          target: publicIpAddress.properties.dnsSettings.fqdn
          endpointStatus: 'Enabled'
          endpointLocation: location
        }
      }
    ]
  }
}