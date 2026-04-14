@description('Deployment prefix used to generate all resource names. Choose a short, lowercase alphanumeric string.')
@minLength(3)
@maxLength(10)
param prefix string

@description('Deployment environment. Drives resource naming and tag values.')
@allowed(['lab', 'prod'])
param environment string = 'lab'

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('HIPAA compliance tags applied to all resources.')
param tags object = {
  DataClassification: 'PHI'
  ComplianceFramework: 'HIPAA'
  Environment: environment
  Owner: 'pipeline-operator'
}

// --- Resource name variables (prefix-driven, no hardcoded names) ---
var logAnalyticsName = '${prefix}-law-${environment}'
var serviceBusNamespaceName = '${prefix}-sb-${environment}'
var keyVaultName = '${prefix}-kv-${environment}'

// --- Modules ---
module logAnalytics 'modules/loganalytics.bicep' = {
  name: 'deploy-loganalytics'
  params: {
    name: logAnalyticsName
    location: location
    tags: tags
  }
}

module serviceBus 'modules/servicebus.bicep' = {
  name: 'deploy-servicebus'
  params: {
    namespaceName: serviceBusNamespaceName
    location: location
    tags: tags
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
  }
}

module keyVault 'modules/keyvault.bicep' = {
  name: 'deploy-keyvault'
  params: {
    name: keyVaultName
    location: location
    tags: tags
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
  }
}

// --- Outputs ---
output logAnalyticsWorkspaceId string = logAnalytics.outputs.workspaceId
output serviceBusNamespaceId string = serviceBus.outputs.namespaceId
output keyVaultUri string = keyVault.outputs.vaultUri

@description('Azure Function App and AHDS FHIR service require manual provisioning. See docs/deployment-guide.md.')
output note string = 'Function App and AHDS FHIR service require manual provisioning. See deployment-guide.md.'
