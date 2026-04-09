param location string
param tags object
param logAnalyticsWorkspaceId string

resource serviceBus 'Microsoft.ServiceBus/namespaces@2022-10-01-preview' = {
  name: 'sb-hipaa-hl7-joel'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
  properties: {}
}

resource hl7Queue 'Microsoft.ServiceBus/namespaces/queues@2022-10-01-preview' = {
  parent: serviceBus
  name: 'hl7-inbound'
  properties: {
    maxDeliveryCount: 3
    deadLetteringOnMessageExpiration: true
    lockDuration: 'PT5M'
  }
}

resource sbDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'sb-diagnostics'
  scope: serviceBus
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'OperationalLogs'
        enabled: true
      }
    ]
  }
}

output serviceBusId string = serviceBus.id
output serviceBusEndpoint string = serviceBus.properties.serviceBusEndpoint
