targetScope = 'resourceGroup'

@allowed(['lab', 'prod'])
param environment string = 'lab'

param location string = resourceGroup().location
param dataClassification string = 'PHI'
param complianceFramework string = 'HIPAA'

var tags = {
  Environment: environment
  DataClassification: dataClassification
  ComplianceFramework: complianceFramework
  Owner: 'Joel'
}

module logAnalytics 'modules/loganalytics.bicep' = {
  name: 'logAnalyticsDeployment'
  params: {
    location: location
    tags: tags
  }
}

module serviceBus 'modules/servicebus.bicep' = {
  name: 'serviceBusDeployment'
  params: {
    location: location
    tags: tags
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
  }
}

output serviceBusEndpoint string = serviceBus.outputs.serviceBusEndpoint
