param location string = resourceGroup().location

resource automationAccount 'Microsoft.Automation/automationAccounts@2020-01-13-preview' = {
  name: 'promitor-resource-discovery-1'
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

resource workflows 'Microsoft.Logic/workflows@2017-07-01' = [for i in range(1,3): {
  name: 'promitor-testing-resource-discovery-eu-${i}'
  location: location
  tags: {
    region: 'europe'
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
